#!/usr/bin/env bash
# login-apps — run at login by launchd (com.user.login-apps).
# Opens the startup apps, each on its own yabai space:
#   1 Firefox · 3 Claude · 4 Calendar · 5 Ghostty (empty terminal) · 10 Music
#
# Each app is opened, then its first window is moved to its space with
# `yabai -m window --space`. Nothing permanent: windows you open later go
# wherever you open them. (yabai one-shot rules were tried first, but they
# only catch brand-new windows and got stuck on apps that were already open.)

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Wait (up to ~60s) for yabai to come up and know about all 10 spaces.
for _ in $(seq 60); do
  n=$(yabai -m query --spaces 2>/dev/null | jq length 2>/dev/null)
  [ "${n:-0}" -ge 10 ] && break
  sleep 1
done

# space|app name as yabai reports it|app to open
apps=(
  "1|Firefox|Firefox"
  "3|Claude|Claude"
  "4|Calendar|Calendar"
  "5|Ghostty|Ghostty"
  "10|Music|Music"
)

# Launch everything at once, then place windows one at a time, in order, so a
# fullscreen space being removed can't shift the target of a later move.
for entry in "${apps[@]}"; do
  IFS='|' read -r _ _ bundle <<< "$entry"
  open -a "$bundle"
done

for entry in "${apps[@]}"; do
  IFS='|' read -r space name _ <<< "$entry"
  ( # wait up to 30s for a real window, then move it
    for _ in $(seq 60); do
      wid=$(yabai -m query --windows 2>/dev/null | jq -r --arg a "$name" \
        '[.[] | select(.app == $a and ."is-minimized" == false
                       and (.subrole == "AXStandardWindow" or .role == ""))]
         | sort_by([(.subrole != "AXStandardWindow"), .id]) | .[0].id // empty')
      if [ -n "$wid" ]; then
        # A native-fullscreen window (Claude restores like that) sits on its
        # own extra space, which shifts every space index after it. Un-fullscreen
        # it first, and wait for macOS to remove that space.
        if [ "$(yabai -m query --windows --window "$wid" | jq '."is-native-fullscreen"')" = "true" ]; then
          yabai -m window "$wid" --toggle native-fullscreen
          for _ in $(seq 20); do
            [ "$(yabai -m query --spaces | jq '[.[] | select(."is-native-fullscreen")] | length')" = "0" ] && break
            sleep 0.25
          done
          sleep 0.5
        fi
        yabai -m window "$wid" --space "$space" && echo "$(date '+%F %T') $name -> space $space"
        exit 0
      fi
      sleep 0.5
    done
    echo "$(date '+%F %T') $name: no window after 30s"
  )
done

# Land on space 1 (Firefox) once everything is placed.
yabai -m space --focus 1 2>/dev/null
