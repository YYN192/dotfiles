#!/bin/sh

# The volume_change event supplies a $INFO variable in which the current volume
# percentage is passed to the script. On startup/reload (forced update) there is
# no event, so read the current volume directly instead of showing 0%.

# Scroll on the pill to change volume: 10% per step, 1% with ctrl held
# (same behaviour as FelixKratz/dotfiles' volume widget). Setting the volume
# fires volume_change, which updates the pill below.
if [ "$SENDER" = "mouse.scrolled" ]; then
  FACTOR=10
  [ "$MODIFIER" = "ctrl" ] && FACTOR=1
  # $SCROLL_DELTA can be fractional, so let AppleScript do the maths
  osascript -e "set volume output volume (output volume of (get volume settings) + ($SCROLL_DELTA * $FACTOR))"
  exit 0
fi

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"
else
  VOLUME="$(osascript -e 'output volume of (get volume settings)')"
fi

case "$VOLUME" in
  [6-9][0-9]|100) ICON="􀊩"
  ;;
  [3-5][0-9]) ICON="􀊧"
  ;;
  [1-9]|[1-2][0-9]) ICON="􀊥"
  ;;
  *) ICON="􀊣"
esac

sketchybar --animate tanh 10 --set "$NAME" icon="$ICON" label="$VOLUME%"
