# Setting up a loop for a new application

## 1. Loop directory (outside the application's source tree)
Keep every artefact of the loop in one directory that is not part of the application repository, e.g. `<loop_dir>/`:

```
<loop>/
  STATE.md                 journal, read first by every session (templates/STATE.md)
  notes/HARNESS.md         how to run points, gates and evaluations for THIS application (templates/HARNESS.md)
  notes/PROFILE_<date>.md  the measured profile the loop opened with
  baseline/                baseline profile + reference outputs of every point (never overwritten)
  baseline/points/         per-point references (timings, hashes, statistics), phase files, overrides
  suite/                   captured inputs for replay points (states, frames, directive files)
  candidates/LEDGER.md     one row per evaluation (templates/LEDGER.md)
  candidates/<lane>/<NNN_slug>/   patch.diff, rev.txt, build log, gate output, fitness.json, point outputs
  builds/                  named builds (reference, probes)
  pilot/                   diagnostics and probes that are not candidates (keep them: they are evidence)
  queue/ pending|running|done   jobs for the queue runner (scripts/queue_runner.sh)
  locks/                   GPU locks used by the guard
  tools/                   application-specific scripts (points, gates, drivers); generic ones come from this repo
  report/                  page generator + page
```

## 2. Worktrees and branches
For each repository the loop touches, create a git worktree outside the user's checkout and two branches:
- `era-<app>` (the accepted head; only fast-forwarded to accepted candidate commits),
- `era-<app>-dev` (where candidates are committed; reset to the head after a rejection).
Tag the starting commit (`pre-era-<app>-<date>`) so the chain of accepted candidates is `git log pre-era..era-<app>`.
Never run the loop from the user's working checkout.

## 3. Build parity
Build the unmodified baseline with the loop's build script and check it reproduces the production binary's outputs and
timing (the *null candidate*, next step). A loop whose reference build differs from production measures the wrong thing.

## 4. Points
Pick 2-4 points per lane, cheapest first:
- **Replay points**: a captured input state run through one stage (one hook, one solver call, one kernel batch). Seconds.
  Capture the state from a production run (inputs *and* outputs, so the replay can be compared with production).
- **Short whole-application runs**: e.g. the first 60 units of simulated time. Minutes. They catch interactions and the
  overhead the replays miss.
- **Microbenchmarks**: a kernel on a captured frame for N steps. They isolate per-step cost but carry fixed harness cost; do
  not treat a benchmark ratio as the whole-run ratio (measure both; see 04_measurement.md).
- **Phase points**: the same replay at several phases of a long run (early / middle / late), because costs shift over a run.

For each point store in `baseline/points/`: reference timing (median of >= 3 reps, with CV), reference outputs/hashes,
and for Lane B the base-vs-base spread of every statistic the gate will use.

## 5. Null candidate
Evaluate an empty diff through the whole pipeline (`000_null`). Its fitness is the noise floor (should be 1.00 ± a few
tenths of a percent) and it proves the harness end to end. Re-run it whenever the harness or node changes.

## 6. Baseline profile
Profile the baseline at the points and, if available, cut the whole-run profile from production logs (per-stage timers
over many completed runs). Write `notes/PROFILE_<date>.md`: where the time goes, which stage paces the run, how much the
same code varies between runs and why (node load, shared cores, a throttling GPU). The loop's first candidates come from it.

## 7. Journal from minute one
Create STATE.md from the template before the first candidate. Every accept/reject, every trap, every harness change gets
a dated entry. Update the memory/notes the user keeps (if any) with a pointer to the loop.
