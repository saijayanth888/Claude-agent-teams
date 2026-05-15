<!--
  Sample CLAUDE.md snippet for using Claude Agent Teams in any project.

  Copy the content below into <your-project>/CLAUDE.md (append if the file
  already exists). After this is in place, the main Claude Code session
  knows to load PLAYBOOK.md when you invoke a team.

  Source of truth: https://github.com/<your-org>/claude-agent-teams
  (or wherever this repo lives — symlinked locally at
  ~/.claude/agent-team-templates/)
-->

## Agent Teams

When I say "run the X team on Y" (where X is one of: `research`, `debate`,
`brainstorm`, `design-review`, `improvement`), read
`~/.claude/agent-team-templates/PLAYBOOK.md` and follow its 6-stage algorithm
step by step. Don't improvise; the PLAYBOOK is authoritative.

**Team picker**:

- `research` — open-ended question, multiple angles explored in parallel
- `debate` — yes/no decision with adversarial stress-test (defender vs skeptic)
- `brainstorm` — generate a wide set of options before narrowing
- `design-review` — design something new, with critique built in
- `improvement` — **actually fix code** (only team that edits files)

Output lands at `<this-project>/.claude/agent-team-runs/<run-id>/` with
`summary.md`, `manifest.json`, `members/<role>.md`, and `comms/transcript.md`.

**Caveat (until G4 ships)**: the contents of this CLAUDE.md are NOT
automatically propagated to spawned teammates' prompts. For `improvement`
runs, include critical project conventions inline in the request
(e.g., "use poetry for tests", "don't touch the `secrets/` directory").
Read-only teams (research, debate, brainstorm, design-review) are safe
to run without this caveat.
