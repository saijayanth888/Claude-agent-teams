---
title: Claude Code Agent Teams — Reusable Team Library
version: v1
status: approved (pending implementation)
date: 2026-05-14
author: operator + Claude Opus 4.7
target_release: claude-agent-teams v1.0
---

# Claude Code Agent Teams — v1 Design

A user-global library of pre-baked agent-team templates and reusable roles, invokable from any Claude Code session in any project. Replaces ad-hoc subagent prompts with structured teams that have known communication patterns, explicit circuit breakers, and per-project output archives.

This spec is project-agnostic. The same library serves the trading-bot, future side-projects, and any other codebase the operator opens. Project context (CLAUDE.md, MCP servers, skills) is loaded by Claude Code at teammate spawn time — not baked into templates.

---

## 1. Motivation

Today, every session that needs parallel work begins with the operator (or Claude) writing fresh subagent prompts from scratch. The morning's `/ops` audit spawned six parallel subagents with bespoke 500-word briefs; the afternoon's RG-wiring review spawned two more with different bespoke briefs. Each session reinvents:

- Which roles compose a useful team
- How those roles should communicate
- What the output format should be
- What the circuit breaker / cleanup policy is

This recurring tax bloats the operator's context, bloats the lead's context, and produces inconsistent results. The fix is to pre-bake the patterns. Five team templates cover roughly 80% of the work the operator does in Claude Code; ten reusable roles compose those teams. Invoking a team becomes a one-line natural-language request ("run the research team on X"); the lead resolves the template, spawns the right teammates with the right tools and model, enforces the circuit breakers, and routes output to a per-project archive.

The library is user-global because Claude Code itself does not support project-level team config: `~/.claude/teams/` is the only location Claude Code recognizes for active team state, and `.claude/teams/teams.json` inside a project repo is treated as an ordinary file (per the agent-teams documentation). User-global also matches how skills, agents, and plugins are already organized.

---

## 2. Pre-flight setup (operator runs once)

### 2.1 Version requirement

Claude Code **v2.1.32 or later**. Check:

```bash
claude --version
```

If older, upgrade before installing this library.

### 2.2 Enable experimental agent teams

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Surface check: after restart, `TeamCreate`, `SendMessage`, and `TeamDelete` tools appear in the deferred tool registry.

### 2.3 Set `teammateMode`

Add to `~/.claude/settings.json`:

```json
{
  "teammateMode": "in-process"
}
```

**Why "in-process"**: maximum terminal portability. Split-pane mode (`"tmux"`) is nicer when available but is NOT supported in VS Code's integrated terminal, Windows Terminal, or Ghostty. The default `"auto"` works but silently varies behavior across sessions; pinning to `"in-process"` makes behavior predictable.

Operator overrides per session if desired: `claude --teammate-mode tmux`.

### 2.4 Configure default teammate model

Run `/config` once. Set **Default teammate model** to **"Default (leader's model)"**.

**Why**: teammates do NOT inherit the lead's `/model` selection by default. Without this setting, teammates spawn with whatever Claude Code's built-in default is, which is typically a smaller / cheaper model than the lead. Quality drops noticeably for synthesis and critic roles.

### 2.5 (Optional) Pre-approve teammate permissions

Teammate permission requests bubble up to the lead. To reduce interruption, pre-approve common operations in `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Read", "Glob", "Grep",
      "Bash(ls *)", "Bash(cat *)", "Bash(grep *)"
    ]
  }
}
```

(The operator already has most of these from a separate settings hardening done 2026-05-14.)

---

## 3. Architecture

### 3.1 Filesystem layout

```
~/.claude/
├── settings.json                 (operator-managed; pre-flight from §2)
├── agents/                       (Claude Code primitive — already exists)
│   ├── researcher.md             ← reusable role definitions, one per file
│   ├── scout.md
│   ├── synthesizer.md
│   ├── defender.md
│   ├── skeptic.md
│   ├── diverger.md
│   ├── critic.md
│   ├── designer.md
│   ├── builder.md
│   └── verifier.md
│
├── agent-team-templates/         (NEW — what this spec defines)
│   ├── README.md                 (operator entrypoint)
│   ├── PLAYBOOK.md               (lead's algorithm — how it runs a team)
│   ├── teams/
│   │   ├── research.md
│   │   ├── debate.md
│   │   ├── brainstorm.md
│   │   ├── design-review.md
│   │   └── improvement.md
│   └── roles/
│       └── README.md             (pointer to ~/.claude/agents/)
│
└── teams/                        (Claude Code primitive — active team state)
    └── (auto-managed; NEVER hand-edit)

<any-project>/.claude/agent-team-runs/   (per-project output archive)
└── 2026-05-14T10-45_debate_rg-wiring/
    ├── manifest.json
    ├── summary.md
    ├── members/
    │   ├── defender.md
    │   └── skeptic.md
    └── comms/
        └── transcript.md
```

