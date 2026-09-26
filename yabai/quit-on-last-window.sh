#!/usr/bin/env bash
# Make closing an app's last window (e.g. the red traffic-light button)
# actually quit the app, instead of leaving it idle in the Dock.
# Invoked by a yabai `window_destroyed` signal, with the window's PID as $1.

pid="$1"
[ -z "$pid" ] && exit 0

# Apps to leave running even when they have no open windows.
# Pipe-separated, must match the .app bundle name (e.g. 'Finder|Music|Spotify').
EXCLUDE='Finder'

# Let the window finish closing before we count what's left.
sleep 0.2

# How many windows does this process still own?
remaining=$(yabai -m query --windows 2>/dev/null \
  | jq --arg pid "$pid" '[.[] | select(.pid == ($pid | tonumber))] | length')

# Still has windows (or the query failed) -> leave it alone.
[ "$remaining" = "0" ] || exit 0

# Resolve a human-readable app name from the PID.
appname=$(ps -p "$pid" -o comm= 2>/dev/null | sed -E 's#.*/([^/]+)\.app/.*#\1#')
[ -z "$appname" ] && exit 0              # process already gone
case "$appname" in */*) exit 0 ;; esac   # couldn't resolve a clean .app name

# Honor the exclusion list.
case "|$EXCLUDE|" in *"|$appname|"*) exit 0 ;; esac

# Graceful quit, so the app can still run its save prompts.
osascript -e "tell application \"$appname\" to quit" 2>/dev/null
