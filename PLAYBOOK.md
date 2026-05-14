# PLAYBOOK — the team-lead's algorithm

This document tells the team-lead (the main Claude Code session that the operator invokes a team from) how to run any of the five teams. Read this at every invocation. Do NOT improvise — follow it step by step.

---

## STAGE 1 — Resolve template and roles

When the operator says "run the X team on Y":

1. Determine X (template name). Match against `teams/*.md` in this folder (and project-scope first per G3).
2. **[G3] Resolution order for roles**: `<cwd>/.claude/agents/<role>.md` ▸ `~/.claude/agents/<role>.md` ▸ plugin scope ▸ CLI-defined. Use the first that exists.
3. Read the template's `.md` file. Parse YAML frontmatter:
   - `members` (list with role + count)
   - `pattern` (one of 5 enumerated)
   - `kickoff` (role name or null)
   - `output_artifact` (filename)
   - `require_plan_approval` (bool, default false)
   - `limits` (max_rounds, max_wall_minutes, max_idle_minutes)
4. For each member's role, confirm the role file exists at the resolved path. **Fail fast** if any role is missing — tell the operator which.
5. If any member's `count` is a range (e.g. `"3-5"`), invoke AskUserQuestion to let the operator pick within range.

## STAGE 2 — Create team and tasks

6. `team_name = "<template>-<YYYY-MM-DDTHH-MM>"` (e.g. `debate-2026-05-14T10-45`).
7. Call `TeamCreate(team_name, description=<operator's request>)`.
8. Call `TaskCreate` once per teammate, with subject describing their role assignment.
9. **[G2] For pipeline patterns** (`improvement`, `pipeline-with-handoff-validation`), set task dependencies:
   - builder's task depends on scout's task completing.
   - verifier's task depends on each builder fix landing (one task per fix; chain dependencies).
   - This enables self-claiming via Claude Code's native task-dep system; reduces DM coordination overhead.

## STAGE 3 — Spawn teammates

10. For each member, call `Agent` with **all three** keys:
    ```
    Agent(
      subagent_type=<role>,        # MUST match the role file's name field
      team_name=<team_name>,       # MAKES IT A REAL TEAM MEMBER (not a subagent)
      name=<role>,                 # addressable name for inter-teammate DMs
      prompt=<role body> + <task-specific context> + <kickoff hint if applicable>
    )
    ```
11. **WRONG**: `Agent(subagent_type="defender", prompt="...")` — this runs as a parallel subagent, completes once, cannot DM. (This was the alice/bob ghost-run bug.)
12. **RIGHT**: include both `team_name` AND `name`. Verify by reading `~/.claude/teams/<team_name>/config.json` and confirming the spawned member appears in `members[]`.

## STAGE 4 — Orchestrate the pattern

Pattern-specific. Pick the section matching the template's `pattern` field.

### 4A. `parallel-then-sync` (research)

- Spawn N workers in parallel (Stage 3, all in one batch).
- Wait until ALL workers DM team-lead with their reports.
- Spawn the synthesizer with all reports concatenated in its spawn prompt.
- Wait for synthesizer to DM team-lead. May involve 1-2 cross-check rounds; let the synthesizer drive.
- Enforce circuit breakers throughout.

### 4B. `position-then-engage` (debate)

- Spawn both teammates (defender + skeptic).
- Skeptic is the kickoff role. Confirm via the spawn-prompt instruction: "You are the kickoff role; send your opening DM to defender immediately."
- Watch DM exchanges; each round = one defender↔skeptic exchange.
- When max_rounds reached OR both DM team-lead with final verdicts (whichever first), proceed to Stage 5.

### 4C. `diverge-critique-converge` (brainstorm)

- Spawn 3 divergers in parallel with identical prompts.
- Wait for all 3 to DM team-lead with idea sets.
- Spawn critic with concatenated idea sets.
- Critic DMs each diverger with rejections. Each diverger may push back ONCE per rejected idea.
- After critic's task completes, spawn synthesizer with survivors + reasons.
- Wait for synthesizer to DM team-lead.

### 4D. `sequential-with-critique-loop` (design-review)

- Spawn scout. Scout is kickoff; will DM designer when done.
- Wait for scout's DM to designer to land in mailbox.
- Spawn designer. Designer reads scout's DM via Read on `~/.claude/tasks/<team>/`.
- [G1] If `require_plan_approval=true`, designer's initial proposal enters plan mode. Receive plan-approval request. **Judge criteria** for design-review: proposal must include `Files affected`, `Tradeoffs`, `Open questions` sections. Approve if present; reject with specific missing-section feedback otherwise.
- Spawn critic once designer's first proposal is shared.
- Watch critic-designer loop (max 2 rounds).
- When designer DMs team-lead with final design, proceed to Stage 5.

