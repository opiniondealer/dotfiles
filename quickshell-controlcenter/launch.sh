#!/usr/bin/env bash
# Launch Control Center shell without double HiDPI scaling.
# QT_SCALE_FACTOR=2 from hyprland.conf would make Quickshell render 2x on top of
# Wayland's own scale handling, so it is stripped here.
exec env -u QT_SCALE_FACTOR -u GDK_SCALE QT_AUTO_SCREEN_SCALE_FACTOR=0 \
  quickshell -p "$HOME/.config/quickshell-controlcenter" "$@"
