#!/usr/bin/env bash
# wallpaper.sh — restart hyprpaper dengan aman (detached dari shell)
# pemakaian: wallpaper.sh [path-gambar]
#   tanpa argumen -> reload config yang sekarang
#   dengan argumen -> ganti path di config lalu reload

CONF="$HOME/.config/hypr/hyprpaper.conf"

if [ -n "$1" ]; then
    IMG="$1"
    # resolve ke absolute path
    case "$IMG" in
        /*) : ;;
        "~"*) IMG="${HOME}${IMG#\~}" ;;
        *) IMG="$(realpath "$IMG" 2>/dev/null || echo "$IMG")" ;;
    esac

    if [ ! -f "$IMG" ]; then
        notify-send -u critical "Wallpaper" "File tidak ditemukan: $IMG"
        exit 1
    fi

    # update path di config
    sed -i "s|^\( *path *=\).*|\1      $IMG|" "$CONF"
fi

# kill yang lama
pkill -x hyprpaper 2>/dev/null
sleep 0.4

# start baru, detached (kebal SIGHUP kalau terminal ditutup)
setsid hyprpaper >/tmp/hyprpaper.log 2>&1 < /dev/null &

sleep 1
if pgrep -x hyprpaper >/dev/null; then
    notify-send -t 2000 "Wallpaper" "Aktif: $(basename "$(grep -oP '^\s*path\s*=\s*\K.*' "$CONF" | head -1)")"
else
    notify-send -u critical "Wallpaper" "hyprpaper gagal start"
    exit 1
fi
