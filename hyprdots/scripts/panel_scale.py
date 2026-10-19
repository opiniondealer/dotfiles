#!/usr/bin/env python3
"""panel-scale.py — shared font/geometry scaling for the GTK4 waybar panels.

All panels size their fonts against a 1080p reference and scale with the
monitor height, so they look the same on a 1080p screen and on a HiDPI
laptop panel. Import it:

    from panel_scale import monitor_size, font_scale, px

The module is import-safe: it does not run GTK code at import time.
"""

import json
import os
import pathlib
import signal
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


# --- panel toggle ----------------------------------------------------------
# Panels are mutually exclusive through a shared state file. On top of that,
# clicking the waybar button again should toggle the panel closed. Each panel
# runs its own process, so a second launch cannot see the first one; instead
# every panel goes through this helper: `toggle_panel(name)` exits the caller
# acting as a "close" if the panel `name` is already running, otherwise it
# records itself and the caller keeps going.
STATE_DIR = "/tmp/opencode-serialchiller-panels"


def _state_file(name: str):
    return pathlib.Path(STATE_DIR) / f"{name}.pid"


def another_panel_running(name: str):
    """Close any *other* panel that is currently open. Returns nothing."""
    for f in pathlib.Path(STATE_DIR).glob("*.pid"):
        other = f.stem
        if other == name:
            continue
        _close_pid_file(f)


def panel_is_open(name: str) -> bool:
    f = _state_file(name)
    if not f.exists():
        return False
    try:
        pid = int(f.read_text().strip())
        os.kill(pid, 0)  # 0 == probe, raises if gone
        return True
    except (ValueError, ProcessLookupError, PermissionError):
        try:
            f.unlink()
        except Exception:
            pass
        return False


def _close_pid_file(f):
    try:
        pid = int(f.read_text().strip())
        os.kill(pid, signal.SIGTERM)
    except Exception:
        pass
    try:
        f.unlink()
    except Exception:
        pass


def close_panel(name: str) -> None:
    f = _state_file(name)
    if f.exists():
        _close_pid_file(f)


def register_panel(name: str) -> None:
    """Record this process as the owner of panel `name` and close siblings."""
    pathlib.Path(STATE_DIR).mkdir(parents=True, exist_ok=True)
    _state_file(name).write_text(str(os.getpid()))
    another_panel_running(name)


def release_panel(name: str) -> None:
    f = _state_file(name)
    try:
        if f.exists() and f.read_text().strip() == str(os.getpid()):
            f.unlink()
    except Exception:
        pass


def toggle_panel(name: str) -> bool:
    """Return True if the caller should exit (= the panel was open, so this
    invocation just closes it). Return False when the caller should open.

    Typical use at the top of main():

        if toggle_panel("calendar"):
            return 0
    """
    if panel_is_open(name):
        close_panel(name)
        return True
    return False