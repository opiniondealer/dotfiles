#!/usr/bin/env bash
# switch-layout.sh — auto switch config Hyprland & Waybar based on connected monitors

# Resolve the repo from this script's real location, so the layout still
# switches when the repo is cloned somewhere other than the owner's machine.
# The script is symlinked into ~/.config/hyprdots/scripts, so follow the link.
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
DOTFILES_DIR="$(cd "$(dirname "$SCRIPT_PATH")/../.." && pwd)"

# Symlink into ~/.config, which is what Hyprland and Waybar actually read.
# The repo copies stay untouched: they are the source of the two profiles.
HYPR_DIR="$HOME/.config/hypr"
WAYBAR_DIR="$HOME/.config/waybar"
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
    ln -sfn "$DOTFILES_DIR/hypr/monitors-triple.conf" "$HYPR_DIR/monitors.conf"
    ln -sfn "$DOTFILES_DIR/waybar/config-triple" "$WAYBAR_DIR/config"
else
    ln -sfn "$DOTFILES_DIR/hypr/monitors-single.conf" "$HYPR_DIR/monitors.conf"
    ln -sfn "$DOTFILES_DIR/waybar/config-single" "$WAYBAR_DIR/config"
fi

# Reload Hyprland config
hyprctl reload >/dev/null 2>&1

# Waybar: FULL restart, never SIGUSR2.
# waybar 0.12 leaks a stale layer surface on every SIGUSR2 reload (the old
# surface is never unmapped), so repeated hotplug events stack ghost bars on
# top of the real one. A hard kill + respawn is the only reliable path. The
# sleep gives the compositor time to destroy the old layer surfaces before the
# new instance maps its own, otherwise the bar can end up with no exclusive
# zone (windows overlapping it).
pkill -x waybar 2>/dev/null
for _ in $(seq 1 20); do
    pgrep -x waybar >/dev/null || break
    sleep 0.1
done
pkill -9 -x waybar 2>/dev/null
sleep 0.3
setsid waybar >/dev/null 2>&1 &