**Key invariants**:

1. **Roles live in `~/.claude/agents/`** — the Claude Code primitive. They double as standalone subagents AND team members. No duplication.
2. **Templates live in `~/.claude/agent-team-templates/teams/`** — a new folder. Claude Code does not need to know about it; the lead Read-s the relevant file at invocation time.
3. **Active team state lives in `~/.claude/teams/<team-name>/`** — reserved by Claude Code, written automatically when `TeamCreate` is called. Never authored by hand.
4. **Run output lives in the project's own `.claude/agent-team-runs/`** — not user-global. The operator can `git add` if they want decisions archived in the repo, `gitignore` otherwise.

### 3.2 Template format

Templates are markdown with YAML frontmatter. Same convention as skills and agent definitions, so the operator's mental model carries over.

```markdown
---
name: debate
description: Adversarial review with explicit defender and skeptic positions
when_to_use: |
  Yes/no decisions where the strongest argument should win.
  Examples: "is this fix correct", "is this design ready", "should we
  ship X today".

members:
  - role: defender
    count: 1
  - role: skeptic
    count: 1

pattern: position-then-engage
kickoff: skeptic
output_artifact: verdict.md

require_plan_approval: false

limits:
  max_rounds: 5
  max_wall_minutes: 15
  max_idle_minutes: 3
---

# Debate team

(Markdown body follows — extended description, lead-playbook hints,
example invocation strings, output schema, etc.)
```

**Frontmatter fields (schema)**:

| Field | Type | Required | Description |
|---|---|---|---|
| `name` | string | yes | Matches the filename without `.md` |
| `description` | string | yes | One-line summary shown by `team list` (future v2 slash command) |
| `when_to_use` | string | yes | Multi-line guidance for the lead's "should I propose this team?" decision |
| `members` | list | yes | Array of `{role, count}`. `count` is either an integer (e.g. `1`) or an inclusive range string (e.g. `"3-5"` means 3, 4, or 5; the lead asks the operator to pick at invocation time). |
| `pattern` | enum | yes | One of: `parallel-then-sync`, `position-then-engage`, `diverge-critique-converge`, `sequential-with-critique-loop`, `pipeline-with-handoff-validation` |
| `kickoff` | string \| null | recommended | Role name that makes the first DM. `null` for parallel patterns where the lead orchestrates. Required for any pattern with bidirectional dialogue (otherwise teammates deadlock). |
| `output_artifact` | string | yes | Filename of the deliverable inside `summary.md`'s sibling location |
| `require_plan_approval` | bool | no | If `true`, the lead instructs teammates to enter plan mode before any file edits. Default `false`. Recommended `true` for `improvement` and `design-review` when they may touch files. |
| `limits.max_rounds` | int | yes | Maximum rounds of DM exchange before the lead force-shuts down |
| `limits.max_wall_minutes` | int | yes | Absolute timeout from spawn to forced shutdown |
| `limits.max_idle_minutes` | int | yes | If no DM activity for this many minutes, lead force-shuts down |

**Body**:

Free-form markdown. Sections recommended (but not enforced):

- `## When to use` — operator-facing guidance
- `## How members coordinate` — lead-facing description of the pattern
- `## What the lead does` — step-by-step playbook
- `## Output schema` — what `summary.md` should contain
- `## Example invocation` — natural-language strings that work

### 3.3 Role definitions

Roles live at `~/.claude/agents/<role>.md`. Format follows the standard Claude Code subagent definition schema:

```markdown
---
name: defender
description: Argues a position with file:line evidence; concedes when challenged convincingly
tools:
  - Read
  - Grep
  - Bash
model: sonnet
---

You are the **defender** in a debate team. Your role:

1. Read the artifact under review thoroughly. Build a complete mental
   model before posting your first message.
2. Claim your task via TaskUpdate.
3. Wait for the skeptic's opening attack (the kickoff role).
4. Defend with file:line evidence. Every claim cites a specific file
   and line.
5. Steelman the skeptic's attacks — when they have a point, concede;
   don't dig in on lost positions.
6. DM the skeptic via SendMessage when responding. Plain text, 3-5
   lines per message.
7. When debate concludes (max_rounds reached, or you and skeptic
   converge on a verdict, or limits enforced by lead), send your
   final position to the team-lead via SendMessage with three parts:
   (a) what's solid, (b) what's a real gap the skeptic found,
   (c) verdict (ship / gate / refactor-first).
8. Mark your task completed via TaskUpdate.

Constraints:
- READ-ONLY for the artifact (don't edit files)
- Refer to teammates by NAME (skeptic, team-lead)
- 3-5 line messages — fast back-and-forth beats wall-of-text
- Cap your participation when max_rounds is reached
```

