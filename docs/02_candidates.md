# Candidates

## Where they come from
Always from a measurement of the current head, never from a guess about the code:
- **Kernel timelines** (CUPTI trace, `scripts/trace/`): per-kernel totals, counts, means, and the *idle gaps* between kernels
  (host work the GPU waits for). Idle gaps are often the cheapest wins.
- **Kernel metrics** (ncu): stall reasons, registers, occupancy, memory throughput. Tells latency-bound from bandwidth-bound.
- **Host profiles**: per-command / per-function timers behind an env switch, line profilers on captured inputs, cProfile.
- **Diagnostic traces of algorithms**: e.g. an energy-vs-iteration trace of an iterative solver showed where its iterations
  went (it was a step-size cap, not a converged tail).
- **The critical-path model**: which arm paces each phase of the run; speeding up the other arm buys nothing.

Rank candidates by expected saving on the critical path, not by local speedup.

## Classify before writing code
| class | examples | gate |
|---|---|---|
| **Lane A (identical)** | skip redundant work; cache; exact faster reimplementation; fewer transfers; better launch shape; lazy evaluation | bitwise identity + VERIFY |
| **Lane B-light** | same operations in another order (reduction/summation order, neighbour order, atomics) | statistical gate |
| **Lane B** | lower precision, different numerics with the same model | statistical gate + whole-run ensemble validation |
| **Model change** | tolerances, step caps, time steps, coupling intervals, algorithms that follow a different path | **the owner decides**; you may measure it and present the trade-off |

A change can look like numerics and be a model change: a larger line-search step cap in a minimiser kept energy and
tolerances identical but moved every configuration further per call and failed the statistical gate at every value tried.

## Writing a candidate
- Put it behind switches: `<TAG>_OFF=1` restores the old path; `<TAG>_VERIFY=1` runs both paths (or re-computes the
  reference) and prints `IDENTICAL/DIFFERENT` with counts. Keep VERIFY in the committed code: it is the gate's evidence
  and the next change's safety net.
- For an exact reimplementation, handle only the plain case and hand everything else to the original function
  (fallback on anything unusual: comments, labels, overflow, odd formats). Unusual inputs keep the original's behaviour
  and errors.
- New work goes into new files (keep monoliths untouched except for hook lines); keep files small.
- Comments explain the physics/semantics and the measured reason, not the location.

## Commit, evaluate, decide
- Commit on the dev branch: `<LOOP> NNN (<lane class>): <what>` + body with the measurement that motivated it and the
  verification result (see `templates/candidate_commit.txt`). No co-author trailers unless the owner wants them.
- Evaluate with the lane's evaluator (`scripts/eval_candidate.sh` skeleton) → ledger row.
- **Accept**: gates pass and fitness beats the head → fast-forward the head branch to the commit; for multi-repository
  candidates, fast-forward each repository and record both revisions.
- **Reject**: keep the patch (`git format-patch` into `candidates/<lane>/<name>/`), write the row with the reason
  (slower by x %, gate failure with the statistic), reset the dev branch to the head.
- A rejected idea may be re-tried later on a different head; say so in its note.
