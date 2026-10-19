#!/usr/bin/env bash
# shortcuts.sh — cheatsheet keybind Hyprland (sumber: ~/.config/hypr/hyprland.conf)

render() {
cat <<'LIST'
WORKSPACE
  Super + 1..6            Ke workspace N
  Super + Shift + 1..6    Pindah window ke workspace N

WINDOW
  Super + W               Close window
  Super + F               Toggle fullscreen
  Super + Shift + Space   Toggle floating
  Super + V               Toggle split (dwindle)
  Super + H               Swap split
  Super + Left/Right/Up/Down    Focus window
  Super + Shift + Arrow         Pindah window (swap)
  Super + Ctrl + Arrow          Resize window
  Super + Backspace       Submap resize (arrow, Esc keluar)
  Alt + Tab               Window berikutnya
  Alt + Shift + Tab       Window sebelumnya
  Alt + `                 Window terakhir fokus
  Super + mouse drag      Pindah window
  Super + mouse right-drag  Resize window

APPS
  Super + Return          Terminal (kitty)
  Super + Alt + Return    Terminal + tmux (session: Work)
  Ctrl + Alt + T          Terminal
  Super + Space           App launcher (wofi drun)
  Super + Shift + B       Browser
  Super + Shift + Return  Browser
  Super + Shift + Alt + B Browser incognito
  Super + Shift + F       File manager
  Super + Shift + N       Editor di terminal
  Super + Shift + T       btop
  Super + Shift + D       lazydocker

SCREENSHOT
  Print                   Pilih area -> simpan
  Ctrl + Print            Full screen -> clipboard
  Shift + Print           Monitor aktif -> simpan
  Super + Shift + S       Pilih area -> simpan + clipboard + notif

SYSTEM
  Super + L               Lock screen (hyprlock)
  Super + Shift + M       Display settings (nwg-displays)
  Super + Shift + C       Reload Hyprland
  Super + /               Cheatsheet ini
  Super + Shift + E       Exit Hyprland

LIST
}

# wofi dmenu: scrollable list
render | wofi --dmenu --insensitive --normal-window --prompt "" --no-actions --cache-file /dev/null
