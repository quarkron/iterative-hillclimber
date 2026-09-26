#!/bin/bash
# Evaluate one candidate: snapshot -> build -> gate -> time -> fitness -> one ledger row -> page. Application-independent
# skeleton: the lane-specific steps are hook scripts in $LOOP_DIR/tools/lanes/<lane>/{build,gate,time,score}.sh, each called
# with the candidate directory as $1 and writing its evidence there. Exit codes: 0 ok, 2 build failure, 3 gate failure.
#   usage: REV=<commit> eval_candidate.sh <lane> <NNN_slug> "<note>"
#   env:   LOOP_DIR (required), REPO_<lane> (the lane's git worktree), REV (commit; default: the uncommitted diff of REPO_<lane>)
# Hook contract:
#   build.sh C  -> builds the snapshot in C/src into C/build; prints BUILD_OK
#   gate.sh  C  -> runs the lane's gate(s); writes C/gate.txt whose first line starts with "GATE PASS" or "GATE FAIL: <why>"
#   time.sh  C  -> runs the timing point(s); writes C/timing.json  {"point": seconds, ...}
#   score.sh C  -> writes C/fitness.json {"fitness": x, "per_point": {...}} (scripts/fitness.py does the usual geomean)
set -u
LANE=$1; NAME=$2; shift 2; NOTE="$*"
: "${LOOP_DIR:?}"; H=$LOOP_DIR/tools/lanes/$LANE; C=$LOOP_DIR/candidates/$LANE/$NAME; LEDGER=$LOOP_DIR/candidates/LEDGER.md
REPO_VAR="REPO_$LANE"; REPO=${!REPO_VAR:?set $REPO_VAR to the worktree of this lane}
mkdir -p "$C"
row() { echo "| $LANE | $NAME | $(date +%FT%T) | $1 | $2 | $3 | $NOTE |" >> "$LEDGER"; }
trap '[ -x "$LOOP_DIR/tools/report.sh" ] && "$LOOP_DIR/tools/report.sh"' EXIT
rm -rf "$C/src"; mkdir -p "$C/src"
if [ -n "${REV:-}" ]; then
  git -C "$REPO" archive "$REV" | tar -x -C "$C/src"; git -C "$REPO" rev-parse --short "$REV" > "$C/rev.txt"
  git -C "$REPO" show "$REV" > "$C/patch.diff"
else
  git -C "$REPO" archive HEAD | tar -x -C "$C/src"; git -C "$REPO" diff HEAD > "$C/patch.diff"; (cd "$C/src" && patch -p1 -s < "$C/patch.diff")
  git -C "$REPO" rev-parse --short HEAD > "$C/base_commit.txt"
fi
echo "[$LANE/$NAME] $(wc -l < "$C/patch.diff") patch lines; note: $NOTE"
bash "$H/build.sh" "$C" > "$C/build.log" 2>&1; grep -q BUILD_OK "$C/build.log" || { echo "[$LANE/$NAME] BUILD FAILED"; row "BUILD_FAIL" - -; exit 2; }
bash "$H/gate.sh" "$C" > "$C/gate.log" 2>&1
g=$(head -1 "$C/gate.txt" 2>/dev/null || echo "GATE FAIL: no gate.txt")
case "$g" in "GATE PASS"*) ;; *) echo "[$LANE/$NAME] $g"; row "${g:0:200}" - -; exit 3;; esac
bash "$H/time.sh" "$C" > "$C/time.log" 2>&1
bash "$H/score.sh" "$C" > "$C/score.log" 2>&1
fit=$(python3 -c "import json;print('%.4f'%json.load(open('$C/fitness.json'))['fitness'])" 2>/dev/null || echo "?")
per=$(python3 -c "import json;d=json.load(open('$C/fitness.json')).get('per_point',{});print('; '.join('%s %.3g'%(k,v) for k,v in d.items()))" 2>/dev/null || echo "-")
echo "[$LANE/$NAME] $g | FITNESS $fit"
row "${g:0:200}" "fitness $fit" "$per"
