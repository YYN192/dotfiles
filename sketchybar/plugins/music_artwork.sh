#!/bin/bash
# Now-playing pill (album art icon + "Title · Artist"), driven by `media-control stream`.
#
# Source: Kcraft059/sketchybar-config — plugins/music/script-artwork.sh
#   https://github.com/Kcraft059/sketchybar-config
# Local changes (everything else is the original logic):
#   - one pill instead of artwork + two-line title/subtitle + bracket: the art is
#     the icon's background image (cropped square), the label is "Title · Artist"
#   - play/pause flash shown by icon colour (hiding the icon would hide the art)
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

			sketchybar --set $NAME icon.background.image=$tmpfile.$ext \
				icon.background.image.scale=$scale

			rm -f $tmpfile* && sendLog "Cleaned artwork image generated at $tmpfile.$ext" "vomit"
		fi

		### Set "Title · Artist" (artist omitted when empty, e.g. browser tabs)

		if [[ $(echo $line | jq -r .payload.title) != "null" ]]; then

			title_label="$(echo $line | jq -r .payload.title)"
			artist="$(echo "$line" | jq -r '.payload.artist // empty')"

			label="$title_label"
			if [[ -n "$artist" ]]; then
				label+=" · $artist"
			fi

			sketchybar --set $NAME label="$label"
		fi

		### Set Playing state indicator

		if [[ $playing != "null" && $(echo $line | jq -r .diff) == "true" ]]; then
			case $playing in
			"true")
				sendLog "Updating playing state to play" "vomit"
				sketchybar --animate tanh 5 \
					--set $NAME icon="􀊆" \
					icon.color="$COLOR_TEXT"
				{
					sleep 5
					sketchybar --animate tanh 45 --set $NAME icon.color=0x00000000
				} &
				;;
			"false")
				sendLog "Updating playing state to pause" "vomit"
				sketchybar --animate tanh 5 \
					--set $NAME icon="􀊄" \
					icon.color="$COLOR_TEXT"
				{
					sleep 5
					sketchybar --animate tanh 45 --set $NAME icon.color=0x00000000
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
