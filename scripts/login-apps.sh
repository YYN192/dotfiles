#!/usr/bin/env bash
# login-apps — run at login by launchd (com.user.login-apps).
# Opens the startup apps, each on its own yabai space:
#   1 Firefox · 3 Claude · 4 Calendar · 5 Ghostty (empty terminal) · 10 Music
#
# Uses yabai one-shot rules: each rule places only the first window that
# matches it and then removes itself, so windows opened later go wherever
# you open them.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

# Wait (up to ~60s) for yabai to come up and know about all 10 spaces.
for _ in $(seq 60); do
  n=$(yabai -m query --spaces 2>/dev/null | jq length 2>/dev/null)
  [ "${n:-0}" -ge 10 ] && break
  sleep 1
done

# space  app-name (as yabai sees it)  bundle to open
apps=(
  "1|Firefox|Firefox"
  "3|Claude|Claude"
  "4|Calendar|Calendar"
  "5|Ghostty|Ghostty"
  "10|Music|Music"
)

for entry in "${apps[@]}"; do
  IFS='|' read -r space name bundle <<< "$entry"
  yabai -m rule --add --one-shot app="^${name}$" space="$space"
  open -a "$bundle"
done
