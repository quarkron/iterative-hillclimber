# Traps (each one cost a real loop time)

| trap | symptom | fix |
|---|---|---|
| Second whole-application run in one queue job | "GPU N locked by another run" although nothing else runs; waits GUARD_WAIT_S | one run per job (the lock fd lives in the job's shell) |
| Cancelling an old job whose run name a new job reuses | the new run's container is killed shortly after starting (the old job's EXIT trap kills containers by name) | distinct names, or cancel with a signal the trap cannot catch; move the aborted attempt aside, never delete |
| Slurm gives the lowest free GPU indices | the job lands on a GPU busy with work started outside Slurm, or on the wrong pair | refuse other allocations (WANT_GPUS); hold lower indices with a trap-free placeholder while submitting |
| Work started outside Slurm | guard reports GPUs in use that Slurm thinks are free | the guard is the protection; wait, do not share |
| A GPU with a cooling fault | a much slower stage, high idle temperature, sustained thermal slowdown | exclude it; watchdog; tell the owner |
| Co-scheduled CPU jobs pinned to your cores | host stages markedly slower, transient spikes | check `ps`/load; pin to free cores; note affected bins |
| Single-GPU test point for device work on one arm of a two-GPU app | no gain measured | measure in the production layout |
| Benchmark ratio carries fixed setup | ratio jumps when a change only shortens one-time setup | override with the reason; measure whole-run per-step cost |
| VERIFY prints nothing | the new path never ran (fell back, env not passed, wrong function) | print a count of fast-path calls; check the env reaches the process (`docker run ${ENVX}`) |
| Interposed symbol not called | the library calls a different variant (e.g. a buffered formatter, not the line writer) | read the library's call path; check with `LD_DEBUG=bindings` |
| Hashing structs | input hashes differ run to run | hash fields, never padded structs |
| Non-deterministic reductions downstream | outputs differ between identical runs | compare inputs of the non-deterministic stage (hashes) + Lane B statistics |
| Tolerance / step-cap changes | fast, "converged", but the statistical gate fails | it is a model change: the owner decides |
| Guard waits forever at the start of a job | a previous container of yours is still exiting | the guard retries; check `docker ps` |
| First run of a new state is slow | page cache cold | alternate and repeat |
| Monolith files | changes are hard to review and revert | new work in new files, hook lines in old ones |
