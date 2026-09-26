#!/bin/bash

# Clock + click-to-open calendar popup.
# Popup rows (date.header, date.cal.0-7, date.open) are created in sketchybarrc.

source "$CONFIG_DIR/colors.sh"

fill_calendar() {
  sketchybar --set date.header label="$(date +'%A, %d %B %Y')"

  # Mark today as [dd]. Padding each line with a space on both sides means the
  # " dd " → "[dd]" swap keeps every column aligned, even on Sun/Sat edges.
  local today i=0
  today="$(date +%-d)"
  while IFS= read -r line; do
    line=" $line "
    if [ "$i" -ge 2 ]; then
      if [ "$today" -lt 10 ]; then
        line="$(echo "$line" | sed -E "s/  $today /[ $today]/")"
      else
        line="$(echo "$line" | sed -E "s/ $today /[$today]/")"
      fi
    fi
    sketchybar --set "date.cal.$i" label="$line" drawing=on
    i=$((i + 1))
  done < <(cal | sed 's/[[:space:]]*$//' | grep -v '^$')

  # Months span 4-6 week rows; hide unused rows
  while [ "$i" -le 7 ]; do
    sketchybar --set "date.cal.$i" drawing=off
    i=$((i + 1))
  done
}

case "$SENDER" in
  mouse.clicked)
    if [ "$(sketchybar --query date | jq -r '.popup.drawing')" = "off" ]; then
      fill_calendar
      sketchybar --set volume popup.drawing=off --set date popup.drawing=on
    else
      sketchybar --set date popup.drawing=off
    fi
    ;;
  mouse.exited.global)
    sketchybar --set date popup.drawing=off
    ;;
  *)
    sketchybar --animate tanh 10 --set "$NAME" label="$(date +'%a %d %b  -  %I:%M %p')"
    ;;
esac
