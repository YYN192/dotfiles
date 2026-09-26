#!/bin/bash
# Smooth scroll-to-change-volume for the volume pill.
#
# SketchyBar coalesces scroll events (src/event.c, SCROLL_TIMEOUT = 150ms): it
# delivers at most one mouse.scrolled per ~150ms, with $SCROLL_DELTA = whole
# lines scrolled in that window. So |delta| is effectively scroll velocity.
#
# 1. Acceleration (cf. libinput's adaptive pointer-acceleration profile):
#    step = BASE * |delta|^EXP, capped at CAP. A slow notch nudges by BASE%,
#    a fast swipe moves faster, never more than CAP% per 150ms window.
#    ctrl held = flat 1% per line for fine control.
# 2. Accumulating target: consecutive scrolls add to a remembered target
#    rather than to the mid-glide volume, so fast scrolling never loses steps.
#    The target re-syncs from the real volume after IDLE_RESET_MS of no scrolling.
# 3. Gain ramping (cf. JUCE SmoothedValue): glide to the target in STEPS
#    steps over ~STEPS*STEP_DELAY_MS ms with an ease-out curve, instead of
#    jumping. A new scroll kills the running glide and retargets from wherever
#    the volume currently is. macOS's 0-100 output volume is already a
#    perceptual scale, so a linear-space glide is appropriate.

BASE=3
EXP=1.5
CAP=15
IDLE_RESET_MS=800
STEPS=6
STEP_DELAY_MS=15   # whole ms: AppleScript number parsing is locale-dependent (bg uses ",")

STATE_DIR="${TMPDIR:-/tmp/}sketchybar"
STATE="$STATE_DIR/volume_scroll"
mkdir -p "$STATE_DIR"

now="$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')"   # ms
delta="$SCROLL_DELTA"
[ -z "$delta" ] || [ "$delta" = "0" ] && exit 0

# Base value: the pending target if we scrolled recently, else the pill's
# current value (cheaper than asking osascript).
base=""
glide_pid=""
if [ -f "$STATE" ]; then
  read -r last_target last_time last_pid < "$STATE"
  if [ $((now - last_time)) -le "$IDLE_RESET_MS" ]; then
    base="$last_target"
    glide_pid="$last_pid"   # only trust the PID while it's recent
  fi
fi
if [ -z "$base" ]; then
  base="$(sketchybar --query volume | jq -r '.label.value' | tr -d '%')"
fi

target="$(awk -v b="$base" -v d="$delta" -v ctrl="$MODIFIER" \
              -v base="$BASE" -v e="$EXP" -v cap="$CAP" 'BEGIN {
  a = (d < 0) ? -d : d
  s = (ctrl == "ctrl") ? a : base * a ^ e
  if (s > cap) s = cap
  t = b + ((d < 0) ? -s : s)
  if (t < 0) t = 0
  if (t > 100) t = 100
  printf "%.0f", t
}')"

# Retarget: stop the previous glide (subshell + its osascript), start a new
# one from the current volume
if [ -n "$glide_pid" ] && ps -p "$glide_pid" -o command= | grep -q volume_scroll; then
  pkill -P "$glide_pid" 2>/dev/null
  kill "$glide_pid" 2>/dev/null
fi

(
osascript - "$target" "$STEPS" "$STEP_DELAY_MS" <<'APPLESCRIPT'
on run argv
  set targetV to (item 1 of argv) as number
  set steps to (item 2 of argv) as integer
  set dt to ((item 3 of argv) as integer) / 1000
  set startV to output volume of (get volume settings)
  repeat with i from 1 to steps
    set t to i / steps
    set eased to 1 - (1 - t) ^ 3
    set volume output volume (startV + (targetV - startV) * eased)
    if i < steps then delay dt
  end repeat
end run
APPLESCRIPT
# The glide fires several volume_change events whose handlers run in
# parallel and can finish out of order; resync the pill to the final value.
sketchybar --trigger volume_change INFO="$target"
) &

echo "$target $now $!" > "$STATE"
