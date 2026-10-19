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


# --- icons -----------------------------------------------------------------
# Nerd Font glyphs must be drawn with a font that actually has them. GTK's
# default monospace is DejaVu Sans Mono, which lacks every private-use glyph,
# so icons fall back to a random font and end up glued to the text with a
# bogus advance width. Pinning the icon font fixes the alignment everywhere.
NF_FONT = "JetBrainsMono Nerd Font"

# CSS every panel should include so Nerd Font glyphs and text both render in
# the same monospace face. Appending this to a panel stylesheet is enough:
# it sets the font on the window (all descendants inherit) and fixes the two
# icon-label shapes. Scale-independent.
NF_CSS = f"""
window, .nf, .nf-btn label {{
    font-family: "{NF_FONT}";
}}
.nf, .nf-btn label {{
    font-weight: normal;
}}
"""


def icon_label(icon: str, classes: list[str], width_chars: int = 2):
    """A fixed-width Nerd Font icon label.

    width_chars reserves a stable horizontal slot (in characters, so it scales
    with the font) so the text that follows always starts at the same x. The
    glyph is centered inside that slot. Import Gtk before calling this.
    """
    from gi.repository import Gtk

    lbl = Gtk.Label(label=icon)
    lbl.set_css_classes([*classes, "nf"])
    lbl.set_width_chars(width_chars)
    lbl.set_xalign(0.5)
    lbl.set_halign(Gtk.Align.CENTER)
    lbl.set_valign(Gtk.Align.CENTER)
    return lbl