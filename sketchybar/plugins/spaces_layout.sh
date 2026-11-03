#!/usr/bin/env bash
# Lays out the app icons on all 10 space pills in one pass, and keeps the
# left group from running into the notch.
#
# Every space gets one icon per app (no duplicates), separated by single
# spaces. Empty spaces show just their number. If the group's right edge
# would cross the notch, spaces you're not on get fewer icons (4 -> 3 -> 2
# -> 1 -> none) until it fits; the focused space always keeps up to 4.
#
# Triggered by space_watcher on space/window changes. Overlapping triggers
# are folded into one rerun.

SPACES=10
MAX_ICONS=4      # most icons any one pill shows
NOTCH_W=${NOTCH_W:-186}      # notch width in points (MacBook Pro 14"/16")
MARGIN=${MARGIN:-10}        # keep this far left of the notch

LOCK="${TMPDIR:-/tmp}/sketchybar_spaces_layout.lock"
PENDING="$LOCK/pending"

# Fold bursts of events into a single rerun.
if ! mkdir "$LOCK" 2>/dev/null; then
  # Stale lock (crashed run) older than 10 s: take it over.
  if [ -n "$(find "$LOCK" -maxdepth 0 -mtime -10s 2>/dev/null)" ]; then
    touch "$PENDING" 2>/dev/null
    exit 0
  fi
fi
trap 'rm -rf "$LOCK"' EXIT

# Pull __icon_map in once instead of spawning icon_map.sh per app.
eval "$(sed -n '/^### START-OF-ICON-MAP/,/^### END-OF-ICON-MAP/p' "$CONFIG_DIR/plugins/icon_map.sh")"

layout() {
  local display_w focused limit windows
  display_w=$(yabai -m query --displays --display 1 | jq -r '.frame.w | floor')
  [ -z "$display_w" ] && display_w=1728
  limit=$(( (display_w - NOTCH_W) / 2 - MARGIN ))
  focused=$(yabai -m query --spaces --space | jq -r '.index')

  # space<TAB>app, one line per app per space, in window order, no repeats.
  windows=$(yabai -m query --windows | jq -r '
    [.[] | select(."is-minimized" == false)]
    | unique_by([.space, .app]) | sort_by(.space, .id)
    | .[] | "\(.space)\t\(.app)"')

  # icons[sid] = space-separated app-font glyph names
  local -a icons counts
  local sid app
  for ((sid = 1; sid <= SPACES; sid++)); do icons[sid]=""; counts[sid]=0; done
  while IFS=$'\t' read -r sid app; do
    [ -z "$sid" ] || [ "$sid" -gt "$SPACES" ] && continue
    __icon_map "$app"
    icons[sid]+="${icons[sid]:+ }$icon_result"
    counts[sid]=$(( counts[sid] + 1 ))
  done <<< "$windows"

  local cap args label right
  for ((cap = MAX_ICONS; cap >= 0; cap--)); do
    args=()
    for ((sid = 1; sid <= SPACES; sid++)); do
      local n=$cap
      [ "$sid" = "$focused" ] && n=$MAX_ICONS
      label=$(echo "${icons[sid]}" | cut -d' ' -f"1-$n" 2>/dev/null)
      [ "$n" -eq 0 ] && label=""
      if [ -n "$label" ]; then
        args+=(--set "space.$sid" label="$label" label.drawing=on icon.padding_right=4)
      else
        # Number only: balance the padding so the digit sits centred.
        args+=(--set "space.$sid" label="" label.drawing=off icon.padding_right=10)
      fi
    done
    sketchybar "${args[@]}"

    right=$(sketchybar --query "space.$SPACES" \
      | jq -r '.bounding_rects | to_entries[0].value | (.origin[0] + .size[0]) | floor')
    [ -z "$right" ] || [ "$right" = "null" ] && break
    [ "$right" -le "$limit" ] && break
  done
}

while :; do
  rm -f "$PENDING"
  layout
  [ -e "$PENDING" ] || break
done
