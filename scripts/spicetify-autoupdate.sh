#!/bin/bash
# spicetify-autoupdate — run at login by launchd (com.user.spicetify-autoupdate).
#
# Keeps the Spotify rice alive and current:
#   1. Spicetify CLI      — official release tarball when a newer release exists
#   2. Marketplace        — official release zip when a newer tag exists
#   3. Ziro theme         — spicetify-themes files when the Ziro folder changed
#   4. Colour scheme      — rose-pine / rose-pine-dawn from the macOS appearance
#   5. Re-apply           — only what is needed:
#        Spotify updated itself      -> spicetify backup apply
#        CLI changed, same Spotify   -> spicetify restore backup apply
#        marketplace/theme/scheme    -> spicetify apply
#        patch missing for any other reason -> spicetify backup apply
#
# Prior art this builds on (none of them update the CLI or Marketplace):
#   - RubenNijhuis/dotfiles ops/automation/spicetify-reapply.sh — compare
#     Spotify's CFBundleShortVersionString with config [Backup] version
#   - Gildaciolopes/spicetify-autopatch — a patched Spotify has
#     Apps/xpui/index.html mentioning "spicetify"; a stock one never does
#   - spicetify docs: "After Spotify updates: spicetify backup apply"
#
# The CLI is upgraded the same way `spicetify upgrade` does it (src/cmd/update.go:
# download the release tarball, extract over the install dir) but done here,
# because after a successful upgrade spicetify.go spawns its own
# `spicetify backup apply` without -n/-q, which restarts (i.e. launches)
# Spotify at login and bypasses the lock and the decisions below.
#
# Always runs spicetify with -q: quiet mode auto-answers the CLI's yes/no
# prompts (src/cmd/cmd.go ReadAnswer), so nothing can hang at login.
#
# Spotify is always closed while it's patched. If it was running, spicetify
# restarts it afterwards; if it wasn't (the usual case at login), -n keeps it
# from being launched.
#
# Usage: spicetify-autoupdate.sh [--dry-run]

set -uo pipefail

export PATH="$HOME/.spicetify:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

CONFIG_DIR="$HOME/.config/spicetify"
CONFIG_FILE="$CONFIG_DIR/config-xpui.ini"
STATE_DIR="$HOME/.local/state/spicetify-autoupdate"
LOG="$HOME/Library/Logs/spicetify-autoupdate.log"
LOCK="/tmp/spicetify-$(id -u).lock"     # shared with ~/.config/switch-theme.sh

THEME="Ziro"
SCHEME_DARK="rose-pine"
SCHEME_LIGHT="rose-pine-dawn"
THEMES_REPO="spicetify/spicetify-themes"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)    DRY_RUN=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

mkdir -p "$STATE_DIR" "$(dirname "$LOG")"

# Keep the log short: last ~500 lines
if [ -f "$LOG" ] && [ "$(wc -l <"$LOG")" -gt 1000 ]; then
  tail -n 500 "$LOG" >"$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
exec >>"$LOG" 2>&1

log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }
notify() { osascript -e "display notification \"$1\" with title \"Spicetify\"" >/dev/null 2>&1 || true; }
run() {
  log "  \$ $*"
  if [ "$DRY_RUN" = 1 ]; then return 0; fi
  "$@"
}

log "---- run start (pid $$)"

# --- lock (switch-theme.sh also touches spicetify at login) -------------------
for _ in $(seq 1 60); do
  if mkdir "$LOCK" 2>/dev/null; then break; fi
  # stale lock from a crashed run?
  if [ -f "$LOCK/pid" ] && ! kill -0 "$(cat "$LOCK/pid")" 2>/dev/null; then
    rm -rf "$LOCK"; continue
  fi
  sleep 1
done
if [ ! -d "$LOCK" ]; then log "could not get lock, giving up"; exit 1; fi
echo $$ >"$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT

if ! command -v spicetify >/dev/null; then
  log "spicetify not installed (~/.spicetify/spicetify missing), nothing to do"
  exit 0
fi

# --- wait for the network (login can beat Wi-Fi) ------------------------------
online=0
for _ in $(seq 1 30); do
  if curl -fsS -o /dev/null -m 5 https://api.github.com; then online=1; break; fi
  sleep 2
done
[ "$online" = 1 ] || log "offline: skipping update checks, will still repair the patch"

gh_latest_tag() {  # $1 = owner/repo
  curl -fsS -m 20 "https://api.github.com/repos/$1/releases/latest" | jq -r '.tag_name // empty'
}

version_gt() {  # true if $1 > $2 (strips a leading v)
  local a="${1#v}" b="${2#v}"
  [ "$a" != "$b" ] && [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | tail -1)" = "$a" ]
}

