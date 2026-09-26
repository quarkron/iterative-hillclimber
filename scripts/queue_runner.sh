#!/bin/bash
# Queue runner: runs <Q>/pending/*.sh one at a time in name order -> running/ -> done/ (+ .rc, .log).
#   env: Q (queue dir, required), ONLY_GPU (the lane's GPU, exported to jobs), any other lane env (core lists, ...) is inherited.
#   Stop after the current job: touch $Q/STOP.  Hold: touch $Q/PAUSE (remove to resume).
# One whole-application run per job: the GPU guard's lock is held on a descriptor of the job's shell.
set -u
: "${Q:?set Q to the queue directory}"
mkdir -p "$Q/pending" "$Q/running" "$Q/done"
export ONLY_GPU=${ONLY_GPU:-0} GUARD_WAIT_S=${GUARD_WAIT_S:-1800}
echo "[runner] job ${SLURM_JOB_ID:-none} on $(hostname) start $(date -Is); queue $Q; GPU $ONLY_GPU; cpus $(grep Cpus_allowed_list /proc/self/status | awk '{print $2}')"
while [ ! -e "$Q/STOP" ]; do
  if [ -e "$Q/PAUSE" ]; then sleep 30; continue; fi
  next=$(ls "$Q"/pending/*.sh 2>/dev/null | sort | head -1)
  if [ -z "$next" ]; then sleep 20; continue; fi
  b=$(basename "$next" .sh); mv "$next" "$Q/running/$b.sh"
  echo "[runner] $(date -Is) START $b"; t0=$(date +%s)
  bash "$Q/running/$b.sh" > "$Q/done/$b.log" 2>&1; rc=$?
  echo $rc > "$Q/done/$b.rc"; mv "$Q/running/$b.sh" "$Q/done/$b.sh"
  echo "[runner] $(date -Is) END $b rc=$rc $(( $(date +%s) - t0 ))s"
done
echo "[runner] STOP seen, exiting $(date -Is)"
