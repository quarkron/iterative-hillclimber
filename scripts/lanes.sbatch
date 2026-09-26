#!/bin/bash
#SBATCH --job-name=era-lanes
#SBATCH --time=4-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=56
#SBATCH --gres=gpu:2
# Several loop lanes under ONE Slurm allocation: one queue runner per lane, one thermal watchdog over all lane GPUs.
#   sbatch --gres=gpu:<n> --output=<loop>/queue/lanes-%j.out --export=ALL,LANES_FILE=<loop>/lanes.conf,HILLCLIMBER=<repo> lanes.sbatch
# LANES_FILE: one lane per line:  <queue_dir> <gpu> [VAR=value ...]   (VARs are exported to that lane's runner and jobs, e.g.
#   ARM_A_CORES=<cpu list> ARM_B_CORES=<cpu list>). Lines starting with # are ignored.
# The job refuses to start unless Slurm booked every lane GPU (book extra GPUs, e.g. a faulty one, so nobody lands on them).
# Stop: touch <queue>/STOP in every lane queue (each finishes its current job); the watchdog stops with <first queue>/STOP_WATCHDOG.
set -u
: "${LANES_FILE:?}" "${HILLCLIMBER:?path of this repository}"
echo "[lanes] job ${SLURM_JOB_ID:-none} $(date -Is) slurm GPUs ${SLURM_JOB_GPUS:-?}"
mapfile -t LANES < <(grep -vE '^\s*(#|$)' "$LANES_FILE")
GPUS=""; FIRSTQ=""
for l in "${LANES[@]}"; do
  read -r q g rest <<< "$l"
  case ",${SLURM_JOB_GPUS:-}," in *,$g,*) ;; *) echo "[lanes] ABORT: lane GPU $g not booked (got ${SLURM_JOB_GPUS:-none})"; exit 3;; esac
  GPUS="$GPUS $g"; [ -z "$FIRSTQ" ] && FIRSTQ=$q
  mkdir -p "$q"; rm -f "$q/STOP"
done
rm -f "$FIRSTQ/STOP_WATCHDOG"
for l in "${LANES[@]}"; do
  read -r q g rest <<< "$l"
  ( export Q="$q" ONLY_GPU="$g"; for kv in $rest; do export "$kv"; done; exec bash "$HILLCLIMBER/scripts/queue_runner.sh" ) > "$q/runner.out" 2>&1 &
done
( export Q="$FIRSTQ" GPUS="${WATCH_GPUS:-$GPUS}"; exec bash "$HILLCLIMBER/scripts/thermal_watchdog.sh" ) > "$FIRSTQ/watchdog.out" 2>&1 &
# a trip PAUSEs the first queue: mirror it to every lane
while sleep 30; do
  if [ -e "$FIRSTQ/PAUSE" ]; then for l in "${LANES[@]}"; do read -r q _ <<< "$l"; touch "$q/PAUSE"; done; fi
  jobs -r | grep -q queue_runner || break
done
touch "$FIRSTQ/STOP_WATCHDOG"; wait