ini_get() {  # $1 = section, $2 = key
  awk -F'=' -v s="[$1]" -v k="$2" '
    $0 == s {inb=1; next} /^\[/ {inb=0}
    inb { key=$1; gsub(/^[ \t]+|[ \t]+$/, "", key)
          if (key == k) { v=$2; gsub(/^[ \t]+|[ \t]+$/, "", v); print v; exit } }
  ' "$CONFIG_FILE"
}

cli_changed=0
assets_changed=0
failures=()
changes=()

# --- 1. Spicetify CLI ---------------------------------------------------------
cli_dir="$HOME/.spicetify"
cli_before="$(spicetify -v 2>/dev/null)"
if [ "$online" = 1 ]; then
  cli_latest="$(gh_latest_tag spicetify/cli)"
  if [ -n "$cli_latest" ] && version_gt "$cli_latest" "$cli_before"; then
    ver="${cli_latest#v}"
    arch="amd64"; [ "$(uname -m)" = arm64 ] && arch="arm64"
    url="https://github.com/spicetify/cli/releases/download/$cli_latest/spicetify-$ver-darwin-$arch.tar.gz"
    log "CLI $cli_before -> $ver ($url)"
    tmp="$(mktemp -d)"
    if curl -fsSL -m 180 -o "$tmp/cli.tar.gz" "$url" \
       && mkdir "$tmp/x" && tar -xzf "$tmp/cli.tar.gz" -C "$tmp/x" \
       && [ "$("$tmp/x/spicetify" -v 2>/dev/null)" = "$ver" ]; then
      if [ "$DRY_RUN" = 0 ]; then
        rm -rf "$cli_dir.bak" && cp -R "$cli_dir" "$cli_dir.bak"
        if tar -xzf "$tmp/cli.tar.gz" -C "$cli_dir" && [ "$(spicetify -v 2>/dev/null)" = "$ver" ]; then
          rm -rf "$cli_dir.bak"
          cli_changed=1; changes+=("CLI ${cli_before} → ${ver}")
        else
          log "CLI install failed, rolling back to $cli_before"
          rm -rf "$cli_dir" && mv "$cli_dir.bak" "$cli_dir"
          failures+=("CLI upgrade")
        fi
      else
        cli_changed=1; changes+=("CLI ${cli_before} → ${ver}")
      fi
    else
      log "CLI download/verify failed, keeping $cli_before"
      failures+=("CLI upgrade")
    fi
    rm -rf "$tmp"
  else
    log "CLI $cli_before is current"
  fi
fi

# --- 2. Marketplace -----------------------------------------------------------
mp_dir="$CONFIG_DIR/CustomApps/marketplace"
mp_state="$STATE_DIR/marketplace.version"
mp_installed="$(cat "$mp_state" 2>/dev/null || echo none)"
if [ "$online" = 1 ]; then
  mp_latest="$(gh_latest_tag spicetify/marketplace)"
  if [ -n "$mp_latest" ] && { [ "$mp_installed" = none ] || version_gt "$mp_latest" "$mp_installed"; }; then
    log "Marketplace $mp_installed -> $mp_latest"
    tmp="$(mktemp -d)"
    if curl -fsSL -m 120 -o "$tmp/marketplace.zip" \
         "https://github.com/spicetify/marketplace/releases/download/$mp_latest/marketplace.zip" \
       && unzip -q -o "$tmp/marketplace.zip" -d "$tmp" \
       && [ -s "$tmp/marketplace-dist/index.js" ] && [ -s "$tmp/marketplace-dist/manifest.json" ]; then
      if [ "$DRY_RUN" = 0 ]; then
        mkdir -p "$CONFIG_DIR/CustomApps"
        rm -rf "$mp_dir.old"
        [ -d "$mp_dir" ] && mv "$mp_dir" "$mp_dir.old"
        mv "$tmp/marketplace-dist" "$mp_dir" && rm -rf "$mp_dir.old"
        echo "$mp_latest" >"$mp_state"
      fi
      assets_changed=1; changes+=("Marketplace ${mp_latest}")
    else
      log "Marketplace download/verify failed, keeping the installed copy"
      failures+=("Marketplace update")
    fi
    rm -rf "$tmp"
  else
    log "Marketplace $mp_installed is current"
  fi
fi
# make sure it's enabled (the official installer does the same)
# (read the ini directly: `spicetify -q config` prints nothing in quiet mode)
if ! ini_get AdditionalOptions custom_apps | grep -qw marketplace; then
  run spicetify -q config custom_apps marketplace; assets_changed=1
fi

# --- 3. Ziro theme ------------------------------------------------------------
theme_dir="$CONFIG_DIR/Themes/$THEME"
theme_state="$STATE_DIR/theme.$THEME.sha"
theme_installed="$(cat "$theme_state" 2>/dev/null || echo none)"
if [ "$online" = 1 ]; then
  theme_latest="$(curl -fsS -m 20 "https://api.github.com/repos/$THEMES_REPO/commits?path=$THEME&per_page=1" | jq -r '.[0].sha // empty')"
  if [ -n "$theme_latest" ] && { [ "$theme_latest" != "$theme_installed" ] || [ ! -s "$theme_dir/color.ini" ]; }; then
    log "Theme $THEME ${theme_installed:0:10} -> ${theme_latest:0:10}"
    tmp="$(mktemp -d)"
    ok=1
    for f in color.ini user.css LICENSE; do
      curl -fsSL -m 60 -o "$tmp/$f" "https://raw.githubusercontent.com/$THEMES_REPO/$theme_latest/$THEME/$f" || ok=0
    done
    grep -q "^\[$SCHEME_DARK\]" "$tmp/color.ini" 2>/dev/null && grep -q "^\[$SCHEME_LIGHT\]" "$tmp/color.ini" || ok=0
    if [ "$ok" = 1 ] && [ -s "$tmp/user.css" ]; then
      if [ "$DRY_RUN" = 0 ]; then
        mkdir -p "$theme_dir" && cp "$tmp"/* "$theme_dir/" && echo "$theme_latest" >"$theme_state"
      fi
      assets_changed=1; changes+=("$THEME theme")
    else
      log "Theme download/verify failed, keeping the installed copy"
      failures+=("$THEME theme update")
    fi
    rm -rf "$tmp"
  else
    log "Theme $THEME is current"
  fi
fi

# --- 4. Theme + colour scheme from the macOS appearance -----------------------
if defaults read -g AppleInterfaceStyle 2>/dev/null | grep -qi dark; then
  scheme="$SCHEME_DARK"
else
  scheme="$SCHEME_LIGHT"
fi
if [ "$(ini_get Setting current_theme)" != "$THEME" ] || [ "$(ini_get Setting color_scheme)" != "$scheme" ]; then
  run spicetify -q config current_theme "$THEME" color_scheme "$scheme"
  assets_changed=1
fi
log "Scheme: $scheme"

# --- 5. Decide what to apply --------------------------------------------------
spotify_app="$(ini_get Setting spotify_path)"; spotify_app="${spotify_app%/Contents/Resources}"
spotify_app="${spotify_app:-/Applications/Spotify.app}"
spotify_v="$(defaults read "$spotify_app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null)"
backup_v="$(ini_get Backup version)"
backup_with="$(ini_get Backup with)"
cli_now="$(spicetify -v 2>/dev/null)"
patched=0
grep -qi spicetify "$spotify_app/Contents/Resources/Apps/xpui/index.html" 2>/dev/null && patched=1

log "Spotify $spotify_v | backup $backup_v (made with $backup_with) | CLI $cli_now | patched=$patched"

action=""
if [ -z "$spotify_v" ]; then
  log "Spotify not found at $spotify_app"
elif [ -z "$backup_v" ] || { [ "$backup_v" != "$spotify_v" ] && [[ "$backup_v" != "$spotify_v".* ]]; }; then
  action="backup apply"        # Spotify updated itself: files are stock again
elif [ "$backup_with" != "$cli_now" ]; then
  action="restore backup apply"  # same Spotify, new CLI: rebuild the backup
elif [ "$patched" = 0 ]; then
  action="backup apply"
elif [ "$assets_changed" = 1 ]; then
  action="apply"
fi

if [ -n "$action" ]; then
  flags=(-q)
  # Patching always closes Spotify: restart it if it was running, and don't
  # launch it if it wasn't (-n)
  if ! pgrep -xq Spotify; then flags+=(-n); fi
  # shellcheck disable=SC2086
  if run spicetify "${flags[@]}" $action; then
    changes+=("applied ($action)")
    if [ "$DRY_RUN" = 0 ] && ! grep -qi spicetify "$spotify_app/Contents/Resources/Apps/xpui/index.html" 2>/dev/null; then
      failures+=("patch check after $action")
    fi
  else
    failures+=("spicetify $action")
  fi
else
  log "Nothing to apply"
fi

# --- summary ------------------------------------------------------------------
if [ ${#failures[@]} -gt 0 ]; then
  log "FAILED: ${failures[*]}"
  notify "Problem: ${failures[*]}. See ~/Library/Logs/spicetify-autoupdate.log"
  exit 1
elif [ ${#changes[@]} -gt 0 ]; then
  log "Done: ${changes[*]}"
  notify "Updated: ${changes[*]}"
else
  log "Done: everything current"
fi
