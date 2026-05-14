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
  max_silence_minutes: 3
---

# Debate team

## When to use
Use this team when you have a specific YES/NO decision and want adversarial pressure to surface weaknesses. The defender argues the position is correct; the skeptic attacks it. Both deliver final verdicts to the lead, who synthesizes a recommendation.

## How members coordinate
1. Lead spawns defender + skeptic simultaneously.
2. Skeptic (kickoff) opens with strongest attack via DM to defender.
3. Defender rebuts or concedes; cycle continues.
4. After max_rounds OR both teammates DM the lead with final verdicts, the lead synthesizes.

## What the lead does
- Count DM rounds (each defender↔skeptic exchange = 1 round).
- Enforce all three limits (rounds, wall time, idle).
- On limit breach: SendMessage shutdown_request to both, then TeamDelete.
- Read both final verdicts, write synthesis to summary.md.

## Output schema
`summary.md` sections:
- **Verdict** — ship / gate-on-X / refactor-first
- **Confirmed gaps** — what the skeptic found and defender conceded
- **Rebutted attacks** — what the defender successfully defended
- **Recommended next action** — operator-facing call to action

## Example invocation
"run the debate team on whether commit abc123 is safe to push to main"
"run debate: is the new auth middleware ready to ship today"
