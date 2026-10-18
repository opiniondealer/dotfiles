#!/usr/bin/env bash
# auto-workspace.sh — show workspaces on bar ONLY when external monitors connected
# Logic: 1 monitor (laptop only)  -> show workspaces
#        2+ monitors (external)   -> hide workspaces

CONF="$HOME/.config/waybar/config"
HYPRSIG="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)}"
export HYPRLAND_INSTANCE_SIGNATURE="$HYPRSIG"

count=$(hyprctl -j monitors 2>/dev/null | jq 'length' 2>/dev/null || echo 1)

# simpen mode saat ini biar ga reload terus-terusan
STATE_FILE="/tmp/waybar-ws-mode"
prev=$(cat "$STATE_FILE" 2>/dev/null || echo "")

# 1 monitor (laptop only) -> show workspaces
# 2+ monitors (ada eksternal) -> hide workspaces
if [ "$count" -ge 2 ]; then
    newmode="no-ws"
else
    newmode="with-ws"
fi

[ "$prev" = "$newmode" ] && exit 0
echo "$newmode" > "$STATE_FILE"

# patch modules-left di config (in-place, minimal)
python3 - "$CONF" "$newmode" <<'PY'
import sys, re
conf, mode = sys.argv[1], sys.argv[2]
s = open(conf).read()

if mode == "with-ws":
    new_left = '''    "modules-left": [
        "custom/l_end", "hyprland/workspaces", "custom/r_end"
    ],'''
else:
    new_left = '''    "modules-left": [],'''

s = re.sub(r'    "modules-left": \[.*?\],', new_left, s, count=1, flags=re.S)
open(conf, "w").write(s)
PY

# reload waybar
pkill waybar 2>/dev/null
sleep 0.5
setsid waybar >/dev/null 2>&1 &
