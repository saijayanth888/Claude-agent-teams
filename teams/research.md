---
name: research
description: Parallel investigation across multiple angles with synthesizer cross-check
when_to_use: |
  Open-ended question where multiple independent angles exist.
  Examples:
    - "investigate what could be causing X"
    - "audit Y for security issues"
    - "what are the alternatives for Z"
  Not for: yes/no decisions (use debate), ideation (use brainstorm),
  implementation tasks (use improvement).

members:
  - role: researcher
    count: "3-5"
  - role: synthesizer
    count: 1

pattern: parallel-then-sync
kickoff: null
output_artifact: synthesis.md

require_plan_approval: false

limits:
  max_rounds: 3
  max_wall_minutes: 30
  max_silence_minutes: 5
---

# Research team

## When to use
Use this team for open-ended investigation where the answer benefits from multiple independent angles being explored in parallel. Each researcher works alone first (no anchoring on each other's findings), then the synthesizer integrates.

## How members coordinate
1. Lead spawns 3-5 researchers in parallel, each with a distinct angle.
2. Researchers work alone — no inter-talk during scout phase.
3. Each researcher DMs team-lead with their report when done.
4. Lead spawns the synthesizer with all researcher reports concatenated.
5. Synthesizer reads everything, DMs individual researchers with cross-check questions.
6. Researchers respond 1-2 rounds.
7. Synthesizer produces final synthesis and DMs team-lead.

## What the lead does
- AskUserQuestion at spawn time to pick researcher count (within 3-5 range) based on complexity.
- Spawn researchers in parallel with distinct angle prompts.
- Wait for all researcher reports before spawning synthesizer.
- Enforce circuit breakers (max_wall_minutes=30 hard cap).
- Synthesize the final synthesizer output into `summary.md`.

## Output schema
`summary.md` sections:
- **Synthesis** — the unified answer
- **Tensions resolved** — where researchers disagreed and how reconciled
- **Open questions** — remaining gaps despite cross-checks
- **Per-researcher summary** — 1-2 lines per researcher for traceability

## Example invocation
"run the research team on what could be causing the v4 parity oracle false positives"
"run a 5-person research team on options for replacing the freqtrade dependency"
