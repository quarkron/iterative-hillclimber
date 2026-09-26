# Scripts (application-independent)

| script | purpose | notes |
|---|---|---|
| `queue_runner.sh` | runs `$Q/pending/*.sh` in order into `done/` (+ .rc, .log); STOP / PAUSE files | one whole-application run per job |
| `lanes.sbatch` | several lanes under one Slurm allocation + one watchdog; refuses if a lane GPU is not booked | lanes in a `lanes.conf` |
| `gpu_guard.sh` | sourced: `gpu_usable`, `pick_gpus`, `lock_gpus`, `cores_free`, `with_wait` | set `LOCKDIR`, `GPU_NUMA_MAP`, `EXCLUDE_GPUS` |
| `thermal_watchdog.sh` | telemetry CSV + trip (pause queue, kill containers on the GPU) | `Q`, `GPUS` |
| `eval_candidate.sh` | snapshot -> build -> gate -> time -> fitness -> ledger row, via per-lane hook scripts | the loop provides `tools/lanes/<lane>/{build,gate,time,score}.sh` |
| `fitness.py` | geometric-mean speedup over points (optional weights) | JSON point -> seconds |
| `stat_gate.py` | Lane B band gate on per-replicate metrics + replicate distances | calibrate `--k` on the null candidate |
| `ensemble_check.py` | whole-run typicality vs a production ensemble with leave-one-out null | needs numpy; CSV quantity x time |
| `critical_path.py` | two-arm pipeline projection from per-bin costs and measured speedups | calibrate on a measured run |
| `trace/` | CUPTI kernel timeline (LD_PRELOAD) + summariser (per-kernel totals, idle gaps) | when nsys is unavailable |

Example `lanes.conf`:

    # queue dir                      gpu  env for the lane's runner and jobs (your application's variables)
    <loop_dir>/queue_a               <g1> ARM_A_CORES=<cpu list> ARM_B_CORES=<cpu list>
    <loop_dir>/queue_b               <g2> ARM_A_CORES=<cpu list> ARM_B_CORES=<cpu list>

Submit: `sbatch --gres=gpu:<n> --output=<loop_dir>/queue_a/lanes-%j.out --export=ALL,LANES_FILE=<loop_dir>/lanes.conf,HILLCLIMBER=$PWD scripts/lanes.sbatch`
(book extra GPUs, e.g. a faulty card, so nobody else lands on them; `WATCH_GPUS` to watch more than the lane GPUs).
Core lists: keep each lane's cores disjoint from the other lanes' and from other users' jobs; prefer the NUMA node of the lane's GPU (`nvidia-smi topo -m`).
