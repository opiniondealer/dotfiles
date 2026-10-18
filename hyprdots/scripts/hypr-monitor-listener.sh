#!/usr/bin/env bash
# hypr-monitor-listener.sh — listen Hyprland events, trigger auto-workspace.sh

SCRIPT_DIR="$(dirname "$(realpath "$0")")"
SIG="${HYPRLAND_INSTANCE_SIGNATURE:-$(ls -t /run/user/$(id -u)/hypr/ 2>/dev/null | head -1)}"
export HYPRLAND_INSTANCE_SIGNATURE="$SIG"
SOCK="/run/user/$(id -u)/hypr/${SIG}/.socket2.sock"

[ -S "$SOCK" ] || { echo "socket2 not found: $SOCK"; exit 1; }

# jalanin sekali di awal (sync state)
"$SCRIPT_DIR/auto-workspace.sh"

# listen event streaming
while IFS= read -r line; do
    case "$line" in
        monitoradded*|monitorremoved*)
            "$SCRIPT_DIR/auto-workspace.sh"
            ;;
    esac
done < <(socat -U - "UNIX-CONNECT:$SOCK" 2>/dev/null || nc -U "$SOCK")
