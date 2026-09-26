#!/bin/bash
# Now-playing pill (album art icon + "Title · Artist"), driven by `media-control stream`.
#
# Source: Kcraft059/sketchybar-config — plugins/music/script-artwork.sh
#   https://github.com/Kcraft059/sketchybar-config
# Local changes (everything else is the original logic):
#   - one pill instead of artwork + two-line title/subtitle + bracket: the art is
#     the icon's background image (cropped square), the label is "Title · Artist"
#   - play/pause flash shown by setting/clearing the icon glyph (hiding the icon
#     would hide the art; a transparent colour still drew the glyph's shadow)
#   - label shortened at a word boundary with "…"; full text scrolls on hover
#   - tracks without artwork (ads, some browser media) show a music-note glyph
#     instead of an empty gap or the previous track's cover
#   - hover events handed to music_title.sh before the stream starts
#   - image size/format via macOS's built-in `sips` instead of ImageMagick
#   - their log_handler.sh replaced by no-op sendLog/sendWarn
#   - TMPDIR fallback + cache dir creation (launchd may not set TMPDIR)
#   - dropped the `activities_update` trigger (it only fed their centre separator)

export PATH=/opt/homebrew/bin/:$PATH

# Hover events arrive here too (same item); don't start another stream for them
case "$SENDER" in
"mouse.entered" | "mouse.exited")
	exec "$(dirname "$0")/music_title.sh"
	;;
esac

source "$CONFIG_DIR/colors.sh"
sendLog() { :; }
sendWarn() { :; }

TMPDIR="${TMPDIR:-/tmp/}"
mkdir -p "${TMPDIR}sketchybar"

pids=($(ps -p $(pgrep sh) | grep $0 | awk '{print $1}')) # List any left-over execution of this same process

### Kill any possible remaining streaming process from last config on reload
# script is made to be invoked only once per bar reload

if [[ -n "$pids" ]]; then
	for i in $(cat ${TMPDIR}sketchybar/pids 2>/dev/null); do
		pids+=("$i")
	done
	sendWarn "Killing remaining media-control stream pids: ${pids[*]}" "debug"
	kill -9 ${pids[@]} 2>/dev/null
fi

ART_SIZE="$1"
MAX_CHARS=13
NO_ART_ICON="􀑪"
idle_icon="$NO_ART_ICON"   # glyph shown when not flashing play/pause
LABEL_FULL="${TMPDIR}sketchybar/music_label_full"
LABEL_SHORT="${TMPDIR}sketchybar/music_label_short"

