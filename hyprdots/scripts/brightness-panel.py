#!/usr/bin/env python3
"""brightness-panel.py — brightness slider matching the audio panel.

Layout: title, icon + device name, slider, live percentage.
Applies instantly while dragging.

Usage: brightness-panel.py
"""

import subprocess
import os
import pathlib
import signal
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

SCRIPT_DIR = __file__.rsplit("/", 1)[0] if "/" in __file__ else "."
sys.path.insert(0, SCRIPT_DIR)
from panel_scale import (
    font_scale, make_px, monitor_size, icon_label, NF_CSS,
    toggle_panel, register_panel, release_panel,
)  # noqa: E402

# Palette (Minimal Neutral)
BG = "#171717"
FG = "#fafafa"
MUTED = "#a1a1a1"
ACCENT = "#91c5ff"
WARN = "#e0c07b"


def build_css(scale: float):
    px = make_px(scale)
    return f"""
window {{
    background-color: {BG};
}}
.panel {{
    background-color: {BG};
    border: 1px solid #262626;
    border-radius: 14px;
    padding: {px(18)}px {px(20)}px {px(16)}px {px(20)}px;
}}
label {{
    color: {FG};
}}
.brand {{
    color: {MUTED};
    font-size: {px(13)}px;
    letter-spacing: 2px;
}}
.device-name {{
    color: {FG};
    font-size: {px(16)}px;
    font-weight: bold;
}}
.device-sub {{
    color: {MUTED};
    font-size: {px(13)}px;
}}
.value {{
    color: {ACCENT};
    font-size: {px(15)}px;
    font-weight: bold;
}}
.low-value {{
    color: {WARN};
    font-size: {px(15)}px;
    font-weight: bold;
}}
scale trough {{
    min-height: {px(5)}px;
    border-radius: 3px;
    background-color: #262626;
}}
scale highlight {{
    background-color: {ACCENT};
    border-radius: 3px;
}}
scale slider {{
    min-width: {px(14)}px;
    min-height: {px(14)}px;
    background-color: {FG};
    border-radius: 50%;
}}
button {{
    background-image: none;
    box-shadow: none;
    text-shadow: none;
    border: none;
    outline: none;
    padding: 0;
    margin: 0;
    min-height: 0;
    min-width: 0;
}}
.btn {{
    background-color: #1f1f1f;
    border: 1px solid #2e2e2e;
    border-radius: 7px;
    padding: {px(4)}px 0;
    min-width: {px(62)}px;
    min-height: {px(22)}px;
    transition: background-color 120ms ease, border-color 120ms ease;
}}
.btn label {{
    color: {MUTED};
    font-size: {px(16)}px;
    font-weight: normal;
    letter-spacing: 0;
}}
.btn:hover {{
    background-color: #262626;
    border-color: #3a3a3a;
}}
.btn:hover label {{
    color: {FG};
}}
.btn:active {{
    background-color: #303030;
}}
""" + NF_CSS


def run(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        return out.stdout.strip()
    except Exception:
        return ""


def get_device() -> str:
    """Return the first backlight device name, or '' if none."""
    out = run(["brightnessctl", "--list"])
    for line in out.splitlines():
        if "backlight" in line and "'" in line:
            return line.split("'")[1]
    return ""


def get_pct(dev: str) -> int:
    out = run(["brightnessctl", "-d", dev, "info"])
    for tok in out.split():
        if tok.startswith("(") and tok.endswith("%)"):
            try:
                return int(tok.strip("()%"))
            except ValueError:
                pass
    for tok in out.split():
        if tok.endswith("%") and tok.strip("%").isdigit():
            return int(tok.strip("%"))
    return 50


def set_pct(dev: str, value: int) -> None:
    value = max(1, min(100, value))
    run(["brightnessctl", "-d", dev, "set", f"{value}%"])


def icon_for(value: int, name: str) -> str:
    if "kbd" in name or "keyboard" in name:
        return "󰌵"
    if value < 25:
        return "\U000f00dd"   # low: half sun
    if value < 60:
        return "\U000f00de"   # mid: full sun
    return "\U000f05a8"       # high: sun with rays



PANEL_STATE = "/tmp/opencode-serialchiller-panel.pid"


def claim_panel(me: str) -> None:
    """Close any other panel before showing this one.

    Panels are mutually exclusive: opening the audio panel dismisses the
    wifi panel and vice versa. State lives in PANEL_STATE as
    "<name> <pid>"; a stale pid is simply ignored.
    """
    try:
        path = pathlib.Path(PANEL_STATE)
        if path.exists():
            name, _, pid = path.read_text().strip().partition(" ")
            if name != me and pid.isdigit():
                try:
                    os.kill(int(pid), signal.SIGTERM)
                except (ProcessLookupError, PermissionError):
                    pass
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"{me} {os.getpid()}")
    except Exception:
        pass


