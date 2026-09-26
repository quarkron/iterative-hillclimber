---
name: iterative-hillclimber
description: Run an ERA-style iterative hill-climbing optimisation loop on an existing scientific code (GPU kernels, host pipelines, whole applications) without changing its results. Use when asked to make a simulation or pipeline faster while keeping outputs identical (or statistically equivalent), to set up or resume such a loop, to evaluate a speed candidate with gates and a fitness number, or to decide whether a speed idea is a numerics/physics change that needs the owner's ruling.
---

# Iterative hill-climber (ERA loop)

A disciplined loop for making an existing code faster without changing what it computes:
one fixed baseline, fixed measurement points, one candidate = one commit, gates before timing, one fitness number,
one ledger row per candidate, accept only what passes the gates and beats the head. It is greedy hill climbing guided by
profiles, with a written journal so that any agent (or person) can stop and resume it.

## When to use it
- "Make X faster but keep the results the same" on code whose outputs can be compared (bitwise or statistically).
- Resuming an existing loop: read its `STATE.md` first, then its `candidates/LEDGER.md`.
- Deciding whether an idea is a pure speed change (Lane A), a numerics change with statistically equal results (Lane B),
  or a model change the owner must rule on.

## How to run it (read in this order)
1. `docs/00_overview.md` — the loop on one page and its vocabulary.
2. `docs/01_setup.md` — bootstrapping a loop for a new application (layout, worktrees, baseline, points, null candidate).
3. `docs/02_candidates.md` — where candidates come from (profile first), how to write, commit, accept or reject them.
4. `docs/03_gates.md` — Lane A identity gates, VERIFY modes, Lane B statistical gates, whole-run ensemble validation.
5. `docs/04_measurement.md` — timing discipline: noise floor, interleaved A/B, layouts, the critical-path model.
6. `docs/05_infrastructure.md` — queue runner, GPU lanes, Slurm booking, guard, thermal watchdog.
7. `docs/06_techniques.md` — patterns that paid off and patterns that failed.
8. `docs/07_journal_and_report.md` — STATE.md, the ledger, the study page, what to tell the owner.
9. `docs/08_plateau_and_stopping.md` — recognising a plateau, stopping, and handing the owner the decisions that are theirs.
10. `docs/lessons_traps.md` — concrete traps, each of which cost a real loop time.

`templates/` has the files a new loop starts from; `scripts/` has application-independent tools (see `scripts/README.md`);
`examples/case_study.md` describes how the loop was run on a large coupled GPU simulation (method only).

## Non-negotiables
- Never change results silently. A change that is not bitwise identical is Lane B and must pass a statistical gate; a change
  that alters the model (tolerances, step caps, coupling, time steps) is the owner's decision even if it is fast.
- Measure before optimising, and measure the candidate against the head under the same conditions (same GPU, same cores,
  interleaved), never against a number from another day.
- One candidate, one commit, one ledger row. Rejected candidates stay in the ledger with their patch.
- Journal as you go (STATE.md). The next session starts from it.
- Stop at a plateau and say so, with the numbers; do not keep spending on sub-percent gains unless asked.
