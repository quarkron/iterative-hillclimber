# The loop on one page

```
            ┌──────────────── profile the head at the points ────────────────┐
            │                                                                ▼
  baseline ─┴─► head ──► candidate (1 commit) ──► build ──► GATES ──► TIME ──► FITNESS ──► ledger row ──► page
                 ▲                                            │ fail           │ not better
                 │                                            ▼                ▼
                 └──────── accept: head := candidate      reject (patch kept, row written)
```

## Vocabulary
| term | meaning |
|---|---|
| **baseline** | The code and its measured cost before the loop started. Never changes. Every fitness is relative to it. |
| **head** | The last accepted candidate, per repository (an accepted branch). |
| **lane** | One independently optimisable part of the application (a kernel family, a host stage, one repository). Lanes have their own points and gates. |
| **point** | A fixed, reproducible workload the lane is timed on: a replay of a captured state, a short whole-application run, a microbenchmark. Points never change once the loop starts (add new ones instead). |
| **candidate** | One uncommitted diff or one commit on the lane's dev branch, named `NNN_slug`. |
| **gate** | A pass/fail check run *before* timing: identity (Lane A) or statistical equivalence (Lane B). |
| **Lane A** | Results must be bitwise identical to the head (lattices, counts, files, hashes). |
| **Lane B** | Results cannot be bitwise identical (floating-point order, non-deterministic reductions); they must be statistically indistinguishable from the head's run-to-run spread. |
| **fitness** | Speedup of the candidate at the lane's point(s) against the baseline (geometric mean over cells/points). |
| **critical path** | For pipelines with parallel arms (e.g. two GPUs that meet every interval), the model that turns per-arm speedups into the whole run's time. |
| **ledger** | `candidates/LEDGER.md`, one row per candidate evaluation: gates, fitness, note. |
| **STATE.md** | The journal: what exists, what was accepted, what is running, traps found. Read first, written continuously. |
| **plateau** | The point where every remaining idea is worth ~1-2 % and costs more than it returns. |

## One iteration
1. **Find the biggest cost** at the head: a trace (kernel timeline), a profile (per-function, per-command timers), or the
   critical-path model telling you which arm paces the run.
2. **Form one candidate** that removes part of that cost. Decide its lane up front: identical (A) or statistically equal (B).
   If it changes the model, stop and ask the owner.
3. **Implement it behind a switch**: `<TAG>_OFF=1` restores the old path; a `<TAG>_VERIFY=1` mode computes both and
   compares, printing IDENTICAL/DIFFERENT with counts. The switch makes the A/B and the gate trivial.
4. **Gate**: VERIFY at the points (and at every call the point exercises), then the lane's formal gate.
5. **Time**: interleaved A/B on the same resources (on, off, on, off), or the lane's timing point.
6. **Record**: a ledger row whatever the outcome; STATE.md entry; rebuild the page.
7. **Accept** (fast-forward the lane branch to the commit) only if gates pass *and* it is faster; otherwise reject and keep the patch.
8. Every few acceptances, **re-measure the phases / whole run** and re-project; the bottleneck moves.

## Why greedy
Evaluations are expensive (minutes to hours) and noisy (node load moves timings by several percent); most accepted
changes compose additively; and profiles point at the largest remaining cost. A wider search (beam over parameters,
combinations of rejected candidates) is worth it only for interacting knobs; see `08_plateau_and_stopping.md`.