class BrightnessPanel(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.serialchiller.brightnesspanel")
        self.dev = get_device()

    def do_activate(self):
        # Single instance: if a window is already open, just focus it.
        existing = self.get_active_window() or (self.get_windows() or [None])[0]
        if existing is not None:
            existing.present()
            return

        if not self.dev:
            run(["notify-send", "-u", "critical", "Brightness", "No backlight device found"])
            self.quit()
            return

        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("brightness-panel")

        # Scale fonts and panel width with the focused monitor.
        _sw, _sh = monitor_size()
        scale = font_scale(_sh)

        provider = Gtk.CssProvider()
        provider.load_from_string(build_css(scale))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        panel.set_css_classes(["panel"])
        panel.set_size_request(int(320 * scale), -1)

        brand = Gtk.Label(label="D I S P L A Y", xalign=0)
        brand.set_css_classes(["brand"])
        panel.append(brand)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        self.icon_lbl = icon_label("", ["device-name"], width_chars=2)
        header.append(self.icon_lbl)

        textbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        textbox.set_hexpand(True)
        name_lbl = Gtk.Label(label="Backlight", xalign=0)
        name_lbl.set_css_classes(["device-name"])
        textbox.append(name_lbl)

        sub_lbl = Gtk.Label(label=self.dev, xalign=0)
        sub_lbl.set_css_classes(["device-sub"])
        sub_lbl.set_ellipsize(3)
        sub_lbl.set_max_width_chars(30)
        textbox.append(sub_lbl)
        header.append(textbox)

        self.reset_btn = Gtk.Button(label="\U000f05a8")
        self.reset_btn.set_css_classes(["btn", "nf-btn"])
        self.reset_btn.set_tooltip_text("Reset to 100%")
        self.reset_btn.connect("clicked", self._on_reset)
        header.append(self.reset_btn)

        panel.append(header)

        slider_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 1, 100, 1)
        self.scale.set_draw_value(False)
        self.scale.set_hexpand(True)
        self.scale.set_increments(1, 5)
        self.scale.connect("value-changed", self._on_scale)
        slider_row.append(self.scale)

        self.value_lbl = Gtk.Label(label="0%")
        self.value_lbl.set_css_classes(["value"])
        self.value_lbl.set_size_request(42, -1)
        self.value_lbl.set_xalign(1)
        slider_row.append(self.value_lbl)
        panel.append(slider_row)

        win.set_child(panel)

        self._loading = True
        val = get_pct(self.dev)
        self.scale.set_value(val)
        self.value_lbl.set_text(f"{val}%")
        self._apply_style(val)
        self._loading = False

        GLib.timeout_add(1000, self._tick)

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        register_panel("brightness")
        win.present()

    def _apply_style(self, val: int) -> None:
        self.icon_lbl.set_text(icon_for(val, self.dev))
        self.value_lbl.set_css_classes(["low-value"] if val <= 15 else ["value"])

    def _on_scale(self, scale):
        if self._loading:
            return
        val = int(round(scale.get_value()))
        set_pct(self.dev, val)
        self.value_lbl.set_text(f"{val}%")
        self._apply_style(val)

    def _on_reset(self, _btn):
        set_pct(self.dev, 100)
        self._loading = True
        self.scale.set_value(100)
        self.value_lbl.set_text("100%")
        self._apply_style(100)
        self._loading = False

    def _tick(self):
        """Follow external changes (brightness keys, other apps)."""
        try:
            val = get_pct(self.dev)
            if abs(int(self.scale.get_value()) - val) > 0:
                self._loading = True
                self.scale.set_value(val)
                self.value_lbl.set_text(f"{val}%")
                self._apply_style(val)
                self._loading = False
        except Exception:
            pass
        return True

    def _on_key(self, _c, keyval, _code, _state):
        if keyval == Gdk.KEY_Escape:
            for w in self.get_windows():
                w.close()
            return True
        return False


def main() -> int:
    if toggle_panel("brightness"):
        return 0
    try:
        return BrightnessPanel().run(sys.argv)
    finally:
        release_panel("brightness")


if __name__ == "__main__":
    sys.exit(main())
