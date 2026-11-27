#!/bin/bash
# setup.sh - sets up the system with the rice
# Make sure to clone the repo to .config!
# Run: bash ~/.config/setup.sh

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# ── Homebrew ──────────────────────────────────────────────────────────────────
echo "--- Homebrew ---"
if ! command -v brew &>/dev/null; then
    echo "Please install Homebrew first! https://brew.sh/"
    exit 1
fi

# ── Taps ──────────────────────────────────────────────────────────────────────
echo "--- Taps ---"
brew tap cormacrelf/tap
brew tap FelixKratz/formulae
brew tap koekeishiya/formulae   # yabai + skhd live here

# ── Packages ──────────────────────────────────────────────────────────────────
echo "--- Packages ---"
brew install \
    borders \
    btop \
    dark-notify \
    fastfetch \
    fish \
    fisher \
    media-control \
    neovim \
    sketchybar \
    skhd \
    starship \
    yabai

# Modern CLI tools (wired up in fish/conf.d/cli-tools.fish)
brew install atuin bat eza fd fzf lazydocker lazygit ripgrep yazi zoxide

echo "--- Casks ---"
brew install --cask ghostty raycast karabiner-elements

echo "--- Fonts ---"
brew install --cask font-sf-pro font-jetbrains-mono-nerd-font font-sketchybar-app-font sf-symbols

# ── Fish as default shell ─────────────────────────────────────────────────────
echo "--- Fish shell ---"
FISH_PATH="$(brew --prefix)/bin/fish"
if ! grep -qF "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells
fi
if [ "$SHELL" != "$FISH_PATH" ]; then
    chsh -s "$FISH_PATH"
fi

# ── Fisher plugins (reads from fish/fish_plugins) ─────────────────────────────
echo "--- Fisher plugins ---"
fish -c "fisher update"

# ── Script permissions ────────────────────────────────────────────────────────
echo "--- Script permissions ---"
chmod +x "$HOME/.config/switch-theme.sh" "$HOME"/.config/sketchybar/plugins/*.sh "$HOME"/.config/scripts/*.sh

# ── Yabai scripting addition sudoers entry ────────────────────────────────────
echo "--- Yabai scripting addition ---"
YABAI_PATH="$(brew --prefix)/bin/yabai"
SUDOERS_FILE="/private/etc/sudoers.d/yabai"
echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 "$YABAI_PATH" | cut -d ' ' -f 1) $YABAI_PATH --load-sa" \
    | sudo tee "$SUDOERS_FILE" >/dev/null
sudo chmod 440 "$SUDOERS_FILE"

# ── Dark-notify LaunchAgent ───────────────────────────────────────────────────
echo "--- Automatic theme switching ---"
PLIST="$HOME/Library/LaunchAgents/com.user.dark-notify.plist"
launchctl unload "$PLIST" 2>/dev/null || true

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.dark-notify</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/dark-notify</string>
        <string>-c</string>
        <string>$HOME/.config/switch-theme.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/dark-notify.err</string>
</dict>
</plist>
EOF

launchctl load "$PLIST"

# ── Spotify rice: Spicetify + Ziro, kept current at every login ───────────────
echo "--- Spicetify ---"
chmod +x "$HOME/.config/scripts/spicetify-autoupdate.sh"
if [ ! -x "$HOME/.spicetify/spicetify" ]; then
    # Official installer (installs to ~/.spicetify; it asks about Marketplace,
    # the autoupdate agent below installs/updates Marketplace and Ziro either way)
    curl -fsSL https://raw.githubusercontent.com/spicetify/cli/main/install.sh | sh
fi
AGENT="$HOME/Library/LaunchAgents/com.user.spicetify-autoupdate.plist"
launchctl bootout "gui/$(id -u)/com.user.spicetify-autoupdate" 2>/dev/null || true
sed "s#__HOME__#$HOME#g" "$HOME/.config/launchd/com.user.spicetify-autoupdate.plist" > "$AGENT"
# Runs once now, then at every login (log: ~/Library/Logs/spicetify-autoupdate.log)
launchctl bootstrap "gui/$(id -u)" "$AGENT" || echo "Could not load $AGENT; run it with: launchctl bootstrap gui/$(id -u) $AGENT"

# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "Done! Restart for the changes to take effect, then run:"
echo ""
echo "  yabai --start-service"
echo "  brew services start sketchybar"
echo "  skhd --start-service"
echo ""
echo "Open Karabiner-Elements once and grant it permissions; it reads ~/.config/karabiner/karabiner.json"
echo "(Caps Lock = Super/Esc, Cmd + Caps = switch keyboard language)."
echo "Neovim (LazyVim + Rose Pine) installs its plugins on first launch: just run nvim."
echo ""
echo "A few things to note:"
echo ""
echo "1. SIP must be partially disabled for yabai's scripting addition: https://github.com/asmvik/yabai/wiki/Disabling-System-Integrity-Protection"
echo "   After each 'brew upgrade yabai', re-run the sudoers block in this script"
echo ""
echo "2. The automatic theme switcher follows your system appearance, but it does not change the wallpaper."
echo ""
echo "3. Uninstalling the rice is a manual process. You will need to remove the installed packages, the LaunchAgent, and any configuration files you no longer want."
echo ""
echo "Hope you enjoy your new setup! I encourage you to explore the configuration files and customize them to your liking. The true power of a rice is in its customizability, so make it your own!"