### 4E. `pipeline-with-handoff-validation` (improvement)

- Spawn scout. Scout is kickoff; will DM builder when done.
- [G2] Builder's task has dependency on scout's; builder self-claims when scout completes.
- [G1] Builder enters plan mode (require_plan_approval=true for improvement). **Judge criteria** for improvement: plan must include `Files affected`, `Test impact`, `Rollback notes` sections. Approve if all present.
- After approval, builder edits files one at a time.
- [G2] Verifier's task chain: one verifier subtask per builder fix; verifier self-claims as builder completes each.
- Builder ↔ verifier loop until all fixes pass OR max_rounds (10) reached.
- Final state: both DM team-lead with summary.

## STAGE 5 — Collect and archive

Throughout the team's run:

- Track wall clock from `TeamCreate` timestamp.
- Poll `~/.claude/tasks/<team>/` directory mtime every ~30s to detect idle. If `now - mtime > max_idle_minutes`, force shutdown.
- Count rounds appropriately per pattern.
- If any limit is breached: SendMessage `{"type": "shutdown_request"}` to every teammate. Wait briefly (≤30s) for graceful shutdown.

When teammates finish OR shutdown completes:

13. Capture each teammate's final-verdict DM.
14. `mkdir -p <cwd>/.claude/agent-team-runs/<team_name>/{members,comms}/`
15. Write `manifest.json`:
    ```json
    {
      "team_name": "<team_name>",
      "template": "<template>",
      "task": "<operator's request>",
      "cwd": "<absolute path>",
      "created_at": "<ISO 8601>",
      "completed_at": "<ISO 8601>",
      "status": "completed" | "shutdown_max_rounds" | "shutdown_max_wall" | "shutdown_idle",
      "limits_enforced": ["<which limit if any>"],
      "members": [
        {"name": "<name>", "role": "<role>", "model": "<model>"}
      ],
      "rounds_used": <int>,
      "wall_minutes_used": <float>,
      "estimated_token_cost": <int>
    }
    ```
    The `estimated_token_cost` field is the [G5] tally: `members × wall_minutes × ~5000 tok/min` as a coarse placeholder. Refined in a future version.
16. Write `summary.md` — the synthesis per the template's `output_artifact` schema.
17. Write `members/<role>.md` — each teammate's final verdict.
18. Write `comms/transcript.md` — full DM log (read from team task store).
19. Call `TeamDelete(team_name)`. If teammates still active, send shutdown first.

## STAGE 6 — Report to operator

20. Inline summary in the conversation: outcome + key findings (3-10 lines).
21. Pointer to archive: `Full output at <cwd>/.claude/agent-team-runs/<team_name>/`

---

## Circuit breakers (mandatory)

Three layers; enforce all of them at every invocation.

### Per-template (frontmatter)

```yaml
limits:
  max_rounds: <int>
  max_wall_minutes: <int>
  max_idle_minutes: <int>
```

The lead enforces by:
- Counting rounds (per DM exchange in position-then-engage / design-review; per builder-fix in improvement)
- Tracking wall clock from `TeamCreate` timestamp
- Polling task-store directory mtime every 30 seconds

### Kickoff explicitness (deadlock prevention)

Every template with bidirectional dialogue MUST specify `kickoff`. The role spawned as kickoff is told in its prompt: "You are the kickoff role; send your opening DM to <peer> immediately."

Templates with `kickoff: null` are pure parallel (research, brainstorm) — no deadlock risk.

### Operator interrupt (always honored)

If operator interrupts (Ctrl+C / Escape):
1. SendMessage shutdown_request to every active teammate
2. Wait briefly (≤30s — shutdown can be slow per Claude Code docs)
3. TeamDelete
4. Report partial output to operator with what was collected

---

## Spawn-correctness checklist

Before AND after Stage 3, verify:

- [ ] Every `Agent` call includes `team_name=<team_name>` AND `name=<role>`.
- [ ] `~/.claude/teams/<team_name>/config.json` exists and lists all spawned teammates in `members[]`.
- [ ] The lead itself appears in `members[]` automatically.
- [ ] No teammate has `name` colliding with another teammate's name in the same team.

If verification fails, do NOT proceed to orchestration. Shutdown and report.

---

## Glossary

| Term | Meaning |
|---|---|
| **operator** | the human |
| **team-lead** (or just **lead**) | the main Claude Code session — i.e. this session |
| **teammate** | a spawned Claude session participating as a team member |
| **DM** | direct message between teammates via SendMessage |
| **kickoff role** | the role that posts the first DM in a bidirectional pattern |
| **G1–G5** | spec patches: plan-approval criteria, task-deps, project-scope override, CLAUDE.md propagation, token tally |
