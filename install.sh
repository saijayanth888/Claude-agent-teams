#!/usr/bin/env bash
# install.sh — symlink claude-agent-teams into ~/.claude/
# Idempotent: safe to rerun.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_AGENTS="$HOME/.claude/agents"
USER_TEMPLATES="$HOME/.claude/agent-team-templates"

echo "Installing claude-agent-teams from $REPO_DIR"

# --- 1. Symlink agent-team-templates ---
mkdir -p "$(dirname "$USER_TEMPLATES")"

if [ -L "$USER_TEMPLATES" ]; then
  current="$(readlink "$USER_TEMPLATES")"
  if [ "$current" = "$REPO_DIR" ]; then
    echo "  agent-team-templates: already linked correctly"
  else
    echo "  agent-team-templates: relinking from $current to $REPO_DIR"
    rm "$USER_TEMPLATES"
    ln -s "$REPO_DIR" "$USER_TEMPLATES"
  fi
elif [ -e "$USER_TEMPLATES" ]; then
  echo "  ERROR: $USER_TEMPLATES exists and is NOT a symlink. Refusing to clobber."
  echo "  Move it aside manually, then rerun."
  exit 1
else
  ln -s "$REPO_DIR" "$USER_TEMPLATES"
  echo "  agent-team-templates: symlinked → $REPO_DIR"
fi

# --- 2. Symlink each role file ---
mkdir -p "$USER_AGENTS"

shopt -s nullglob
for src in "$REPO_DIR"/agents/*.md; do
  name="$(basename "$src")"
  dst="$USER_AGENTS/$name"

  if [ -L "$dst" ]; then
    current="$(readlink "$dst")"
    if [ "$current" = "$src" ]; then
      echo "  agents/$name: already linked correctly"
      continue
    fi
    echo "  agents/$name: relinking from $current to $src"
    rm "$dst"
    ln -s "$src" "$dst"
  elif [ -e "$dst" ]; then
    echo "  WARN: $dst exists and is NOT a symlink. Skipping (move aside manually if you want to relink)."
  else
    ln -s "$src" "$dst"
    echo "  agents/$name: symlinked → $src"
  fi
done

echo
echo "Install complete."
echo
echo "Next steps:"
echo "  1. Verify Claude Code v2.1.32+:           claude --version"
echo "  2. Set CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 in ~/.claude/settings.json env"
echo "  3. Set teammateMode: in-process in ~/.claude/settings.json"
echo "  4. Run /config → Default teammate model → Default (leader's model)"
echo "  5. Restart Claude Code, then in any session say:"
echo "       \"run the research team on <topic>\""
