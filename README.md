# Claude Agent Teams

User-global library of pre-baked Claude Code agent-team templates and reusable role definitions. Replaces ad-hoc subagent prompts with structured teams that have known communication patterns, explicit circuit breakers, and per-project output archives.

**Status**: v1 implementation complete · post-impl refinements applied 2026-05-14 PM (silence-breaker, inbox-path archiving, DM-based plan-approval, forced-close on verdict, team_file_path normalization)

---

## What this is

Every Claude Code session that needs parallel work starts with writing fresh subagent prompts from scratch. This library pre-bakes the patterns. Five team templates cover ~80% of typical work; ten reusable roles compose those teams. Invoking a team becomes a one-line natural-language request: *"run the debate team on whether commit X is safe to ship."*

The library is **project-agnostic**. The same templates serve any codebase. Project-specific context (CLAUDE.md, MCP servers, skills) is loaded by Claude Code at teammate spawn time — not baked into templates.

## Browse

- [PLAYBOOK](PLAYBOOK.md) — the lead's 6-stage algorithm; authoritative for all team runs
- [Design spec](docs/specs/2026-05-14-claude-code-agent-teams-design.md) — 16 sections, full v1 architecture + G1–G5 patches + §3.4 hierarchy framing (see appendix D for post-impl refinements)
- [Architecture diagram](docs/diagrams/agent-teams-architecture.svg) — 6 panels, dark monospace (Panel 6 = invocation options)

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
├── teams/<team_name>/            (active runtime state; auto-managed)
│   ├── config.json               (members list)
│   └── inboxes/<name>.json       (per-teammate DM log — read by lead at Stage 5)
└── tasks/<team_name>/            (active task list state)

<any-project>/.claude/
├── agents/                       (project-scope role overrides — G3 patch)
└── agent-team-runs/              (per-project output archive)
    └── 2026-05-14T10-45_debate_rg-wiring/
        ├── manifest.json
        ├── summary.md
        ├── members/<role>.md
        └── comms/transcript.md   (assembled from ~/.claude/teams/.../inboxes/)
```

## How to invoke a team

Claude Code does **not** auto-load `PLAYBOOK.md` when you say "run the X team". One of the three options below must be in place, or the lead will improvise instead of following the 6-stage orchestration. See [diagram Panel 6](docs/diagrams/agent-teams-architecture.svg) for the visual.

### Option A — Project `CLAUDE.md` pointer (recommended, works today)

One-time setup per project. Add this section to `<project>/CLAUDE.md`:

```markdown
## Agent Teams

When the operator says "run the X team on Y" (where X is one of: research, debate, brainstorm, design-review, improvement), read `~/.claude/agent-team-templates/PLAYBOOK.md` and follow its 6-stage algorithm step by step. Do not improvise; the PLAYBOOK is authoritative.
```

After that, every invocation in this project is natural language: *"run the improvement team on the regime-config bugs"*.

### Option B — Explicit per-invocation (works today, friction)

No setup. Each invocation must include the PLAYBOOK pointer:

> *"Follow `~/.claude/agent-team-templates/PLAYBOOK.md` and run the improvement team on the regime-config bugs."*

Easy to forget the prefix; otherwise the lead won't follow the protocol.

### Option C — `/team` slash command (future, roadmap phase C)

Not built yet. When built, it will be a one-liner across all projects:

```
/team improvement regime-config bugs in trading-bot/src/regime/
```

The slash skill will load `PLAYBOOK.md` and parse args automatically.

## Quick start

After pre-flight + invocation setup (option A or B above):

- *"run the research team on how we should approach X"*
- *"run the debate team on whether commit abc123 is safe to push"*
- *"run the brainstorm team on design alternatives for Y"*
- *"run the design-review team on the new auth flow"*
- *"run the improvement team to fix all bugs in module Z"*

The lead resolves the template, spawns teammates with the right tools and model, enforces circuit breakers, and writes results to `<cwd>/.claude/agent-team-runs/<run-id>/`.

## Roadmap

| Phase | Scope | Status |
|---|---|---|
| **A — v1 ship** | spec §14 phases 1–6 + G1–G5 patches + appendix B typo fix | ✓ done 2026-05-14 |
| **A.5 — post-impl refinements** | silence-breaker (replaces idle-breaker), inbox-path archiving, DM-based plan-approval (drops native plan mode), forced-close on verdict, `team_file_path` normalization, MANDATORY task lifecycle on all 10 roles | ✓ done 2026-05-14 PM |
| **B — trading-bot integration** | project-scope roles + 2 trading-bot templates + backup includes + G4 CLAUDE.md propagation | pending · ~3–4h |
| **C — `/team` slash skill** | invocation option C from "How to invoke a team" above — one-line cross-project invoker | pending · ~2–3h |
| **D — deferred** | Hermes cron → team trigger, dashboard card, template chaining, cost budgets, history index | TBD |

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
