#!/usr/bin/env bash
# audio-switch.sh — pilih output/input audio via wofi (PipeWire/wpctl)

clean_name() {
    # buang prefix panjang controller, rapihin
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
    choice=$(list_dev "$section" "$endmark" | wofi --dmenu --insensitive --prompt "" \
        --width 620 --height 420 \
        --mesg "$label  (* = sedang dipakai)" 2>/dev/null)
    [ -z "$choice" ] && return
    local id
    id=$(echo "$choice" | awk '{print $NF}')
    local name
    name=$(echo "$choice" | sed 's/^[* ] *//' | sed 's/ *[0-9]*$//')
    if wpctl set-default "$id" 2>/dev/null; then
        notify-send "Audio" "$label -> $name"
    else
        notify-send -u critical "Audio" "Gagal set $label ke $name"
    fi
}

main() {
    local mode
    mode=$(printf 'Output device   (speaker / headphone)\nInput device    (microphone)\n---\nOutput volume   (slider)\nInput volume    (slider)\n' | \
        wofi --dmenu --insensitive --prompt "" --width 460 --height 220 2>/dev/null)
    case "$mode" in
        Output\ device*) pick "Output" "Sinks" "Sources" "OUTPUT" ;;
        Input\ device*)  pick "Input" "Sources" "Streams" "INPUT" ;;
        Output\ volume*) exec "$(dirname "$0")/volume-slider.sh" sink ;;
        Input\ volume*)  exec "$(dirname "$0")/volume-slider.sh" source ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
