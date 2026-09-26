#!/bin/bash
# Clock + month-calendar popup (hover to show, click to toggle).
#
# Source: aspauldingcode — "Calendar popup" (awesome-sketchybar)
#   https://github.com/nicolas-martin/awesome-sketchybar/blob/main/plugins/Calendar-popup.md
#   https://github.com/FelixKratz/SketchyBar/discussions/12#discussioncomment-7785678
# Local changes:
#   - macOS's built-in `cal` instead of gcal (no longer in Homebrew); today is
#     marked [dd] the same way the original rewrote gcal's <dd>
#   - rows are rebuilt only on hover/click/startup, not on every clock tick
#   - the "skip empty lines" check tests the raw line (the original FIXME:
#     it tested the line after the | borders were added, so it never skipped)
#   - keeps this bar's own date format, icon and 1s clock

source "$CONFIG_DIR/colors.sh"

# Calendar output: pad each line to a fixed width, mark today as [dd].
# The leading space mirrors gcal's layout; " dd " -> "[dd]" keeps columns aligned.
build_calendar() {
  local today
  today="$(date +%-d)"
  cal | sed 's/[[:space:]]*$//' | awk '{printf " %-21s\n", $0}' | awk -v d="$today" '
    NR > 2 {
      pat = (d < 10) ? "  " d " " : " " d " "
      rep = (d < 10) ? "[ " d "]" : "[" d "]"
      i = index($0, pat)
      if (i > 0) $0 = substr($0, 1, i - 1) rep substr($0, i + length(pat))
    }
    { print }'
}

render_popup() {
  CALENDAR="$(build_calendar)"

  sketchybar --remove '/date.popup.cal_.*/' >/dev/null 2>&1

  local lines=() i item_name raw
  for i in 1 2 3 4 5 6 7 8; do
    raw="$(echo "$CALENDAR" | sed -n "${i}p")"
    if [[ -n "$raw" && "$raw" =~ [^[:space:]] ]]; then
      lines+=("| $raw |")
    fi
  done

  for (( i = 0; i < ${#lines[@]}; i++ )); do
    current_line="${lines[$i]}"
    row=(
      icon="$current_line"
      icon.padding_left=-3                          # set to -2 to hide behind border.
      icon.font="JetBrainsMonoNL Nerd Font:Regular:12.0"
      label.font="JetBrainsMonoNL Nerd Font:Bold:12.0"
      icon.color="$COLOR_TEXT"
      padding_left=0
      padding_right=0
      width=0
      background.drawing=off
      y_offset=$(( 56 - 16 * i ))
      label="|"
      label.color="$COLOR_POPUP_BORDER"             # popup border colour, hides the left '|'
      label.padding_left=-182                       # overwrite the '|' on the left of the line
      label.drawing=on
    )
    item_name="date.popup.cal_$((i+1))"
    sketchybar --add item "$item_name" popup.date --set "$item_name" "${row[@]}"
  done

  sketchybar --set "$item_name" background.padding_right=192
}

set_date_and_time() {
  sketchybar --animate tanh 10 --set "$NAME" label="$(date +'%a %d %b  -  %I:%M %p')"
}

case "$SENDER" in
  "mouse.entered")
    render_popup
    sketchybar --set "$NAME" popup.drawing=on
    ;;
  "mouse.exited" | "mouse.exited.global")
    sketchybar --set "$NAME" popup.drawing=off
    ;;
  "mouse.clicked")
    render_popup
    sketchybar --set "$NAME" popup.drawing=toggle
    ;;
  *)
    set_date_and_time
    ;;
esac
