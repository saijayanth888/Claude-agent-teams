---
name: improvement
description: Pipeline that finds issues, fixes them, and validates each handoff
when_to_use: |
  Find issues in existing code AND execute the fixes.
  Examples:
    - "fix all bugs in module X"
    - "refactor Y for clarity"
    - "clean up Z"
  Not for: design proposals (use design-review), open-ended research
  (use research), or yes/no decisions (use debate).

members:
  - role: scout
    count: 1
  - role: builder
    count: 1
  - role: verifier
    count: 1

pattern: pipeline-with-handoff-validation
kickoff: scout
output_artifact: changes.md

require_plan_approval: true

limits:
  max_rounds: 10
  max_wall_minutes: 60
  max_silence_minutes: 5
---

# Improvement team

## When to use
Use this team when you've already identified that work needs to be done in a known area and want the team to scout, fix, and validate. The builder is the only role with write access; the plan-approval gate ensures the operator approves the change set before edits land.

## How members coordinate
1. Lead spawns the scout. Scout audits target, produces issue list with file:line + severity.
2. Scout DMs builder (kickoff handoff). [G2] Native task dependency: builder's task is blocked until scout's task completes.
3. [G1] Builder produces a plan doc (sections: `Files affected`, `Test impact`, `Rollback notes`) and DMs team-lead as plain text for approval. **Not** Claude Code's native plan-mode — a DM-based protocol where the lead is the approver.
4. Team-lead approves OR rejects with feedback. Builder revises until approved.
5. After team-lead replies `approved`, builder implements fixes one at a time.
6. After each fix: builder DMs verifier with `{ file, line, fix summary }`.
7. [G2] Verifier's task is blocked until builder's task completes per-fix; verifier self-claims via task dependency.
8. Verifier runs tests, smoke-checks, catches regressions. DMs builder with failures.
9. Builder iterates until verifier signs off (per fix). Both DM lead with final state.

## What the lead does
- Spawn scout first.
- [G2] Create task dependencies: builder depends on scout; verifier depends on each builder fix.
- [G1] Judge plan-approval. Criteria: plan must include `Files affected`, `Test impact`, `Rollback notes` sections.
- Spawn builder and verifier; let task-dep self-claiming drive the flow.
- Enforce circuit breakers (10 rounds, 60 min wall, 5 min idle).
- Write summary.md + changes.md + test-results.md.

## Output schema
`summary.md`:
- **Overview** — what changed, why, what's left
`changes.md`:
- **Per-fix log** — file:line, 1-line summary, rationale, verifier status
`test-results.md`:
- **Tests run** — name + pass/fail + duration
- **Regressions caught** — fixes that initially failed
- **Unverified** — fixes that couldn't be tested (with reason)

## Example invocation
"run the improvement team to fix all the regime-config bugs in trading-bot/src/regime/"
"improvement: clean up the dashboard /api/v4/* parity oracle false positives"
