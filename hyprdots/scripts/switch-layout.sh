#!/usr/bin/env bash
# switch-layout.sh — auto switch config Hyprland & Waybar based on connected monitors

HYPR_DIR="$HOME/development/dotfiles/hypr"
WAYBAR_DIR="$HOME/development/dotfiles/waybar"
STATE_FILE="/tmp/hypr-layout-mode"

HYPRSIG="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)}"
export HYPRLAND_INSTANCE_SIGNATURE="$HYPRSIG"

# Hitung monitor aktif
count=$(hyprctl -j monitors 2>/dev/null | jq 'length' 2>/dev/null || echo 1)

if [ "$count" -ge 2 ]; then
    target="triple"
else
    target="single"
fi

prev=$(cat "$STATE_FILE" 2>/dev/null || echo "")
if [ "$prev" = "$target" ] && [ "$1" != "--force" ]; then
    exit 0
fi

echo "$target" > "$STATE_FILE"

if [ "$target" = "triple" ]; then
    ln -sf "monitors-triple.conf" "$HYPR_DIR/monitors.conf"
    ln -sf "config-triple" "$WAYBAR_DIR/config"
else
    ln -sf "monitors-single.conf" "$HYPR_DIR/monitors.conf"
    ln -sf "config-single" "$WAYBAR_DIR/config"
fi

# Reload Hyprland config
hyprctl reload >/dev/null 2>&1

# Reload / restart Waybar
pkill -SIGUSR2 waybar 2>/dev/null || {
    pkill waybar 2>/dev/null
    sleep 0.5
    setsid waybar >/dev/null 2>&1 &
}