**Important constraints inherited from Claude Code**:

1. **`tools` and `model` apply when used as a teammate.** Defining `tools: [Read, Grep, Bash]` correctly restricts the teammate.
2. **`SendMessage` and task tools are ALWAYS available** regardless of the `tools` restriction. Roles can't accidentally lock themselves out of team coordination.
3. **`skills` and `mcpServers` frontmatter fields are SILENTLY IGNORED when the role is used as a teammate.** They DO apply when the same role is invoked as a standalone subagent. **Do not write role files that depend on those fields.**
4. **Permissions are inherited from the lead at spawn time.** A role file cannot set per-teammate permissions. The lead's `--dangerously-skip-permissions`, if set, propagates to every teammate.

### 3.4 Mental model — the hierarchy is already there

It's natural to wonder if the system needs an additional coordinator layer above the team lead — a product owner above a tech lead above developers. It doesn't. That hierarchy is already baked into the architecture; it just isn't labeled.

| Layer | Who plays it | Responsibility |
|---|---|---|
| **Product owner** | the operator | sets goals, picks the template, accepts or rejects the deliverable |
| **Tech lead** | the main Claude Code session (= team lead) | translates goal → team plan, spawns teammates, judges plan approvals, enforces circuit breakers, synthesizes `summary.md` |
| **Developers** | the spawned teammates | execute focused, scoped tasks; coordinate via DMs and the shared task list |

The lead is **not** a thin task-router. It is the tech lead: it judges plan-approval requests (§8.5, planned), enforces the three circuit breakers (§8.1), and writes the final synthesis. The operator is the PO: they set scope, accept the verdict, and decide what happens next.

This framing matters when explaining the system to a second operator. It makes "where does my intent end and Claude's autonomy begin" obvious: at the PO ↔ tech-lead handoff — the moment you say "run the X team on Y" and the lead takes over until it hands you back a `summary.md`.

**Vocabulary note**: Claude Code's primitive is literally called the *team lead*. "Tech lead" is the mental model; "team lead" is the implementation term. The two refer to the same Claude session.

**Two things this framing deliberately does NOT do:**

1. It does NOT add a `product-owner` or `tech-lead` role file to `~/.claude/agents/`. The PO is the operator. The tech lead is the main session. Codifying them as spawnable roles would falsely suggest they can be swapped, which Claude Code's "lead is fixed" limitation forbids.
2. It does NOT rename anything in code or configs. Pure documentation framing.

When v2 introduces template chaining (§16), the vocabulary upgrades cleanly: the PO chains multiple tech-lead engagements end-to-end.

---

## 4. The 5 teams

### 4.1 research

**Pattern**: `parallel-then-sync`

**Members**: 3-5 researchers (operator picks count by complexity), 1 synthesizer

**Use when**: open-ended question where multiple independent angles exist. "Investigate X", "audit Y", "what could be wrong with Z".

**Flow**:
1. Lead spawns N researchers in parallel, each on a distinct angle. No kickoff needed.
2. Each researcher works alone, no inter-talk during scout phase.
3. As researchers go idle, lead spawns the synthesizer with all their reports.
4. Synthesizer reads everything, identifies tensions, DMs individual researchers with cross-check questions.
5. Researchers defend or concede in 1-2 rounds.
6. Synthesizer produces `synthesis.md` and DMs the lead.

**Output**: `summary.md` (the synthesis) + per-member reports.

**Default limits**: `max_rounds=3, max_wall_minutes=30, max_idle_minutes=5`.

### 4.2 debate

**Pattern**: `position-then-engage`

**Members**: 1 defender, 1 skeptic (lead is the judge — no third teammate)

**Use when**: yes/no decision where adversarial pressure improves quality. "Is this fix correct", "is this design ready", "should we ship X today".

**Flow**:
1. Lead spawns both teammates.
2. Skeptic (kickoff role) opens with strongest attack via DM to defender.
3. Defender rebuts or concedes; cycle 3-5 rounds.
4. Both deliver final verdict to the lead via DM with: confirmed gaps, rebutted attacks, ship/refactor recommendation.
5. Lead synthesizes the two verdicts.

