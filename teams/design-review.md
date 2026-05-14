---
name: design-review
description: Architectural decision with built-in critique loop
when_to_use: |
  Architectural or UX decision with built-in critique.
  Examples:
    - "design the X system"
    - "approach A vs B for Y"
    - "redesign the Z page"
  Not for: yes/no on existing artifact (use debate), ideation without
  structure (use brainstorm), or implementation tasks (use improvement).

members:
  - role: scout
    count: 1
  - role: designer
    count: 1
  - role: critic
    count: 1

pattern: sequential-with-critique-loop
kickoff: scout
output_artifact: design.md

require_plan_approval: true

limits:
  max_rounds: 2
  max_wall_minutes: 25
  max_silence_minutes: 5
---

# Design-review team

## When to use
Use this team when you need a concrete design proposal with adversarial review built in. The scout maps current state; the designer proposes; the critic loops back to push the designer to revise. Lead is the decider.

## How members coordinate
1. Lead spawns the scout. Scout maps existing system state + constraints.
2. Scout DMs designer (kickoff handoff) with the map. CCs team-lead.
3. Designer proposes a design based on scout's findings.
4. [G1] If require_plan_approval=true, designer DMs the initial proposal to team-lead first (NOT the critic) and waits for team-lead's plain-text reply (`approved` or `revise: <feedback>`). This is a DM-based protocol — designer does NOT invoke Claude Code's native plan mode.
5. Designer DMs critic with the proposal.
6. Critic challenges design from blind-spot angles, DMs designer with concerns.
7. Designer revises (1-2 iterations max).
8. Lead receives final design + critic's residual concerns.

## What the lead does
- Spawn scout first; wait for map.
- Spawn designer once scout DMs handoff.
- [G1] Judge plan-approval requests. Criteria: design must include `Files affected`, `Tradeoffs`, `Open questions` sections.
- Spawn critic once designer's initial proposal is shared.
- Enforce critic-loop cap (2 rounds).
- Write final summary.md.

## Output schema
`summary.md` sections:
- **Goal** — restated from operator
- **Design** — the final approach
- **Files affected** — concrete list
- **Tradeoffs considered** — what was rejected
- **Open questions** — operator-decision items
`residual-concerns.md`:
- **Critic's unresolved objections** — concerns that survived 2 critic-loop rounds

## Example invocation
"run the design-review team on a new shadow-mode toggle for /api/v4/*"
"design-review: redesign the morning-state audit cron to handle 12 crypto + 15 stocks"
