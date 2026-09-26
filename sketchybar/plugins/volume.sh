#!/bin/bash

# Volume level + click-to-open popup with a slider and the audio output list.
# The volume_change event supplies the current percentage in $INFO. On
# startup/reload (forced update) there is no event, so read it directly.

export PATH="/opt/homebrew/bin:$PATH"
source "$CONFIG_DIR/colors.sh"

update_level() {
  local volume="$1" icon
  case "$volume" in
    [6-9][0-9]|100) icon="􀊩" ;;
    [3-5][0-9]) icon="􀊧" ;;
    [1-9]|[1-2][0-9]) icon="􀊥" ;;
    *) icon="􀊣" ;;
  esac
  sketchybar --animate tanh 10 --set volume icon="$icon" label="$volume%" \
             --set volume.slider slider.percentage="$volume"
}

# Rebuild the output-device rows; the active one gets a checkmark.
fill_devices() {
  sketchybar --remove '/volume\.device\..*/' >/dev/null 2>&1
  local current i=0
  current="$(SwitchAudioSource -c -t output)"
  while IFS= read -r device; do
    [ -z "$device" ] && continue
    if [ "$device" = "$current" ]; then
      icon="􀆅"; color="$COLOR_PINE"
    else
      icon=" "; color="$COLOR_TEXT"
    fi
    sketchybar --add item "volume.device.$i" popup.volume \
               --set "volume.device.$i" \
                     icon="$icon" icon.color="$color" icon.width=20 \
                     label="$device" label.color="$color" \
                     background.drawing=off \
                     click_script="SwitchAudioSource -s \"$device\" -t output >/dev/null; sketchybar --set volume popup.drawing=off"
    i=$((i + 1))
  done < <(SwitchAudioSource -a -t output)
}

case "$SENDER" in
  volume_change)
    update_level "$INFO"
    ;;
  mouse.clicked)
    if [ "$(sketchybar --query volume | jq -r '.popup.drawing')" = "off" ]; then
      fill_devices
      sketchybar --set date popup.drawing=off --set volume popup.drawing=on
    else
      sketchybar --set volume popup.drawing=off
    fi
    ;;
  mouse.exited.global)
    sketchybar --set volume popup.drawing=off
    ;;
  *)
    update_level "$(osascript -e 'output volume of (get volume settings)')"
    ;;
esac
