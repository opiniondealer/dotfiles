#!/usr/bin/env bash
# brightness-slider.sh — slider brightness laptop (yad), live update

DEV=$(brightnessctl --list 2>/dev/null | awk -F"'" '/backlight/{print $2; exit}')
[ -z "$DEV" ] && { notify-send -u critical "Brightness" "No backlight device found"; exit 1; }

cur=$(brightnessctl -d "$DEV" info 2>/dev/null | grep -oE '\([0-9]+%\)' | tr -d '()%')
cur=${cur:-50}

# yad --scale --print-partial: tiap perubahan nilai dicetak -> apply live
GTK_THEME=Serialchiller yad --scale \
    --title="Brightness" \
    --text="<b>Brightness</b>" \
    --value="$cur" \
    --min-value=1 --max-value=100 --step=1 \
    --marks=25:50:75 \
    --print-partial \
    --width=400 --height=130 \
    --button="Close:0" \
    --skip-taskbar --center --on-top \
    2>/dev/null | while IFS= read -r val; do
        v=$(printf '%.0f' "$val" 2>/dev/null) || continue
        [ -z "$v" ] && continue
        [ "$v" -lt 1 ] && v=1
        [ "$v" -gt 100 ] && v=100
        brightnessctl -d "$DEV" set "${v}%" >/dev/null 2>&1
    done
