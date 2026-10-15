#!/usr/bin/env bash
# Live drive: a real fm-watch.sh handling successor in a disposable lab home,
# then a real `fm-inbox.sh note` from the captain. Usage: <tree> <label>
set -u
TREE=$1 LABEL=$2
LAB=$(mktemp -d "${TMPDIR:-/tmp}/fm-lab.XXXXXX")
"$TREE/bin/fm-lab-home.sh" create "$LAB" >/dev/null
TMUXD=$("$TREE/bin/fm-lab-home.sh" tmux-dir "$LAB")
OUT="$LAB/watch.out"
run() {
  env -u NO_MISTAKES_GATE -u FM_GATE_REFUSE_BYPASS -u FM_ROOT_OVERRIDE -u FM_STATE_OVERRIDE \
    -u FM_DATA_OVERRIDE -u FM_CONFIG_OVERRIDE -u FM_PROJECTS_OVERRIDE -u TMUX \
    FM_HOME="$LAB" TMUX_TMPDIR="$TMUXD" "$@"
}
echo "== [$LABEL] tree=$TREE lab=$LAB"
printf 'pending:downtime:inherited.1.aaa\n' > "$LAB/state/.watcher-down"
chmod 600 "$LAB/state/.watcher-down"
run env FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=600 \
  FM_WATCH_HANDLING_SUCCESSOR=1 "$TREE/bin/fm-watch.sh" > "$OUT" 2>&1 &
W=$!
sleep 4
echo "successor pid=$W alive=$(kill -0 $W 2>/dev/null && echo yes || echo no)"
echo "marker after start-up: $(cat "$LAB/state/.watcher-down")"
echo "rearm-resurface lines before note: $(grep -cF 'check: rearm-resurface' "$OUT")"
echo "$ fm-inbox.sh note 'captain: please look at the flaky deploy'"
run "$TREE/bin/fm-inbox.sh" note "captain: please look at the flaky deploy"; echo "note exit=$?"
echo "marker right after note: $(cat "$LAB/state/.watcher-down")"
sleep 8
echo "--- watcher stdout after note ---"
cat "$OUT"
echo "---------------------------------"
echo "rearm-resurface lines: $(grep -cF 'check: rearm-resurface' "$OUT")"
echo "marker 8s after note: $(cat "$LAB/state/.watcher-down")"
echo "successor alive: $(kill -0 $W 2>/dev/null && echo yes || echo no)"
echo "$ fm-inbox.sh ready"; run "$TREE/bin/fm-inbox.sh" ready
kill -TERM $W 2>/dev/null; wait $W 2>/dev/null
"$TREE/bin/fm-lab-home.sh" teardown "$LAB" >/dev/null 2>&1
rm -rf "$LAB"
echo "lab removed: $([ -e "$LAB" ] && echo no || echo yes)"
