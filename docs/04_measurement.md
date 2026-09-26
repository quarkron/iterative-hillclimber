# Measurement

## Rules
- **Same resources**: the candidate and its comparison run on the same GPU, the same cores, the same layout. Different GPUs
  of the same model differ (a thermally throttling card can cost several-fold); different NUMA placement differs.
- **Interleave**: on, off, on, off (>= 2 each) inside one job; compare medians. Sequential runs hours apart measure the node.
- **Log the node**: every point writes `nodeload_{start,end}.txt` (GPU utilisation/memory, containers, load average). When
  a timing looks odd, check this first: co-scheduled CPU jobs pinned to your cores can inflate host-side stages substantially.
- **Know the noise floor**: the null candidate; replicate CV; accept nothing inside it unless it is Lane A and obviously
  removes work (then it is free to keep).
- **Steady state**: for long-lived processes (servers, caches), drop the first request; report the median of 2..N.
- **Cold caches**: the first run on a new file/state can be slow (page cache); alternate and repeat before believing it.

## Layout matters
A test point must reproduce the production layout for the part being optimised. In a two-GPU application, a single-GPU
test point runs both arms on one card: device-side work added to one arm then queues behind the other arm's kernels and
looks like no gain, while the same change is a clear gain in the real two-GPU layout. Keep both kinds of
points and label which one each ledger row used.

## Benchmark ratio vs whole-run ratio
Microbenchmarks carry fixed harness cost (initialisation, first-call setup) in both runs, so their ratio understates
per-step gains; a change that shortens one-time setup inflates a benchmark ratio without changing the run. Measure the
whole-run per-step cost too and record both; override a known artefact explicitly (a `gap_override.json` with the reason).

## Critical-path model
For an application whose arms run in parallel and meet every interval, each interval costs the slower arm:
`t = max(arm_A(t), arm_B(t)) + serial_part(t)`. Build a per-phase model from a production run's per-bin timers:
- arm A per unit time = sum of its components / their measured speedups at the points;
- arm B per unit time = its measured cost per call at phase points (interpolated), / its speedup;
- wait = max(0, arm_B - arm_A).
`scripts/critical_path.py` implements the model from a JSON of bins. Use it to rank candidates (speeding up the arm that
does not pace the phase buys nothing) and to know when the other arm becomes the bottleneck. Calibrate it against a
measured full run; models built from bin averages under-predict because per-interval variation (max of two noisy arms)
adds wait; measure the offset once on a full run and quote it with every projection.

## Profilers that worked
- CUPTI activity trace preloaded into the process (`scripts/trace/`): GPU timestamps per kernel, gaps between kernels.
  (nsys can hang or silently miss kernels on architectures newer than its bundled CUPTI; ncu is still fine for per-kernel metrics.)
- ncu SASS sampling for stall reasons on the hottest kernel.
- Per-command timers in the driver loop (`<APP>_CMD_TIMES=1`), per-sub-step timers in long commands.
- line_profiler / cProfile on captured inputs replayed outside the application.
