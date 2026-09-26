#!/bin/bash
# Only scroll the now-playing label while the mouse is over it.
#
# Source: Kcraft059/sketchybar-config — plugins/music/script-title.sh
#   https://github.com/Kcraft059/sketchybar-config
# Local changes: acts on the single music pill ($NAME) instead of separate
# title/subtitle items; their log_handler.sh replaced by a no-op sendLog.

sendLog() { :; }

# (local change: the original read the current state via `--query | jq`
# first, but SketchyBar doesn't escape quotes in labels, so titles like
# `Song "Live"` made that JSON invalid and hover-scroll stopped working.
# Setting the value is idempotent, so just set it.)
setscroll() {
  sendLog "Toggled scroll for media title to $1" "vomit"
  sketchybar --set "$NAME" scroll_texts=$1
}

### Only scroll text on mouse hover for better performances

case "$SENDER" in
"mouse.entered")
  setscroll on
  ;;
"mouse.exited")
  setscroll off
  ;;
esac
