#!/usr/bin/env bash
# ws.sh - per-monitor named workspaces
#
# Monitor -> prefix:
#   eDP-1     -> A  (laptop)
#   HDMI-A-1  -> B  (eksternal kiri)
#   DP-1/DP-2 -> C  (eksternal kanan; the port name changes with the dock)
#
# Usage:
#   ws.sh switch <1-6>    switch to <PREFIX><n> on the focused monitor
#   ws.sh move   <1-6>    move active window to <PREFIX><n> (follows it)
#   ws.sh moveto <1-6>    move active window silently (stay on current ws)
#   ws.sh cycle  <+1|-1>  cycle workspaces within the focused monitor
#
# Unknown monitor: prefix is derived from its name (HDMI* -> B, DP* -> C),
# never a blind "A", so a hotplug cannot redirect keys to the laptop.

set -euo pipefail

MODE="${1:-}"
ARG="${2:-}"

declare -A PREFIX=(
    [eDP-1]=A
    [HDMI-A-1]=B
    [DP-1]=C
    [DP-2]=C
)

FOCUSED=$(hyprctl monitors -j | jq -r '.[] | select(.focused==true) | .name')
P="${PREFIX[$FOCUSED]:-}"

# An unknown monitor used to fall back to "A", which silently switched the
# laptop's workspaces while the cursor was on an external screen. Derive a
# stable prefix from the monitor name instead, so each screen keeps its own set.
if [ -z "$P" ]; then
    case "$FOCUSED" in
        eDP*|*EDP*) P=A ;;
        HDMI*)      P=B ;;
        DP*)        P=C ;;
        *)          P=$(printf '%s' "$FOCUSED" | tr -cd '[:alnum:]' | tail -c 1 | tr '[:lower:]' '[:upper:]') ;;
    esac
    [ -n "$P" ] || P=A
fi

case "$MODE" in
    switch)
        hyprctl dispatch workspace "name:${P}${ARG}" >/dev/null
        ;;
    move)
        hyprctl dispatch movetoworkspace "name:${P}${ARG}" >/dev/null
        ;;
    moveto)
        hyprctl dispatch movetoworkspacesilent "name:${P}${ARG}" >/dev/null
        ;;
    cycle)
        case "$ARG" in
            +1) hyprctl dispatch focusworkspaceoncurrentmonitor next >/dev/null ;;
            -1) hyprctl dispatch focusworkspaceoncurrentmonitor previous >/dev/null ;;
            *)  echo "ws.sh: cycle expects +1 or -1" >&2; exit 1 ;;
        esac
        ;;
    current)
        # print the prefix for the focused monitor (debug helper)
        echo "${P}"
        ;;
    *)
        echo "usage: ws.sh {switch|move|moveto} <1-6> | cycle <+1|-1> | current" >&2
        exit 1
        ;;
esac
