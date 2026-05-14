---
name: brainstorm
description: Generative ideation with divergent thinking before critic-driven convergence
when_to_use: |
  Generative ideation where divergent thinking precedes convergence.
  Examples:
    - "what are the design alternatives for X"
    - "feature ideation for Y"
    - "refactor approaches for Z"
  Not for: yes/no decisions (use debate), structured investigation
  (use research), or implementation tasks (use improvement).

members:
  - role: diverger
    count: 3
  - role: critic
    count: 1
  - role: synthesizer
    count: 1

pattern: diverge-critique-converge
kickoff: null
output_artifact: ideas.md

require_plan_approval: false

limits:
  max_rounds: 2
  max_wall_minutes: 20
  max_silence_minutes: 4
---

# Brainstorm team

## When to use
Use this team for generative ideation where you want quantity-and-variety before convergence. Three divergers produce raw ideas independently (no anchoring); the critic kills weak ones with reasons; the synthesizer organizes survivors.

## How members coordinate
1. Lead spawns 3 divergers in parallel with the same prompt.
2. Each diverger emits 5-10 ideas without self-filter. No inter-talk.
3. Lead spawns the critic with all 3 idea sets concatenated.
4. Critic kills bad ideas with specific reasons. DMs each diverger with rejections.
5. Each diverger may push back ONCE per rejected idea (3-5 lines).
6. Survivors + rejection reasons → lead spawns the synthesizer.
7. Synthesizer organizes survivors into coherent direction + rejected-and-why appendix.

## What the lead does
- Spawn 3 divergers in parallel.
- Wait for all 3 idea sets before spawning critic.
- Spawn critic with concatenated idea sets.
- Manage 1-round push-back cycle between critic and divergers.
- Spawn synthesizer with survivors.
- Write final summary.md.

## Output schema
`summary.md` sections:
- **Direction** — synthesizer's organized survivors, ranked
- **Top 3 picks** — synthesizer's recommendation
`rejected.md`:
- **Killed** — each rejected idea with critic's reason

## Example invocation
"run the brainstorm team on design alternatives for the new dashboard sidebar"
"brainstorm: refactor approaches for the regime config module"
