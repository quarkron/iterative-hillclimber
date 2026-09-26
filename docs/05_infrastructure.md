# Infrastructure

## Queue runner (`scripts/queue_runner.sh`)
One lane = one runner = one GPU (or GPU pair) = one queue directory:
`queue/pending/NNN_name.sh` → `running/` → `done/` (+ `.rc`, `.log`). Jobs run in name order. `touch queue/STOP` ends the
runner after the current job; `touch queue/PAUSE` holds it. Jobs are plain bash scripts that `cd` to the loop and call the
lane's tools, so any agent can queue work by writing a file, and every job leaves its log.

Rules for job scripts:
- **One whole-application run per job.** The guard's GPU lock is held on a file descriptor of the calling shell for the
  shell's lifetime; a second run in the same job waits on its own lock.
- Grep and print the few lines that matter at the end (gate verdict, timings) so `done/*.log` reads as a result.
- Never `pkill -f` a pattern your own command line contains.

## Lanes under Slurm (`scripts/lanes.sbatch`)
Book GPUs honestly: a single Slurm job books the GPUs the lanes use (and any faulty GPU you want nobody else to land on),
runs one runner per lane with disjoint core sets, and one thermal watchdog over all of them. Slurm hands out the lowest
free indices; to land on specific GPUs, hold the lower ones with a trap-free placeholder (`sbatch --wrap "sleep 600"`)
while submitting, and have the job refuse any other allocation (`WANT_GPUS=a,b`).

## GPU guard (`scripts/gpu_guard.sh`)
Before every run: a GPU is usable only if it has no compute processes, ~0 memory in use, 0 % utilisation, an idle
temperature below a limit, no clock-event reason beyond idle, is not mapped into a running container, is not excluded,
and no other loop run holds its lock. Cores must not overlap running containers' cpusets. Work started outside Slurm is
invisible to the scheduler; the guard is what keeps two runs off one card. In the lanes, wait (GUARD_WAIT_S) rather than fail.

## Thermal watchdog (`scripts/thermal_watchdog.sh`)
Samples temperature, memory temperature, power, clocks, clock-event reasons and thermal-slowdown counters every few
seconds into a CSV; on a trip (core/memory temperature, sustained power, any thermal event) it pauses the queue, kills the
loop's containers on that GPU and writes `THERMAL_TRIP`. A card with a cooling fault shows up as high idle temperature and
sustained software thermal slowdown; exclude it (EXCLUDE_GPUS) and tell the owner.

## Long runs (`templates/run_full.sbatch`-style)
Full validation runs get their own Slurm job: snapshot the exact code (git archive + untracked build products) into
`_src/<run>/` with a PROVENANCE file (commits, builds, image id, layout, seed, reference), refuse to overwrite an existing
output directory, write outputs in the same layout as production so the production analysis scripts run unchanged.
Cancelling: if the job has an EXIT trap that kills containers by name, never cancel an old job whose run name a new job
reuses (the trap kills the new container); cancel with the signal the trap cannot catch or use distinct names.

## Containers and builds
Build candidates with the same image and flags as production (a build script per repository that reproduces the
production build; verify with the null candidate). Mount candidate builds read-only into the production image
(`-v build:/bld -e PYTHONPATH=/bld`). Keep build logs next to the candidate.
