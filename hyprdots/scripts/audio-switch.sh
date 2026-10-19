#!/usr/bin/env bash
# audio-switch.sh — pick audio output/input via wofi (PipeWire/wpctl)

# Prefer a fixed monitor for popups (the right-hand screen), so they don't
# steal the screen you're working on. Falls back to the focused monitor.
wofi_mon() {
    local want="${WOFI_MONITOR:-DP-2}"
    if hyprctl monitors -j 2>/dev/null | jq -e --arg n "$want" '.[] | select(.name==$n)' >/dev/null 2>&1; then
        echo "--monitor $want"
    fi
}

clean_name() {
    # strip the long controller prefix, tidy up
    sed -e 's/Alder Lake PCH-P High Definition Audio Controller //' \
        -e 's/ High Definition Audio Controller//' \
        -e 's/ Analog Stereo//' \
        -e 's/Digital Microphone/Mic (digital)/' \
        -e 's/Stereo Microphone/Mic (analog)/' \
        -e 's/ Headphones/Headphone/' \
        -e 's/HDMI \/ DisplayPort \([0-9]\) Output/HDMI\/DP \1/' \
        -e 's/ *\[vol: [0-9.]*\]//' \
        -e 's/ *$//'
}

list_dev() {
    # $1 = Sinks|Sources , $2 = end marker
    wpctl status | awk "/$1:/,/$2:/" | grep -E '^\s*[│├└─]*\s*\*?\s*[0-9]+\.' | grep -v 'V4L2' | while IFS= read -r line; do
        cur=" "
        echo "$line" | grep -q '\*' && cur="*"
        id=$(echo "$line" | grep -oE '[0-9]+\.' | head -1 | tr -d '.')
        name=$(echo "$line" | sed 's/^[^0-9]*//' | sed 's/^[0-9]*\. *//' | clean_name)
        printf '%s %-46s %s\n' "$cur" "$name" "$id"
    done
}

pick() {
    local kind="$1" section="$2" endmark="$3" label="$4"
    local choice
    # wofi has no --mesg (rofi-only). Put the label in the prompt instead.
    choice=$(list_dev "$section" "$endmark" | wofi --dmenu --insensitive --normal-window \
        --prompt "$label  (* = in use)" \
        --width 620 --height 420 $(wofi_mon) 2>/dev/null)
    [ -z "$choice" ] && return
    local id
    id=$(echo "$choice" | awk '{print $NF}')
    local name
    name=$(echo "$choice" | sed 's/^[* ] *//' | sed 's/ *[0-9]*$//')
    if wpctl set-default "$id" 2>/dev/null; then
        notify-send "Audio" "$label -> $name"
    else
        notify-send -u critical "Audio" "Failed to set $label to $name"
    fi
}

main() {
    # Direct mode: called from the audio panel's gear button.
    #   audio-switch.sh sink     -> output device list only
    #   audio-switch.sh source   -> input device list only
    case "${1:-}" in
        sink|output|out)   pick "Output" "Sinks" "Sources" "OUTPUT"; return ;;
        source|input|mic)  pick "Input" "Sources" "Streams" "INPUT"; return ;;
    esac

    # No argument: show the full menu (waybar right-click).
    local mode
    mode=$(printf 'Output device   (speaker / headphone)\nInput device    (microphone)\n---\nOutput volume   (slider)\nInput volume    (slider)\n' | \
        wofi --dmenu --insensitive --normal-window --prompt "" --width 460 --height 220 $(wofi_mon) 2>/dev/null)
    case "$mode" in
        Output\ device*) pick "Output" "Sinks" "Sources" "OUTPUT" ;;
        Input\ device*)  pick "Input" "Sources" "Streams" "INPUT" ;;
        Output\ volume*) exec "$(dirname "$0")/volume-slider.sh" sink ;;
        Input\ volume*)  exec "$(dirname "$0")/volume-slider.sh" source ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
