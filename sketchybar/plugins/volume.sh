#!/bin/bash
# Volume pill + click popup (slider + output devices), scroll to change volume,
# right-click for Sound settings.
#
# Source: FelixKratz/dotfiles — .config/sketchybar/items/widgets/volume.lua
#   https://github.com/FelixKratz/dotfiles/blob/master/.config/sketchybar/items/widgets/volume.lua
# Translated 1:1 from SbarLua to a shell plugin. Local changes:
#   - one pill (icon + label) instead of his two-item bracket
#   - right-click opens the macOS 26 Sound pane (Sound.prefpane no longer exists)
#   - forced update reads the current volume so the pill never starts at 0%
#   - Rosé Pine colours from colors.sh

export PATH="/opt/homebrew/bin:$PATH"
source "$CONFIG_DIR/colors.sh"

POPUP_WIDTH=250

volume_update() {
  local volume="$1" icon="􀊣" lead=""
  if [ "$volume" -gt 60 ]; then
    icon="􀊩"
  elif [ "$volume" -gt 30 ]; then
    icon="􀊧"
  elif [ "$volume" -gt 10 ]; then
    icon="􀊥"
  elif [ "$volume" -gt 0 ]; then
    icon="􀊡"
  fi

  if [ "$volume" -lt 10 ]; then
    lead="0"
  fi

  sketchybar --set volume icon="$icon" label="$lead$volume%" \
             --set volume.slider slider.percentage="$volume"
}

volume_collapse_details() {
  if [ "$(sketchybar --query volume | jq -r '.popup.drawing')" != "on" ]; then
    return
  fi
  sketchybar --set volume popup.drawing=off
  sketchybar --remove '/volume.device\.*/' >/dev/null 2>&1
}

volume_toggle_details() {
  if [ "$BUTTON" = "right" ]; then
    open "x-apple.systempreferences:com.apple.Sound-Settings.extension"
    return
  fi

  if [ "$(sketchybar --query volume | jq -r '.popup.drawing')" = "off" ]; then
    sketchybar --set volume popup.drawing=on
    local current counter=0 color
    current="$(SwitchAudioSource -t output -c)"
    while IFS= read -r device; do
      [ -z "$device" ] && continue
      color="$COLOR_MUTED"
      if [ "$current" = "$device" ]; then
        color="$COLOR_TEXT"
      fi
      sketchybar --add item "volume.device.$counter" popup.volume \
                 --set "volume.device.$counter" \
                       width=$POPUP_WIDTH \
                       align=center \
                       background.drawing=off \
                       icon.drawing=off \
                       label="$device" \
                       label.color="$color" \
                       click_script="SwitchAudioSource -s \"$device\" && sketchybar --set /volume.device\\.*/ label.color=$COLOR_MUTED --set \$NAME label.color=$COLOR_TEXT"
      counter=$((counter + 1))
    done < <(SwitchAudioSource -a -t output)
  else
    volume_collapse_details
  fi
}

volume_scroll() {
  # $SCROLL_DELTA can be fractional, so let AppleScript do the maths
  local factor=10
  if [ "$MODIFIER" = "ctrl" ]; then
    factor=1
  fi
  osascript -e "set volume output volume (output volume of (get volume settings) + ($SCROLL_DELTA * $factor))"
}

case "$SENDER" in
  volume_change) volume_update "$INFO" ;;
  mouse.clicked) volume_toggle_details ;;
  mouse.exited.global) volume_collapse_details ;;
  mouse.scrolled) volume_scroll ;;
  *) volume_update "$(osascript -e 'output volume of (get volume settings)')" ;;
esac