# Shorten to MAX_CHARS at a word boundary, ending in "…" (unicode-aware)
shorten() {
	perl -CSA -e '
		my ($s, $m) = @ARGV;
		if (length($s) <= $m) { print $s; exit }
		my $c = substr($s, 0, $m - 1);
		if (substr($s, $m - 1, 1) !~ /\s/ && $c =~ /\s/) { $c =~ s/\s+\S*$// }
		$c =~ s/[\s\x{00B7},:;\-\x{2013}\x{2014}]+$//;
		print $c . "\x{2026}";
	' "$1" "$2"
}

### Open a stream to get current media continously

media-control stream | grep --line-buffered 'data' | while IFS= read -r line; do
	### List & store childs to prevent multiple background process remaining
	# Introduced because of a present bug, were the stream process detaches from the parent process causing stray processes

	if ps -p $$ >/dev/null; then
		pgrep -P $$ >${TMPDIR}sketchybar/pids
	fi

	if ! {
		[[ "$(echo $line | jq -r .payload)" == '{}' ]] ||
			{ [[ -n $lastAppPID ]] && ! ps -p "$lastAppPID" >/dev/null; }
	}; then
		### Only trigger update for media info if process playing media still exists and current line feed isn't null

		### Get data from line feed

		artworkData=$(echo $line | jq -r .payload.artworkData)
		currentPID=$(echo $line | jq -r .payload.processIdentifier) # Get app currently streaming media
		playing=$(echo $line | jq -r .payload.playing)

		### Set Artwork

		if [[ $artworkData != "null" ]]; then

			tmpfile=$(mktemp ${TMPDIR}sketchybar/cover.XXXXXXXXXX)

			### Dump raw artwork data into tmpfile

			echo $artworkData |
				base64 -d >$tmpfile

			### Assign corresponding extension depending on file type + convert if not supported
			# (local change: sips instead of ImageMagick's identify/magick)

			case $(sips -g format "$tmpfile" 2>/dev/null | awk '/format:/ {print $2}') in
			"jpeg")
				ext=jpg
				mv $tmpfile $tmpfile.$ext
				;;
			"png")
				ext=png
				mv $tmpfile $tmpfile.$ext
				;;
			*)
				sips -s format jpeg "$tmpfile" --out "$tmpfile.jpg" >/dev/null 2>&1
				ext=jpg
				;;
			esac

			sendLog "Artwork image generated at $tmpfile.$ext" "vomit"

			### Crop to a centred square, scale it to ART_SIZE

			img_h=$(sips -g pixelHeight "$tmpfile.$ext" | awk '/pixelHeight:/ {print $2}')
			img_w=$(sips -g pixelWidth "$tmpfile.$ext" | awk '/pixelWidth:/ {print $2}')
			side=$(( img_w < img_h ? img_w : img_h ))
			sips --cropToHeightWidth "$side" "$side" "$tmpfile.$ext" >/dev/null 2>&1

			scale=$(bc <<<"scale=4; $ART_SIZE / $side")

			### Set artwork as the icon's background image, then purge image

			idle_icon=""
			sketchybar --set $NAME icon.background.image=$tmpfile.$ext \
				icon.background.image.scale=$scale \
				icon.background.image.drawing=on \
				icon="$idle_icon"

			rm -f $tmpfile* && sendLog "Cleaned artwork image generated at $tmpfile.$ext" "vomit"
		fi

		### Set "Title · Artist" (artist omitted when empty, e.g. browser tabs)

		if [[ $(echo $line | jq -r .payload.title) != "null" ]]; then

			title_label="$(echo $line | jq -r .payload.title)"

			### New track without artwork in the same update: drop the old cover
			# (Spotify often sends the artwork a moment later; that re-enables it)
			if [[ $artworkData == "null" ]]; then
				idle_icon="$NO_ART_ICON"
				sketchybar --set $NAME icon.background.image.drawing=off icon="$idle_icon"
			fi
			artist="$(echo "$line" | jq -r '.payload.artist // empty')"

			label="$title_label"
			if [[ -n "$artist" ]]; then
				label+=" · $artist"
			fi

			# Resting label: just the title, with "…" only if the title itself is too
			# long (the artist is in the full label shown on hover)
			short="$(shorten "$title_label" "$MAX_CHARS")"
			printf '%s' "$label" >"$LABEL_FULL"
			printf '%s' "$short" >"$LABEL_SHORT"
			sketchybar --set $NAME label="$short" scroll_texts=off
		fi

		### Set Playing state indicator

		if [[ $playing != "null" && $(echo $line | jq -r .diff) == "true" ]]; then
			case $playing in
			"true")
				sendLog "Updating playing state to play" "vomit"
				sketchybar --set $NAME icon="􀊆"
				{
					sleep 5
					sketchybar --set $NAME icon="$idle_icon"
				} &
				;;
			"false")
				sendLog "Updating playing state to pause" "vomit"
				sketchybar --set $NAME icon="􀊄"
				{
					sleep 5
					sketchybar --set $NAME icon="$idle_icon"
				} &
				;;
			esac
		fi

		### Store app currently playing media to check for it's presence later

		if [[ $currentPID != "null" ]]; then
			lastAppPID=$currentPID
		fi

		sketchybar --set $NAME drawing=on

	else
		### If media stopped being played / app playing media is closed; hide music player

		sendLog "Media not playing $(if [[ -n $lastAppPID ]]; then echo "(media process: $lastAppPID)"; fi)" "debug"

		sketchybar --set $NAME drawing=off

		unset lastAppPID
	fi
done
