#!/usr/bin/env bash
# volume-slider.sh — slider volume output/input (yad), live update
#
# Usage:
#   volume-slider.sh            # slider for the default output (sink)
#   volume-slider.sh input      # slider for the default input (source)
#   volume-slider.sh sink       # explicit alias for output
#
# Live: yad --print-partial emits on every drag step, so the volume
# follows the slider without pressing OK.

set -uo pipefail

KIND="${1:-sink}"

case "$KIND" in
    sink|output|out) TARGET="@DEFAULT_SINK@"; LABEL="Output Volume"; ICON="󰕾" ;;
    source|input|mic|in) TARGET="@DEFAULT_SOURCE@"; LABEL="Input Volume"; ICON="󰍬" ;;
    *) echo "usage: volume-slider.sh [sink|source]" >&2; exit 1 ;;
esac

# Current volume (0-100). pactl prints "Volume: front-left: 32768 /  50% ..."
cur=$(pactl get-${KIND}-volume "$TARGET" 2>/dev/null \
      | grep -oE '[0-9]+%' | head -1 | tr -d '%')
cur=${cur:-50}

# Muted state for the subtitle
muted=$(pactl get-${KIND}-mute "$TARGET" 2>/dev/null | awk '{print $2}')
sub="$LABEL"
[ "$muted" = "yes" ] && sub="$LABEL <span color='#ff6467'>(muted)</span>"

GTK_THEME=Serialchiller yad --scale \
    --title="$LABEL" \
    --text="<b>$ICON  $sub</b>" \
    --value="$cur" \
    --min-value=0 --max-value=100 --step=1 \
    --marks=25:50:75 \
    --print-partial \
    --width=400 --height=130 \
    --button="Tutup:0" \
    --skip-taskbar --center --on-top \
    2>/dev/null | while IFS= read -r val; do
        v=$(printf '%.0f' "$val" 2>/dev/null) || continue
        [ -z "$v" ] && continue
        [ "$v" -lt 0 ] && v=0
        [ "$v" -gt 100 ] && v=100
        pactl set-${KIND}-volume "$TARGET" "${v}%" >/dev/null 2>&1
        # dragging above 0 should un-mute
        if [ "$v" -gt 0 ]; then
            pactl set-${KIND}-mute "$TARGET" 0 >/dev/null 2>&1
        fi
    done
