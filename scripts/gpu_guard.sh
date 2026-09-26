#!/bin/bash
# GPU / core guard, sourced by the loop's run scripts before every point.
# A GPU is USABLE only if, over SAMPLES reads SAMPLE_S apart: no compute process, memory.used <= MAX_MEM_MIB, utilisation 0 %,
# temperature <= MAX_IDLE_C, no active clock-event reason other than idle (0x1), not mapped into a running docker container,
# not in EXCLUDE_GPUS, and no other loop run holds its lock (LOCKDIR/gpu<N>.lock, flock). Cores are USABLE only if they overlap
# no running container's --cpuset-cpus.
#   gpu_usable G        -> 0/1, reason on stderr
#   pick_gpus N [numa]  -> N usable GPU indices (same NUMA node first) or return 1
#   lock_gpus G...      -> exclusive locks for the rest of the CALLING SHELL (fd 200+); return 1 if any is held
#   cores_free LIST     -> 0/1, reason on stderr
#   with_wait CMD...    -> retry CMD every 60 s for up to GUARD_WAIT_S
# Config (env): EXCLUDE_GPUS, MAX_MEM_MIB, MAX_IDLE_C, SAMPLES, SAMPLE_S, LOCKDIR, GPU_NUMA_MAP ("0 0 0 0 1 1 1 1" = NUMA of GPU i)
EXCLUDE_GPUS=${EXCLUDE_GPUS:-}; MAX_MEM_MIB=${MAX_MEM_MIB:-100}; MAX_IDLE_C=${MAX_IDLE_C:-50}; SAMPLES=${SAMPLES:-3}; SAMPLE_S=${SAMPLE_S:-1}
LOCKDIR=${LOCKDIR:?set LOCKDIR}; mkdir -p "$LOCKDIR"
GPU_NUMA_MAP=${GPU_NUMA_MAP:-$(nvidia-smi --query-gpu=index --format=csv,noheader | sed 's/.*/0/' | tr '\n' ' ')}
NGPU=$(echo $GPU_NUMA_MAP | wc -w)
gpu_numa() { echo $GPU_NUMA_MAP | cut -d' ' -f$(( $1 + 1 )); }
_docker_gpus() {
  local ids; ids=$(docker ps -q 2>/dev/null); [ -z "$ids" ] && return
  docker inspect $ids --format '{{range .HostConfig.DeviceRequests}}{{range .DeviceIDs}}{{.}} {{end}}{{end}}' 2>/dev/null | tr ' ,' '\n\n' | grep -E '^[0-9]+$' | sort -u
}
gpu_usable() {
  local g=$1 i uuid util mem temp reasons
  for x in $EXCLUDE_GPUS; do [ "$x" = "$g" ] && { echo "GPU $g: excluded (EXCLUDE_GPUS)" >&2; return 1; }; done
  _docker_gpus | grep -qx "$g" && { echo "GPU $g: mapped into a running container" >&2; return 1; }
  uuid=$(nvidia-smi -i "$g" --query-gpu=uuid --format=csv,noheader)
  nvidia-smi --query-compute-apps=gpu_uuid --format=csv,noheader | grep -q "$uuid" && { echo "GPU $g: has compute processes" >&2; return 1; }
  for i in $(seq 1 "$SAMPLES"); do
    IFS=', ' read -r util mem temp reasons <<< "$(nvidia-smi -i "$g" --query-gpu=utilization.gpu,memory.used,temperature.gpu,clocks_event_reasons.active --format=csv,noheader,nounits)"
    [ "$util" -eq 0 ] || { echo "GPU $g: utilization $util %" >&2; return 1; }
    [ "$mem" -le "$MAX_MEM_MIB" ] || { echo "GPU $g: $mem MiB in use" >&2; return 1; }
    [ "$temp" -le "$MAX_IDLE_C" ] || { echo "GPU $g: $temp C at idle (> $MAX_IDLE_C)" >&2; return 1; }
    case "$reasons" in 0x0000000000000000|0x0000000000000001) ;; *) echo "GPU $g: clock event reasons $reasons" >&2; return 1;; esac
    [ "$i" -lt "$SAMPLES" ] && sleep "$SAMPLE_S"
  done
  ( exec 9>"$LOCKDIR/gpu$g.lock"; flock -n 9 ) || { echo "GPU $g: locked by another loop run" >&2; return 1; }
  return 0
}
pick_gpus() {
  local n=$1 want=${2:-} picked=() node g
  for node in ${want:-$(echo $GPU_NUMA_MAP | tr ' ' '\n' | sort -u)}; do
    picked=()
    for g in $(seq 0 $((NGPU-1))); do [ "$(gpu_numa $g)" = "$node" ] && gpu_usable "$g" 2>/dev/null && picked+=("$g"); [ ${#picked[@]} -ge "$n" ] && break; done
    [ ${#picked[@]} -ge "$n" ] && { echo "${picked[@]:0:$n}"; return 0; }
  done
  return 1
}
_lockfd=200
lock_gpus() {
  local g
  for g in "$@"; do
    eval "exec $_lockfd>\"$LOCKDIR/gpu$g.lock\""
    flock -n $_lockfd || { echo "GPU $g: lock held by another loop run" >&2; return 1; }
    echo "$$ $(date -Is)" > "$LOCKDIR/gpu$g.owner"; _lockfd=$((_lockfd+1))
  done
}
_expand() { echo "$1" | tr ',' '\n' | awk -F- 'NF==2{for(i=$1;i<=$2;i++)print i; next}{print $1}'; }
cores_free() {
  local want busy ids clash
  ids=$(docker ps -q 2>/dev/null); [ -z "$ids" ] && return 0
  busy=$(for c in $(docker inspect $ids --format '{{.HostConfig.CpusetCpus}}' 2>/dev/null); do _expand "$c"; done | sort -u)
  want=$(_expand "$1" | sort -u)
  clash=$(comm -12 <(echo "$want") <(echo "$busy") | tr '\n' ' ')
  [ -z "$clash" ] || { echo "cores $1 overlap running containers on: $clash" >&2; return 1; }
}
with_wait() {
  local t0=$(date +%s) last="" tf
  while true; do
    tf=$(mktemp); "$@" 2>"$tf" && { cat "$tf" >&2; rm -f "$tf"; return 0; }; last=$(cat "$tf"); rm -f "$tf"
    [ $(( $(date +%s) - t0 )) -ge "${GUARD_WAIT_S:-0}" ] && { echo "$last" >&2; echo "[guard] gave up after ${GUARD_WAIT_S:-0}s" >&2; return 1; }
    echo "[guard] $(date +%T) waiting: $(echo "$last" | tail -1)" >&2; sleep 60
  done
}
