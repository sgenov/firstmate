#!/usr/bin/env bash
# Live drive (adversarial): a real fm-watch.sh handling successor in a lab home;
# the real arm confirms --handling-delivered for its generation, then the real
# fm_recovery_marker_publish (the supervision host's hand-back call,
# fm-supervision-host.sh:1146) republishes that same generation as pending.
# The successor must not re-announce and must keep supervising. Usage: <tree> <label>
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
echo "== [$LABEL] lab=$LAB"
printf 'pending:downtime:inherited.1.aaa\n' > "$LAB/state/.watcher-down"
chmod 600 "$LAB/state/.watcher-down"
run env FM_POLL=1 FM_SIGNAL_GRACE=0 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=600 \
  FM_WATCH_HANDLING_SUCCESSOR=1 "$TREE/bin/fm-watch.sh" > "$OUT" 2>&1 &
W=$!
sleep 4
M=$(cat "$LAB/state/.watcher-down"); G=${M##*:}
W=$(cat "$LAB/state/.watch.lock/pid"); echo "watcher lock pid=$W"
echo "marker after start-up: $M (generation $G)"
echo "$ fm-watch-arm.sh --handling-delivered $G --watcher-pid $W"
run "$TREE/bin/fm-watch-arm.sh" --handling-delivered "$G" --watcher-pid "$W"; echo "exit=$?"
echo "marker after handling-delivered: $(cat "$LAB/state/.watcher-down")"
echo "$ host hand-back: fm_recovery_marker_publish \$STATE/.watcher-down downtime"
run bash -c '. "$1/bin/fm-wake-lib.sh"; fm_recovery_marker_publish "$FM_HOME/state/.watcher-down" downtime' _ "$TREE"; echo "exit=$?"
echo "marker after hand-back: $(cat "$LAB/state/.watcher-down")"
sleep 6
echo "--- watcher stdout ---"; cat "$OUT"; echo "----------------------"
echo "rearm-resurface lines: $(grep -cF 'check: rearm-resurface' "$OUT")"
echo "marker 6s after hand-back: $(cat "$LAB/state/.watcher-down")"
echo "successor alive: $(kill -0 $W 2>/dev/null && echo yes || echo no)"
kill -TERM $W 2>/dev/null; wait $W 2>/dev/null
"$TREE/bin/fm-lab-home.sh" teardown "$LAB" >/dev/null 2>&1
rm -rf "$LAB"
echo "lab removed: $([ -e "$LAB" ] && echo no || echo yes)"
