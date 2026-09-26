#!/bin/bash

# Now playing — polls `media-control` (brew install media-control).
# SketchyBar's built-in media_change event stopped working when macOS 15.4
# locked down MediaRemote, so this reads the system now-playing info instead.
# Works for any source: Spotify, Music, browser tabs (YouTube), etc.

export PATH="/opt/homebrew/bin:$PATH"

if [ "$SENDER" = "mouse.clicked" ]; then
  media-control toggle-play-pause
  sleep 0.3
fi

MEDIA="$(media-control get 2>/dev/null)"
TITLE="$(echo "$MEDIA" | jq -r '.title // empty' 2>/dev/null)"

if [ -z "$TITLE" ]; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

ARTIST="$(echo "$MEDIA" | jq -r '.artist // empty')"
PLAYING="$(echo "$MEDIA" | jq -r '.playing')"

# Tidy browser titles: drop "(3) " notification counters and " - YouTube"
TITLE="$(echo "$TITLE" | sed -E 's/^\([0-9]+\) //; s/ - YouTube$//')"

if [ -n "$ARTIST" ]; then
  LABEL="$TITLE — $ARTIST"
else
  LABEL="$TITLE"
fi

if [ "$PLAYING" = "true" ]; then
  ICON="􀑪"
else
  ICON="􀊆"
fi

sketchybar --set "$NAME" drawing=on icon="$ICON" label="$LABEL"
