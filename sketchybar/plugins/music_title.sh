#!/bin/bash
# Only scroll the now-playing label while the mouse is over it.
#
# Source: Kcraft059/sketchybar-config — plugins/music/script-title.sh
#   https://github.com/Kcraft059/sketchybar-config
# Local changes: acts on the single music pill ($NAME) instead of separate
# title/subtitle items; swaps the "…"-shortened label for the full one while
# hovered (both written by music_artwork.sh); their log_handler.sh replaced by
# a no-op sendLog.

sendLog() { :; }

# (local change: the original read the current state via `--query | jq`
# first, but SketchyBar doesn't escape quotes in labels, so titles like
# `Song "Live"` made that JSON invalid and hover-scroll stopped working.
# Setting the value is idempotent, so just set it.)
LABEL_DIR="${TMPDIR:-/tmp/}sketchybar"

setscroll() {
  sendLog "Toggled scroll for media title to $1" "vomit"
  local file="$LABEL_DIR/music_label_short"
  [ "$1" = "on" ] && file="$LABEL_DIR/music_label_full"
  if [ -f "$file" ]; then
    sketchybar --set "$NAME" label="$(cat "$file")" scroll_texts=$1
  else
    sketchybar --set "$NAME" scroll_texts=$1
  fi
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
