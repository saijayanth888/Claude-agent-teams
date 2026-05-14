# Claude Agent Teams

User-global library of pre-baked Claude Code agent-team templates and reusable role definitions. Replaces ad-hoc subagent prompts with structured teams that have known communication patterns, explicit circuit breakers, and per-project output archives.

**Status**: v1 design approved · pending implementation · 2026-05-14

---

## What this is

Every Claude Code session that needs parallel work starts with writing fresh subagent prompts from scratch. This library pre-bakes the patterns. Five team templates cover ~80% of typical work; ten reusable roles compose those teams. Invoking a team becomes a one-line natural-language request: *"run the debate team on whether commit X is safe to ship."*

The library is **project-agnostic**. The same templates serve any codebase. Project-specific context (CLAUDE.md, MCP servers, skills) is loaded by Claude Code at teammate spawn time — not baked into templates.

## Browse

- [Design spec](docs/specs/2026-05-14-claude-code-agent-teams-design.md) — 16 sections, full v1 architecture + G1–G5 patches + §3.4 hierarchy framing
- [Architecture diagram](docs/diagrams/agent-teams-architecture.svg) — 5 panels, dYdX-style dark monospace

## The hierarchy (§3.4)

The system has a familiar three-layer hierarchy already baked in. No additional coordinator layer is added or needed.

| Layer | Who plays it | Responsibility |
|---|---|---|
| **Product owner** | the operator | sets goals, picks the template, accepts or rejects the deliverable |
| **Tech lead** | the main Claude Code session (= team lead) | translates goal → team plan, spawns teammates, judges plan approvals, enforces circuit breakers, synthesizes `summary.md` |
| **Developers** | the spawned teammates | execute focused, scoped tasks; coordinate via DMs and the shared task list |

The PO ↔ tech-lead handoff is where your intent ends and Claude's autonomy begins. *"Team lead"* is the implementation term; *"tech lead"* is the mental model — same Claude session.

## The 5 teams

| Template | Pattern | Use when |
|---|---|---|
| `research` | parallel-then-sync | open-ended question with multiple independent angles |
| `debate` | position-then-engage | yes/no decision where adversarial pressure improves quality |
| `brainstorm` | diverge-critique-converge | generative ideation that benefits from divergent thinking before convergence |
| `design-review` | sequential + critique-loop | architectural or UX decision with built-in critique |
| `improvement` | pipeline + verify-handoff | find issues in existing code AND execute the fixes |

## The 10 roles

| Role | Tools allowlist | Job |
|---|---|---|
| `researcher` | Read, Grep, WebSearch, WebFetch, Bash(read-only) | investigates a focused question across web AND code |
| `scout` | Read, Grep, Glob, Bash(read-only) | maps existing code state without proposing changes |
| `synthesizer` | Read, Grep | merges N reports, identifies tensions, produces unified output |
| `defender` | Read, Grep, Bash | argues a position with file:line evidence |
| `skeptic` | Read, Grep, Bash | attacks a position; hunts blind spots |
| `diverger` | Read | generates novel ideas without self-filter |
| `critic` | Read, Grep | challenges design proposals rigorously |
| `designer` | Read, Grep | proposes structured solution given scout's map + constraints |
| `builder` | Read, Edit, Write, Bash | implements code/config changes (only role with write access) |
| `verifier` | Read, Bash, Grep | runs tests, smoke-checks, catches regressions |

Each role's tool allowlist makes it safe to compose: `scout` literally cannot Edit; `builder` literally cannot WebSearch.

## Pre-flight (one-time setup)

```bash
# 1. Verify Claude Code v2.1.32+
claude --version

# 2. Enable experimental agent teams + pin teammate mode for portability
# add to ~/.claude/settings.json:
#   {
#     "env": { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1" },
#     "teammateMode": "in-process"
#   }

# 3. Set default teammate model
# /config → Default teammate model → "Default (leader's model)"

# 4. (Optional) Pre-approve read-only tools to reduce permission prompts
# add to ~/.claude/settings.json:
#   "permissions": { "allow": ["Read", "Glob", "Grep", "Bash(ls *)", "Bash(cat *)", "Bash(grep *)"] }
```

## Filesystem layout (once installed)

```
~/.claude/
├── settings.json                 (operator-managed; pre-flight above)
├── agents/                       (10 role files — Claude Code primitive)
├── agent-team-templates/         (5 team templates — this repo, symlinked)
│   ├── README.md
│   ├── PLAYBOOK.md
│   └── teams/
└── teams/                        (active runtime state; auto-managed; never hand-edit)

<any-project>/.claude/
├── agents/                       (project-scope role overrides — G3 patch)
└── agent-team-runs/              (per-project output archive)
    └── 2026-05-14T10-45_debate_rg-wiring/
        ├── manifest.json
        ├── summary.md
        ├── members/
        └── comms/
```

## Quick start

In any Claude Code session (after pre-flight):

- *"run the research team on how we should approach X"*
- *"run the debate team on whether commit abc123 is safe to push"*
- *"run the brainstorm team on design alternatives for Y"*
- *"run the design-review team on the new auth flow"*
- *"run the improvement team to fix all bugs in module Z"*

The lead resolves the template, spawns teammates with the right tools and model, enforces circuit breakers, and writes results to `<cwd>/.claude/agent-team-runs/<run-id>/`.

## Roadmap

| Phase | Scope | Estimate |
|---|---|---|
| **A — v1 ship** | spec §14 phases 1–6 + G1–G5 patches + appendix B typo fix | ~7–8h |
| **B — trading-bot integration** | project-scope roles + 2 trading-bot templates + backup includes | ~3–4h |
| **C — system polish** | `/team` slash skill, history index, setup-folder mirror, overlap docs | ~2–3h |
| **D — deferred** | Hermes cron → team trigger, dashboard card, template chaining, cost budgets | TBD |

## Known limitations (inherited from Claude Code)

- **One team at a time per lead** · cleanup before creating a new one
- **No nested teams** · teammates cannot spawn their own teams
- **Lead is fixed** for the team's lifetime · no transfer
- **No `/resume` or `/rewind`** for in-process teammates · spawn new teammates after resume
- **Permissions set at spawn** · whole team inherits the lead's `--dangerously-skip-permissions`
- **Split panes need tmux or iTerm2** · in-process mode works everywhere else
- `skills` and `mcpServers` frontmatter on role files are **silently ignored** when used as a teammate · rely on `tools`, `model`, and the body system prompt

See [spec §12](docs/specs/2026-05-14-claude-code-agent-teams-design.md#12-known-claude-code-limitations-acknowledge-work-around) for the full table.

## Reference

- Official Claude Code agent-teams docs: https://code.claude.com/docs/en/agent-teams
- Claude Code subagents (related primitive): https://code.claude.com/docs/en/sub-agents
- Hooks (used for optional quality gates): https://code.claude.com/docs/en/hooks
