#!/usr/bin/env bash
# wifi-menu.sh — network menu simpel buat waybar (wofi)
# Click the network icon -> list wifi, pick one -> connect

TERM_CMD="kitty -e"
SCRIPT_DIR="$(dirname "$(realpath "$0")")"

list_wifi() {
    # format: SSID|signal|status
    nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list --rescan yes 2>/dev/null \
        | awk -F: '{
            inuse=$1; ssid=$2; sig=$3;
            if (ssid=="") next;
            mark = (inuse=="*") ? " [connected]" : "";
            printf "%-4s %-32s%s\n", sig"%", ssid, mark
        }' | sort -rn
}

# tampilkan menu pake wofi dmenu
choice=$(list_wifi | wofi --dmenu --insensitive --prompt "WiFi  (signal %)" --width 520 --height 420 2>/dev/null)

[ -z "$choice" ] && exit 0

# ambil SSID (buang signal% di depan + marker)
ssid=$(echo "$choice" | sed -E 's/^[0-9]+%\s+//; s/\s*\[connected\]$//' | xargs)

# already connected?
if nmcli -t -f NAME connection show --active 2>/dev/null | grep -qx "$ssid"; then
    action=$(printf 'Disconnect\nCancel\n' | wofi --dmenu --insensitive --prompt "" --width 320 --height 160 2>/dev/null)
    [ "$action" = "Disconnect" ] && nmcli connection down "$ssid" && notify-send "WiFi" "Disconnected from $ssid"
    exit 0
fi

# connect (prompts for password if not saved)
if nmcli -t -f NAME connection show 2>/dev/null | grep -qx "$ssid"; then
    # saved profile -> connect directly
    nmcli connection up "$ssid" >/dev/null 2>&1 \
        && notify-send "WiFi" "Connected to $ssid" \
        || notify-send -u critical "WiFi" "Failed to connect to $ssid"
else
    # new profile -> ask for password
    pass=$(wofi --dmenu --password --insensitive --prompt "" --width 400 --height 120 2>/dev/null)
    [ -z "$pass" ] && exit 0
    nmcli dev wifi connect "$ssid" password "$pass" >/dev/null 2>&1 \
        && notify-send "WiFi" "Connected to $ssid" \
        || notify-send -u critical "WiFi" "Connection failed - check password"
fi
