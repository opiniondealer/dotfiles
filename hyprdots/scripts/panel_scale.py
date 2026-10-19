#!/usr/bin/env python3
"""panel-scale.py — shared font/geometry scaling for the GTK4 waybar panels.

All panels size their fonts against a 1080p reference and scale with the
monitor height, so they look the same on a 1080p screen and on a HiDPI
laptop panel. Import it:

    from panel_scale import monitor_size, font_scale, px

The module is import-safe: it does not run GTK code at import time.
"""

import json
import subprocess

PX_REF_H = 1080.0     # reference monitor height the sizes are designed for
SCALE_MIN = 0.85      # clamp so tiny/large panels stay usable
SCALE_MAX = 1.9


def monitor_size(fallback=(1920, 1080)):
    """(width, height) of the focused Hyprland monitor.

    Panels open on the focused monitor, so that is the right reference. Falls
    back to the given size when Hyprland is not reachable.
    """
    try:
        out = subprocess.run(
            ["hyprctl", "monitors", "-j"],
            capture_output=True, text=True, timeout=3,
        )
        if out.returncode == 0:
            mons = json.loads(out.stdout)
            chosen = next((m for m in mons if m.get("focused")), None) or (mons[0] if mons else None)
            if chosen:
                return int(chosen["width"]), int(chosen["height"])
    except Exception:
        pass
    return fallback


def font_scale(monitor_height: int) -> float:
    return max(SCALE_MIN, min(SCALE_MAX, monitor_height / PX_REF_H))


def make_px(scale: float):
    """Return a px(ref) helper: ref is a size in px at the 1080p reference."""
    def px(ref):
        return max(9, int(round(ref * scale)))
    return px