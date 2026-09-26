# <what this job measures, one line>  (one whole-application run per job: the GPU lock lives in this shell)
cd <loop> && source tools/points.sh
# example: A/B of a switch on the lane's point, alternating
for v in on off on off; do
  [ $v = off ] && E="-e <TAG>_OFF=1" || E=""
  ENVX="$E" tools/<point_script> <args> <loop>/pilot/<name>/ab_$v > /dev/null
  echo "$v $(grep -h '<timing line pattern>' <loop>/pilot/<name>/ab_$v/*.log | tail -1)"
done
