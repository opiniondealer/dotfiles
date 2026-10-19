#!/usr/bin/env bash
# shortcuts.sh — cheatsheet keybind Hyprland (sumber: ~/.config/hypr/hyprland.conf)

render() {
cat <<'LIST'
WORKSPACE
  Super + 1..6            Go to workspace N
  Super + Shift + 1..6    Move window to workspace N

WINDOW
  Super + W               Close window
  Super + F               Toggle fullscreen
  Super + Shift + Space   Toggle floating
  Super + V               Toggle split (dwindle)
  Super + H               Swap split
  Super + Left/Right/Up/Down    Focus window
  Super + Shift + Arrow         Move window (swap)
  Super + Ctrl + Arrow          Resize window
  Super + Backspace       Resize submap (arrows, Esc exits)
  Alt + Tab               Next window
  Alt + Shift + Tab       Previous window
  Alt + `                 Last focused window
  Super + mouse drag      Move window
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
  Print                   Select area -> save
  Ctrl + Print            Full screen -> clipboard
  Shift + Print           Active monitor -> save
  Super + Shift + S       Select area -> save + clipboard + notif

SYSTEM
  Super + L               Lock screen (hyprlock)
  Super + Shift + M       Display settings (nwg-displays)
  Super + Shift + C       Reload Hyprland
  Super + /               This cheatsheet
  Super + Shift + E       Exit Hyprland

LIST
}

# --print: emit the raw cheatsheet (used by shortcuts-panel.py)
if [ "${1:-}" = "--print" ]; then
    render
    exit 0
fi

# fallback: wofi dmenu
render | wofi --dmenu --insensitive --normal-window --prompt "" --no-actions --cache-file /dev/null
