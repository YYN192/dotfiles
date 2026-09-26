#!/bin/bash

# Raycast Script Command metadata
# @raycast.schemaVersion 1
# @raycast.title Keybindings Cheatsheet
# @raycast.mode fullOutput
#
# Optional:
# @raycast.icon ⌨️
# @raycast.packageName Window Manager
# @raycast.description Auto-generated from ~/.config/skhd/skhdrc

# Renders the skhd keymap as a colored, sectioned cheatsheet.
# Auto-generated from the live config, so it never goes stale.

python3 - "$HOME/.config/skhd/skhdrc" <<'PY'
import sys, re

path = sys.argv[1]
try:
    raw = open(path).read()
except FileNotFoundError:
    print("skhdrc not found at", path); sys.exit(0)

# ANSI (truecolor) — Rosé Pine
def c(rgb): r,g,b=rgb; return f"\033[38;2;{r};{g};{b}m"
RST="\033[0m"; BOLD="\033[1m"; DIM="\033[2m"
TEXT=c((224,222,244)); MUTE=c((110,106,134)); SUB=c((144,140,170))
IRIS=c((196,167,231)); FOAM=c((156,207,216)); ROSE=c((235,188,186))
GOLD=c((246,193,119)); LOVE=c((235,111,146)); PINE=c((49,116,143))

# join backslash line-continuations
lines, buf = [], ""
for ln in raw.splitlines():
    s = ln.rstrip()
    if s.endswith("\\"):
        buf += s[:-1].strip() + " "
    else:
        lines.append((buf + s).strip()); buf = ""

def chord(mods_key):
    # mods_key like "shift + cmd + alt + ctrl - 0x2C"  -> pretty keys
    if " - " in mods_key:
        mods, key = mods_key.rsplit(" - ", 1)
    else:
        mods, key = "", mods_key
    parts = []
    if "shift" in mods: parts.append("⇧")
    # the rice's super = cmd+alt+ctrl (Caps Lock)
    parts.append("Caps")
    keymap = {"return":"⏎","space":"␣","0x2C":"/"}
    k = keymap.get(key.strip(), key.strip().upper())
    parts.append(k)
    return parts

def fmt_keys(parts):
    out=[]
    for p in parts:
        col = GOLD if p=="⇧" else (IRIS if p=="Caps" else ROSE)
        out.append(f"{col}{BOLD}{p}{RST}")
    return f"{MUTE}+{RST}".join(out)

def clean_cmd(cmd):
    cmd = cmd.strip()
    cmd = cmd.replace("yabai -m ", "")
    cmd = re.sub(r"\s*;\s*", "  ·  ", cmd)
    cmd = cmd.replace("--", "")
    return cmd

print()
print(f"  {IRIS}{BOLD}⌨  Window Manager — Keybindings{RST}")
print(f"  {MUTE}Super = hold Caps Lock   ·   tap Caps Lock alone = Esc   ·   generated from skhdrc{RST}")
print()

bind_re = re.compile(r"^(.*?)\s*:\s*(.+)$")
section = None
for ln in lines:
    if not ln: continue
    if ln.startswith("#"):
        title = ln.lstrip("#").strip().strip("─-—— ").strip()
        low = title.lower()
        noise = any(s in low for s in ("capslock","caps lock","super","->","=","karabiner")) or title.startswith("(")
        if title and not noise:
            section = title
            print(f"\n  {FOAM}{BOLD}{section.upper()}{RST}")
            print(f"  {DIM}{MUTE}{'─'*46}{RST}")
        continue
    m = bind_re.match(ln)
    if not m: continue
    mods_key, cmd = m.group(1), m.group(2)
    parts = chord(mods_key)
    keys = fmt_keys(parts)
    plain_len = len(" + ".join(parts))
    pad = " " * max(2, 22 - plain_len)
    print(f"   {keys}{pad}{SUB}{clean_cmd(cmd)}{RST}")
print()
PY