**Output**: `summary.md` (the lead's synthesis) + `defender.md` + `skeptic.md` final positions + full DM transcript.

**Default limits**: `max_rounds=5, max_wall_minutes=15, max_idle_minutes=3`.

### 4.3 brainstorm

**Pattern**: `diverge-critique-converge`

**Members**: 3 divergers, 1 critic, 1 synthesizer

**Use when**: generative ideation where divergent thinking precedes convergence. "What are the design alternatives for X", "feature ideation for Y", "refactor approaches for Z".

**Flow**:
1. Lead spawns 3 divergers in parallel with the same prompt. No inter-talk.
2. Each diverger emits 5-10 ideas without self-filter.
3. Lead spawns the critic with all 3 idea sets concatenated.
4. Critic kills bad ideas with specific reasons. DMs each diverger with rejections (divergers may push back once per rejected idea).
5. Surviving ideas + rejection reasons → lead spawns the synthesizer.
6. Synthesizer organizes survivors into coherent direction + rejected-and-why appendix.

**Output**: `summary.md` (organized ideas) + `rejected.md` (with reasons) + per-diverger raw idea sets.

**Default limits**: `max_rounds=2, max_wall_minutes=20, max_idle_minutes=4`.

### 4.4 design-review

**Pattern**: `sequential-with-critique-loop`

**Members**: 1 scout, 1 designer, 1 critic (lead is the decider)

**Use when**: architectural or UX decision with built-in critique. "Design the X system", "approach A vs B", "redesign the Y page".

**Flow**:
1. Lead spawns the scout.
2. Scout maps existing system state + constraints, posts findings to lead and designer (DMs designer when done).
3. Designer proposes a design based on scout's findings, posts to lead and critic.
4. Critic challenges design from blind-spot angles, DMs designer with concerns.
5. Designer revises (1-2 iterations max).
6. Lead receives final design + critic's residual concerns.

**Output**: `summary.md` (final design + decision summary) + `residual-concerns.md` (critic's unresolved objections).

**Default limits**: `max_rounds=2, max_wall_minutes=25, max_idle_minutes=5`. Recommended `require_plan_approval: true` if the design may produce code in a follow-up.

### 4.5 improvement

**Pattern**: `pipeline-with-handoff-validation`

**Members**: 1 scout, 1 builder, 1 verifier

**Use when**: find issues in existing code AND execute the fixes. "Fix all bugs in X", "refactor Y for clarity", "clean up Z".

**Flow**:
1. Lead spawns the scout.
2. Scout audits target, produces issue list with file:line + severity. DMs builder when done.
3. Builder implements fixes. May DM scout for ambiguity clarification.
4. Builder DMs verifier when each fix lands.
5. Verifier runs tests, smoke-checks, catches regressions. DMs builder with failures.
6. Builder iterates until verifier signs off. Both DM lead with final state.

**Output**: `summary.md` (overview of changes) + `changes.md` (file:line diffs and rationale) + `test-results.md` (verification log).

**Default limits**: `max_rounds=10, max_wall_minutes=60, max_idle_minutes=5`. Recommended `require_plan_approval: true` (builder edits files).

---

## 5. The 10 roles

All live at `~/.claude/agents/<role>.md`. Default model: `sonnet` (operator override via `/config` Default Teammate Model).

| Role | `tools` allowlist | Distinguishing characteristic |
|---|---|---|
| **researcher** | Read, Grep, WebSearch, WebFetch, Bash(read-only) | Investigates a focused question; produces structured findings with citations across code AND web |
| **scout** | Read, Grep, Glob, Bash(read-only) | Maps existing state in a codebase without proposing changes. No web access. |
| **synthesizer** | Read, Grep | Reads N reports, identifies tensions, produces unified output. No code editing. |
| **defender** | Read, Grep, Bash | Argues a position with file:line evidence. Read access to artifact only. |
| **skeptic** | Read, Grep, Bash | Attacks a position; hunts blind spots. Read access to artifact only. |
| **diverger** | Read | Generates novel ideas without self-filter. Minimal tools to encourage abstract thinking. |
| **critic** | Read, Grep | Challenges design proposals with rigorous skepticism. |
| **designer** | Read, Grep | Proposes structured solution given scout's map and constraints. Output is markdown, not code. |
| **builder** | Read, Edit, Write, Bash | Implements code/config changes. Only role with write access. |
| **verifier** | Read, Bash, Grep | Runs tests, smoke-checks, catches regressions. No edit capability. |

**Why each role exists separately (no merging)**:

- **researcher vs scout**: researcher answers questions across the web AND code; scout maps code state only. Different read scope, different output shape.
- **critic vs skeptic**: critic challenges DESIGN proposals (forward-looking); skeptic attacks POSITIONS (backward-looking, defends-the-status-quo mode). Different attack vocabulary.
- **synthesizer vs designer**: synthesizer merges multiple inputs into one; designer proposes a structured solution from scratch. Different output direction (merge vs create).

The 10 roles together cover all 5 templates without redundancy. Each role's `tools` allowlist makes it safe to compose — `scout` literally cannot Edit; `builder` literally cannot WebSearch.

---

## 6. The 5 communication patterns

| Pattern | Used by | Description |
|---|---|---|
| `parallel-then-sync` | research | N workers parallel, single integrator cross-checks after all are idle |
| `position-then-engage` | debate | 2 opposites, multi-round adversarial dialogue, judge synthesizes |
| `diverge-critique-converge` | brainstorm | divergers → critic kills bad → synthesizer organizes survivors |
| `sequential-with-critique-loop` | design-review | linear pipeline, critic loops back to designer 1-2× |
| `pipeline-with-handoff-validation` | improvement | linear pipeline, verifier gates handoff back to builder |

Each is documented in `PLAYBOOK.md` with a step-by-step description of what the lead does at each stage. Future templates can pick from the same vocabulary.

---

## 7. Invocation flow (lead's playbook)

When the operator says **"run the debate team — is yesterday's RG wiring ready to ship"** (or any equivalent):

```
STAGE 1 — Resolve template and roles
─────────────────────────────────────
1. Read ~/.claude/agent-team-templates/teams/debate.md
2. Parse frontmatter:
   - members: [defender × 1, skeptic × 1]
   - pattern: position-then-engage
   - kickoff: skeptic
   - limits: max_rounds=5, max_wall_minutes=15, max_idle_minutes=3
   - require_plan_approval: false
3. For each member's role, Read ~/.claude/agents/<role>.md to confirm it exists.
   Fail fast if any role is missing.
4. If members.count is a range (e.g. "3-5"), AskUserQuestion to pick within range.

STAGE 2 — Create team and tasks
───────────────────────────────
5. team_name = "<template>-<YYYY-MM-DDTHH-MM>"
6. TeamCreate(team_name, description=<operator's request>)
7. TaskCreate one per teammate, with subject describing their role assignment.

STAGE 3 — Spawn teammates
─────────────────────────
8. For each member:
   Agent(
     subagent_type="<role>",       ← from ~/.claude/agents/<role>.md
     team_name=team_name,           ← MAKES IT A REAL TEAM MEMBER (not subagent)
     name="<role>",                 ← addressable name for DMs
     prompt="<role body>" + "<task-specific context>" + "<kickoff hint if applicable>"
   )

STAGE 4 — Orchestrate the pattern
──────────────────────────────────
9. Pattern-specific (see PLAYBOOK.md for each pattern). For position-then-engage:
   - Wait for kickoff role's first DM
   - Each round: count DMs, increment round_counter
   - When round_counter >= max_rounds: SendMessage(shutdown_request) to all
   - Poll team task store mtime; if no activity > max_idle_minutes: SendMessage(shutdown_request) to all
   - If wall_clock > max_wall_minutes: SendMessage(shutdown_request) to all

STAGE 5 — Collect and archive
─────────────────────────────
10. As teammates send final verdicts, capture each message.
11. mkdir -p <cwd>/.claude/agent-team-runs/<team_name>/{members,comms}/
12. Write manifest.json (template, time, members, task, status, limits_enforced).
13. Write summary.md (lead's synthesis, the deliverable).
14. Write members/<role>.md (each teammate's final verdict).
15. Write comms/transcript.md (full DM log if accessible via team task store).
16. TeamDelete (will fail if teammates still running — shutdown_request first).

STAGE 6 — Report to operator
────────────────────────────
17. Inline summary in the conversation: outcome + key findings.
18. Pointer to archive: "Full output at <cwd>/.claude/agent-team-runs/<team_name>/"
```

---

## 8. Circuit breakers (mandatory, enforced by lead)

Three layers of protection against runaway teams:

### 8.1 Template-level limits (per-template, frontmatter)

Every template specifies its three limits:

```yaml
limits:
  max_rounds: 5            # cap dialogue rounds
  max_wall_minutes: 15     # absolute timeout from spawn
  max_idle_minutes: 3      # auto-shutdown if no DM activity
```

The lead enforces these by:
- Counting rounds (per DM exchange in position-then-engage / design-review)
- Tracking wall clock from `TeamCreate` timestamp
- Polling `~/.claude/tasks/<team>/` directory mtime every 30 seconds to detect idle silence (any task-file mtime newer than `now - max_idle_minutes` = team is active)

When any limit is reached: lead sends `{"type": "shutdown_request"}` to every teammate, then `TeamDelete`.

### 8.2 Kickoff explicitness (deadlock prevention)

Every template with bidirectional dialogue MUST specify the `kickoff` role. The role that makes the first DM is told in its spawn prompt:

> "You are the kickoff role for this team. Send your opening DM to <peer> immediately after reading the artifact."

Templates with `kickoff: null` are pure parallel (research, brainstorm) — no deadlock risk since no inter-DM required.

This was the bug the alice/bob ghost run exposed: both teammates said "waiting for the other" and neither moved. Fixed by mandatory `kickoff` for any bidirectional template.

### 8.3 Hooks (optional, operator-installed quality gates)

In `~/.claude/settings.json[hooks]`, operator can add:

```json
{
  "hooks": {
    "TeammateIdle": [{
      "hooks": [{
        "type": "command",
        "command": "echo 'check' && exit 0"
      }]
    }],
    "TaskCompleted": [{
      "matcher": "improvement-*",
      "hooks": [{
        "type": "command",
        "command": "pytest tests/ -q; [ $? -eq 0 ] || exit 2"
      }]
    }]
  }
}
```

**Hook semantics** (from Claude Code agent-teams docs):
- `TeammateIdle` — runs when a teammate is about to go idle. Exit code 2 sends feedback to that teammate AND keeps them working (prevents the idle).
- `TaskCreated` — runs when a task is being created. Exit 2 prevents creation, sends feedback.
- `TaskCompleted` — runs when a task is marked complete. Exit 2 prevents completion, sends feedback.

Hooks are OPTIONAL — every template's limits work without them. Hooks add a second layer for hard quality gates (e.g., "tests must pass before claiming a fix is done").

### 8.4 Operator interrupt (always honored)

If the operator interrupts the lead (Ctrl+C / Escape), the lead's cleanup must:
1. SendMessage(shutdown_request) to every active teammate
2. Wait briefly (up to ~30s; shutdown can be slow per Claude Code docs)
3. TeamDelete
4. Report partial output (what was collected so far) to the operator

---

## 9. Spawn correctness (the lesson from alice/bob)

For teammates to actually join a team and DM each other, the `Agent` tool MUST be called with `team_name` AND `name` parameters:

```python
# WRONG — runs as parallel subagent, completes, can't DM
Agent(subagent_type="defender", prompt="...")

# RIGHT — becomes a live team member with mailbox
Agent(subagent_type="defender", team_name="<team>", name="defender", prompt="...")
```

The `PLAYBOOK.md` documents this explicitly. Lead implementations MUST follow it.

How to verify: after spawning, read `~/.claude/teams/<team>/config.json` and confirm the spawned member appears in the `members` array (alongside the auto-registered team-lead).

---

## 10. Memory / output layout (per run)

```
<cwd>/.claude/agent-team-runs/<team_name>/
├── manifest.json
├── summary.md
├── members/
│   └── <role>.md         (one per member)
└── comms/
    └── transcript.md
```

### 10.1 `manifest.json` schema

```json
{
  "team_name": "debate-2026-05-14T10-45",
  "template": "debate",
  "task": "is yesterday's RG wiring ready to ship",
  "cwd": "/home/saijayanthai/Documents/trading-bot",
  "created_at": "2026-05-14T14:45:12Z",
  "completed_at": "2026-05-14T14:58:03Z",
  "status": "completed",
  "limits_enforced": [],
  "members": [
    {"name": "defender", "role": "defender", "model": "claude-opus-4-7[1m]"},
    {"name": "skeptic",  "role": "skeptic",  "model": "claude-opus-4-7[1m]"}
  ],
  "rounds_used": 4,
  "wall_minutes_used": 12.85
}
```

### 10.2 `summary.md`

The lead's synthesis. Format depends on template's `output_artifact` field; e.g., for debate it's a verdict (ship / gate / refactor) with confirmed gaps and rebutted attacks.

### 10.3 `members/<role>.md`

Each teammate's final position. Used by the operator for forensic review ("why did the skeptic concede that point?").

### 10.4 `comms/transcript.md`

Full inter-teammate DM log. Critical for debate / design-review where the dialogue IS the value. Captured by polling the team task store + the lead's received-message queue.

### 10.5 Recommended `.gitignore`

The operator should add to their per-project `.gitignore`:

```
.claude/agent-team-runs/
```

This is the safe default — most team runs are exploratory and don't need to live in git history. For runs the operator wants to preserve as a decision record (e.g. a debate that resolved a critical V4 cutover question), the operator can `git add -f .claude/agent-team-runs/<specific-run>/` to override the ignore for that one run. The README documents this pattern.

---

## 11. README structure (operator entrypoint)

Lives at `~/.claude/agent-team-templates/README.md`. ~300 lines, structured as:

```markdown
# Claude Code Agent Teams

Pre-baked patterns for running multi-agent teams from any Claude Code session.

## Pre-flight (do once)
1. Claude Code v2.1.32+
2. Add CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 to ~/.claude/settings.json
3. Add "teammateMode": "in-process" to ~/.claude/settings.json
4. Run /config, set "Default teammate model" to "Default (leader's model)"

## Quick start
In any Claude Code session:
- "run the research team on <topic>"
- "run the debate team on <decision>"
- "run the brainstorm team on <problem>"
- "run the design-review team on <system>"
- "run the improvement team on <target>"

## The 5 teams
[table from §4]

## The 10 roles
[table from §5]

## The 5 communication patterns
[table from §6]

## How invocation works
[link to PLAYBOOK.md]

## How to add a new team
1. Write a new .md in teams/ with frontmatter + body
2. If a new role is needed, write a .md in ~/.claude/agents/
3. Done. No code, no registration, no restart.

## Caveats inherited from Claude Code
- Each teammate is a live Claude session — token costs scale linearly
- No /resume or /rewind support for in-process teammates
- One team active at a time per lead
- Lead is fixed for the team's lifetime
- Split panes require tmux or iTerm2 (in-process recommended)
- Permissions are set at spawn from lead's settings

## Versioning
v1: templates only, manual natural-language invocation.
v2 candidates: /team slash command, web dashboard, Hermes cron integration,
self-improving templates, project-aware default model selection.
```

---

## 12. Known Claude Code limitations (acknowledge, work around)

From the agent-teams documentation:

| Limitation | Our workaround |
|---|---|
| No `/resume` or `/rewind` restoration of teammates | After resume, operator tells the lead to "spawn new teammates" |
| Task status can lag (teammates may fail to mark completed) | Lead polls task store mtime in addition to task state |
| Shutdown can be slow (current call finishes first) | `max_wall_minutes` includes ~30-60s headroom in template defaults |
| One team at a time per lead | v1 is single-team; no concurrent invocations |
| No nested teams | Templates can't spawn sub-teams; deeper work happens within a teammate |
| Lead is fixed | Can't transfer leadership mid-flight; operator restarts to change leads |
| Permissions set at spawn | Templates can't specify per-role permission modes; whole team inherits lead's |
| Split panes need tmux / iTerm2 (NOT VS Code terminal, Windows Terminal, Ghostty) | README recommends `teammateMode: "in-process"` for portability |
| `skills` / `mcpServers` frontmatter NOT applied when role used as teammate | Role files do NOT use those fields; rely only on `tools`, `model`, body |
| Teammates DO NOT inherit lead's `/model` | Pre-flight step 2.4: set Default Teammate Model in `/config` |

---

## 13. v1 explicit non-goals (YAGNI)

The following are deliberately OUT of v1:

- ❌ Slash command (`/team research X`) — v1 uses plain English to the lead
- ❌ Dashboard UI for team management
- ❌ Hermes cron integration (scheduled team fires)
- ❌ Self-improving / learning templates
- ❌ Token cost tracking and budgets per team
- ❌ Per-project default-team configuration
- ❌ Cross-project team invocation history
- ❌ Templates that reference specific projects, files, or endpoints

All of these are candidates for v2 / v3. v1 stays a folder full of markdown and one PLAYBOOK.

---

## 14. Implementation order (high-level)

The detailed plan comes from the `writing-plans` skill in the next phase. High-level:

1. **Phase 1 — Skeleton** (~30 min)
   - Create `~/.claude/agent-team-templates/` with README.md and PLAYBOOK.md stubs
   - Decide on exact `tools` allowlist per role (refine §5 table)

2. **Phase 2 — Roles** (~1.5 hours)
   - Write 10 role files at `~/.claude/agents/<role>.md`
   - Each role: frontmatter (name, description, tools, model) + body system prompt
   - Smoke-test each role as a standalone subagent (works in isolation before teaming)

3. **Phase 3 — Templates** (~2 hours)
   - Write 5 team templates at `~/.claude/agent-team-templates/teams/*.md`
   - Each template: full frontmatter + body sections (when to use, coordination, lead playbook excerpt, output schema, example invocation)

4. **Phase 4 — PLAYBOOK** (~1 hour)
   - Document the 6-stage invocation flow in detail
   - Document each of the 5 communication patterns step-by-step
   - Include explicit "WRONG vs RIGHT" examples for spawn correctness

5. **Phase 5 — README** (~45 min)
   - Operator-facing entrypoint
   - Pre-flight checklist
   - Quick-start examples
   - Caveats

6. **Phase 6 — Live smoke test** (~30 min)
   - Invoke each of the 5 teams on a real task (small scope each)
   - Verify output archive is created at `<cwd>/.claude/agent-team-runs/`
   - Verify circuit breakers fire on intentional violations
   - Fix any deadlocks, missing kickoffs, role tool gaps

Total v1 estimate: **~6-7 hours** of focused work.

---

## 15. Success criteria

v1 ships successfully when:

- All 5 teams invokable by natural language ("run the X team on Y")
- All 10 roles work as both standalone subagents AND team members
- Each team produces a `summary.md` deliverable in the project's `.claude/agent-team-runs/<run-id>/`
- Circuit breakers fire correctly in synthetic violations (test: spawn debate with `max_rounds=1`, confirm forced shutdown after one exchange)
- A second operator (or the same operator on a different machine) can install v1 by:
  1. Cloning the agent-teams repo to `~/.claude/agent-team-templates/`
  2. Symlinking or copying `~/.claude/agents/` from the repo's `agents/` folder
  3. Running the pre-flight checklist (§2)
  4. Saying "run the research team on <test topic>"
  - Result: a team runs end-to-end and produces output

---

## 16. Open questions (post-v1)

- How does v2 surface team-run history across projects? A `~/.claude/agent-team-history/index.json` that's appended after each run?
- Should templates support `dependencies: [other-template]` for chaining? (e.g., research → design-review → improvement as a single super-flow)
- How does the operator override member counts at invocation time? "Run research with 5 instead of 3" — parsed by the lead from natural language, or explicit prompt syntax?
- Should the library ship a `--dry-run` mode that prints the plan without spawning teammates? Useful for first-time users.

These are not blockers for v1.

---

## Appendix A — Example template file (debate.md, complete)

```markdown
---
name: debate
description: Adversarial review with explicit defender and skeptic positions
when_to_use: |
  Yes/no decisions where the strongest argument should win.
  Examples:
  - "is this fix correct and ready to ship"
  - "is this design proposal sound"
  - "should we adopt approach A or B"
  Not for: open-ended research (use research), generative ideation
  (use brainstorm), or implementation tasks (use improvement).

members:
  - role: defender
    count: 1
  - role: skeptic
    count: 1

pattern: position-then-engage
kickoff: skeptic
output_artifact: verdict.md

require_plan_approval: false

limits:
  max_rounds: 5
  max_wall_minutes: 15
  max_idle_minutes: 3
---

# Debate team

## When to use
Use this team when you have a specific YES/NO decision and want
adversarial pressure to surface weaknesses. The defender argues
the position is correct; the skeptic attacks it. Both deliver
final verdicts to the lead, who synthesizes a recommendation.

## How members coordinate
1. Lead spawns defender + skeptic.
2. Skeptic (kickoff) opens with strongest attack via DM to defender.
3. Defender rebuts or concedes; cycle continues.
4. After `max_rounds` rounds OR both teammates DM the lead with
   final verdicts, the lead synthesizes.

## What the lead does
- Counts DM rounds (each defender↔skeptic exchange = 1 round)
- Enforces all three limits (rounds, wall time, idle)
- On limit breach: SendMessage shutdown_request to both, then TeamDelete
- Reads both final verdicts, writes synthesis to summary.md

## Output schema
summary.md sections:
- Verdict (ship / gate-on-X / refactor-first)
- Confirmed gaps the skeptic found
- Attacks the defender successfully rebutted
- Recommended next action

## Example invocation
"run the debate team on whether commit abc123 is safe to push to main"
```

---

## Appendix B — Example role file (skeptic.md, complete)

```markdown
---
name: skeptic
description: Attacks a position with concrete file:line evidence; drops attacks the defender rebuts convincingly
tools:
  - Read
  - Grep
  - Bash
model: sonnet
---

You are the **skeptic** in a debate team. Your role: hunt for gaps in
the artifact under review. Find real bugs, not theoretical ones.

## Your team
- **defender** is the other teammate. They will rebut your attacks.
  DM them via SendMessage(to="defender", message=...).
- **team-lead** is the human's main Claude Code session. When debate
  concludes, DM them with your final position.

## Your job
1. Read the artifact thoroughly before posting anything.
2. Claim your task via TaskUpdate(taskId="<your-task>",
   owner="skeptic", status="in_progress").
3. **You are the kickoff role** — open with your strongest attack.
   First DM to defender within 2 minutes of spawn.
4. Cycle: defender rebuts → you concede or counter with new attack →
   continue for max_rounds rounds.
5. Be honest: if defender convincingly defends, drop that attack and
   find a new one. Don't dig in on lost positions.
6. When debate ends (max_rounds reached OR lead sends shutdown_request),
   DM team-lead with: (a) confirmed gaps, (b) attacks defender rebutted,
   (c) verdict (ship / gate / refactor-first).
7. Mark your task completed via TaskUpdate.

## Constraints
- READ-ONLY. Don't edit anything.
- Plain text messages, 3-5 lines each. No structured JSON status.
- Refer to teammates by NAME (defender, team-lead). Never by UUID.
- Every claim cites file:line. No hand-waving.
- Don't fabricate bugs — every attack needs a real failure mode.
```

---

## Appendix C — Diagram (mental model)

See: [pictures embedded in chat 2026-05-14, panels 1-3]
Panel 1: Filesystem layout
Panel 2: Invocation flow lifecycle
Panel 3: The 5 communication patterns side-by-side

(Will be reproduced in `~/.claude/agent-team-templates/docs/` as `.svg` once
implementation phase begins.)

---

**End of v1 design spec.**
