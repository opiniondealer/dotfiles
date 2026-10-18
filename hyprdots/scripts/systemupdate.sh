#!/usr/bin/env bash
# systemupdate.sh — adapted for Debian
# Original: roscaa-stack/dotfiles (Arch)

# Source variables
ScrDir=$(dirname "$(realpath "$0")")
[ -f "$ScrDir/globalcontrol.sh" ] && source "$ScrDir/globalcontrol.sh"

# Official repo updates (Debian)
ofc=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)

# Flatpak updates
if command -v flatpak >/dev/null 2>&1; then
    fpk=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
    fpk_disp="\n󰏓 Flatpak $fpk"
    fpk_exup="; flatpak update -y"
else
    fpk=0
    fpk_disp=""
    fpk_exup=""
fi

upd=$(( ofc + fpk ))

if [ "$upd" -eq 0 ]; then
    echo "{\"text\":\"$upd\", \"tooltip\":\" Packages are up to date\"}"
else
    echo "{\"text\":\"$upd\", \"tooltip\":\"󱓽 Official $ofc$fpk_disp\"}"
fi

# Trigger upgrade (klik kiri)
if [ "$1" == "up" ]; then
    kitty --title systemupdate sh -c "sudo apt update && sudo apt upgrade -y${fpk_exup}; echo; echo 'Done. Press Enter.'; read"
fi
