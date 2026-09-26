#!/bin/bash
# Only scroll the now-playing title/subtitle while the mouse is over them.
#
# Source: Kcraft059/sketchybar-config — plugins/music/script-title.sh
#   https://github.com/Kcraft059/sketchybar-config
# Local change: their log_handler.sh replaced by a no-op sendLog.

sendLog() { :; }

setscroll() {
  STATE="$(sketchybar --query "music.title" | sed 's/\\n//g; s/\\\$//g; s/\\ //g' | jq -r '.geometry.scroll_texts')"


	case "$1" in
  "on")
    target="off"
    ;;
  "off")
    target="on"
    ;;
  esac

  if [[ "$STATE" == "$target" ]]; then
		sendLog "Toggled scroll for media title to $1" "vomit"
    sketchybar --set "music.title" scroll_texts=$1
    sketchybar --set "music.subtitle" scroll_texts=$1
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
