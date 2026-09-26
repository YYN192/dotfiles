#!/bin/bash
# switch-theme.sh — called by dark-notify on appearance change, or manually with "dark"/"light"

CONFIG="$HOME/.config"

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

MODE="${1:-}"
if [ -z "$MODE" ]; then
    if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
        MODE="dark"
    else
        MODE="light"
    fi
fi

# Only reload sketchybar when the palette actually changes. At login dark-notify
# fires while sketchybar is still running sketchybarrc, and a reload mid-config
# leaves the right-side items without their --default styling.
set_bar_colors() {
    if ! cmp -s "$CONFIG/sketchybar/colors-$1.sh" "$CONFIG/sketchybar/colors.sh"; then
        cp "$CONFIG/sketchybar/colors-$1.sh" "$CONFIG/sketchybar/colors.sh"
        sketchybar --reload
    fi
}

# Spotify (Spicetify, Ziro theme): switch the colour scheme without restarting
# Spotify; it shows on the next launch. `refresh` never closes Spotify (in
# spicetify.go only apply/restore trigger a restart). Shares a lock with
# scripts/spicetify-autoupdate.sh, which sets the scheme itself at login.
set_spotify_scheme() {
    local sp="$HOME/.spicetify/spicetify" lock="/tmp/spicetify-$(id -u).lock"
    [ -x "$sp" ] || return 0
    grep -Eq "^color_scheme[[:space:]]*=[[:space:]]*$1\$" "$HOME/.config/spicetify/config-xpui.ini" && return 0
    mkdir "$lock" 2>/dev/null || return 0   # autoupdate is running; it sets the scheme
    echo $$ > "$lock/pid"
    "$sp" -q config color_scheme "$1" && "$sp" -q refresh
    rm -rf "$lock"
}

case "$MODE" in
    dark)
        # Sketchybar
        set_bar_colors dark
        set_spotify_scheme rose-pine

        # Starship
        sed -i '' 's/^palette = .*/palette = "rose-pine"/' "$CONFIG/starship.toml"

        # Fish
        fish -c 'fish_config theme choose "Rosé Pine"' 2>/dev/null
        sed -i '' 's/^set --global fish_color_command .*/set --global fish_color_command c4a7e7/' "$HOME/.config/fish/conf.d/fish_frozen_theme.fish"

        # JankyBorders
        sed -i '' 's/^borders active_color=.*/borders active_color=0xffc4a7e7 inactive_color=0xff6e6a86 width=5.0 hidpi=on/' "$CONFIG/yabai/yabairc"
        pkill -x borders 2>/dev/null; sleep 0.2
        nohup /opt/homebrew/bin/borders active_color=0xffc4a7e7 inactive_color=0xff6e6a86 width=5.0 hidpi=on >/dev/null 2>&1 &
        ;;

    light)
        # Sketchybar
        set_bar_colors dawn
        set_spotify_scheme rose-pine-dawn

        # Starship
        sed -i '' 's/^palette = .*/palette = "rose-pine-dawn"/' "$CONFIG/starship.toml"

        # Fish
        fish -c 'fish_config theme choose "Rosé Pine Dawn"' 2>/dev/null
        sed -i '' 's/^set --global fish_color_command .*/set --global fish_color_command 907aa9/' "$HOME/.config/fish/conf.d/fish_frozen_theme.fish"

        # JankyBorders
        sed -i '' 's/^borders active_color=.*/borders active_color=0xff575279 inactive_color=0xff9893a5 width=5.0 hidpi=on/' "$CONFIG/yabai/yabairc"
        pkill -x borders 2>/dev/null; sleep 0.2
        nohup /opt/homebrew/bin/borders active_color=0xff575279 inactive_color=0xff9893a5 width=5.0 hidpi=on >/dev/null 2>&1 &
        ;;
esac
