#!/bin/bash
# Thermal / power watchdog for the loop's GPUs. Samples every SAMPLE_S s into $Q/telemetry_gpu<N>.csv; on a TRIP it touches
# $Q/PAUSE (the runner takes no new job), kills the containers mapped to that GPU and appends the reason to $Q/THERMAL_TRIP.
# TRIP when, on a watched GPU: temperature >= MAX_C, memory temperature >= MAX_MEM_C, a clock-event reason for thermal /
# hardware slowdown / power brake, growth of the thermal-slowdown counters, or power >= MAX_W for POWER_SAMPLES samples.
# Stop: touch $Q/STOP_WATCHDOG.  DRYRUN=1: evaluate and print, never act.  ONCE=1: one sample.
set -u
Q=${Q:?set Q}; GPUS=${GPUS:?set GPUS, e.g. "0 1"}; SAMPLE_S=${SAMPLE_S:-5}
MAX_C=${MAX_C:-70}; MAX_MEM_C=${MAX_MEM_C:-75}; WARN_C=${WARN_C:-60}; MAX_W=${MAX_W:-700}; POWER_SAMPLES=${POWER_SAMPLES:-6}
declare -A last_sw last_hw hot_w
trip() {
  local g=$1 why=$2
  echo "[watchdog] $(date -Is) TRIP GPU $g: $why"
  [ "${DRYRUN:-0}" = 1 ] && return
  echo "$(date -Is) GPU $g: $why" >> "$Q/THERMAL_TRIP"; touch "$Q/PAUSE"
  for c in $(docker ps -q 2>/dev/null); do
    if docker inspect $c --format '{{range .HostConfig.DeviceRequests}}{{range .DeviceIDs}}{{.}} {{end}}{{end}}' 2>/dev/null | tr ' ,' '\n\n' | grep -qx "$g"; then
      echo "[watchdog]   killing container $(docker inspect $c --format '{{.Name}}') on GPU $g"; docker kill $c > /dev/null
    fi
  done
}
echo "[watchdog] start $(date -Is) job ${SLURM_JOB_ID:-none}: GPUs $GPUS every ${SAMPLE_S}s; trip at ${MAX_C} C / mem ${MAX_MEM_C} C / ${MAX_W} W x${POWER_SAMPLES} / any thermal event"
while [ ! -e "$Q/STOP_WATCHDOG" ]; do
  for g in $GPUS; do
    line=$(timeout 30 nvidia-smi -i $g --query-gpu=timestamp,temperature.gpu,temperature.memory,power.draw,clocks.sm,utilization.gpu,clocks_event_reasons.active,clocks_event_reasons_counters.sw_thermal_slowdown,clocks_event_reasons_counters.hw_thermal_slowdown --format=csv,noheader,nounits 2>&1)
    f=$Q/telemetry_gpu$g.csv; [ -f $f ] || echo "timestamp,temp_c,mem_c,power_w,sm_mhz,util_pct,reasons,sw_thermal_us,hw_thermal_us" > $f
    echo "$line" | tr -d ' ' >> $f
    IFS=',' read -r ts t tm p clk u rs sw hw <<< "$(echo "$line" | tr -d ' ')"
    if ! [[ "$t" =~ ^[0-9]+$ ]]; then echo "[watchdog] $(date -Is) GPU $g: nvidia-smi read failed: $line"; continue; fi
    [ "$t" -ge "$WARN_C" ] && echo "[watchdog] $(date -Is) WARN GPU $g at $t C (mem $tm C, $p W)"
    [ "$t" -ge "$MAX_C" ] && trip $g "core $t C >= $MAX_C C"
    [[ "$tm" =~ ^[0-9]+$ ]] && [ "$tm" -ge "$MAX_MEM_C" ] && trip $g "memory $tm C >= $MAX_MEM_C C"
    r=$((rs)); (( r & (0x08 | 0x20 | 0x40 | 0x80) )) && trip $g "clock event reasons $rs (thermal / hw slowdown / power brake)"
    if [ -n "${last_sw[$g]:-}" ] && [[ "$sw" =~ ^[0-9]+$ ]] && { [ "$sw" -gt "${last_sw[$g]}" ] || [ "$hw" -gt "${last_hw[$g]}" ]; }; then
      trip $g "thermal slowdown counters grew (sw ${last_sw[$g]} -> $sw us, hw ${last_hw[$g]} -> $hw us)"; fi
    last_sw[$g]=$sw; last_hw[$g]=$hw
    if awk -v p="$p" -v m="$MAX_W" 'BEGIN{exit !(p+0 >= m)}'; then hot_w[$g]=$(( ${hot_w[$g]:-0} + 1 )); else hot_w[$g]=0; fi
    [ "${hot_w[$g]}" -ge "$POWER_SAMPLES" ] && trip $g "power $p W >= $MAX_W W for $POWER_SAMPLES samples"
  done
  [ "${ONCE:-0}" = 1 ] && break
  sleep $SAMPLE_S
done
echo "[watchdog] stop $(date -Is)"
