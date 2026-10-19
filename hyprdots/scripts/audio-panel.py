#!/usr/bin/env python3
"""audio-panel.py — one-window audio control for waybar.

Shows, in a single compact window:
  - Output device name + volume slider (live)
  - Input  device name + volume slider (live)

Both sliders apply immediately via pactl while dragging.
Clicking the device name opens the existing wofi device picker.

Usage: audio-panel.py
"""

import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

SCRIPT_DIR = __file__.rsplit("/", 1)[0] if "/" in __file__ else "."
AUDIO_SWITCH = f"{SCRIPT_DIR}/audio-switch.sh"

# Palette (Minimal Neutral)
BG = "#171717"
CARD = "#0e0e0e"
FG = "#fafafa"
MUTED = "#a1a1a1"
ACCENT = "#91c5ff"
DESTRUCTIVE = "#ff6467"

CSS = f"""
window {{
    background-color: {BG};
}}
.panel {{
    background-color: {BG};
    border: 1px solid #262626;
    border-radius: 14px;
    padding: 18px 20px 16px 20px;
}}
label {{
    color: {FG};
}}
.brand {{
    color: {MUTED};
    font-size: 10px;
    letter-spacing: 2px;
}}
.device-name {{
    color: {FG};
    font-size: 13px;
    font-weight: bold;
}}
.device-sub {{
    color: {MUTED};
    font-size: 10px;
}}
.value {{
    color: {ACCENT};
    font-size: 12px;
    font-weight: bold;
}}
.muted-value {{
    color: {DESTRUCTIVE};
    font-size: 12px;
    font-weight: bold;
}}
scale trough {{
    min-height: 5px;
    border-radius: 3px;
    background-color: #262626;
}}
scale highlight {{
    background-color: {ACCENT};
    border-radius: 3px;
}}
scale slider {{
    min-width: 14px;
    min-height: 14px;
    background-color: {FG};
    border-radius: 50%;
    margin: -5px 0;
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
    padding: 4px 0;
    min-width: 62px;
    min-height: 22px;
    transition: background-color 120ms ease, border-color 120ms ease;
}}
.btn label {{
    color: {MUTED};
    font-size: 13px;
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
.btn.on {{
    background-color: rgba(255, 100, 103, 0.15);
    border-color: {DESTRUCTIVE};
}}
.btn.on label {{
    color: {DESTRUCTIVE};
}}
.btn.on:hover {{
    background-color: rgba(255, 100, 103, 0.25);
}}
.btn.on:hover label {{
    color: {DESTRUCTIVE};
}}
separator {{
    background-color: #262626;
    min-height: 1px;
    margin: 12px 0 12px 0;
}}
"""


def run(cmd: list[str]) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=3)
        return out.stdout.strip()
    except Exception:
        return ""


def pct_from(text: str) -> int:
    for tok in text.split():
        if tok.endswith("%"):
            try:
                return int(tok.rstrip("%"))
            except ValueError:
                pass
    return 0


def get_volume(kind: str) -> int:
    """kind = sink | source"""
    out = run(["pactl", f"get-{kind}-volume", f"@DEFAULT_{kind.upper()}@"])
    if not out:
        return 0
    # "Volume: front-left: 37451 / 57% / -14.58 dB, ..."
    # take the first token that looks like a percentage
    return pct_from(out)


def get_muted(kind: str) -> bool:
    out = run(["pactl", f"get-{kind}-mute", f"@DEFAULT_{kind.upper()}@"])
    return "yes" in out


def clean_desc(desc: str) -> str:
    """Strip the long ALSA controller prefix so the useful part fits."""
    for prefix in (
        "Alder Lake PCH-P High Definition Audio Controller ",
        "Alder Lake-P PCH High Definition Audio Controller ",
    ):
        if desc.startswith(prefix):
            desc = desc[len(prefix):]
    desc = desc.replace("Monitor of ", "")
    desc = desc.replace("HDMI / DisplayPort", "HDMI/DP")
    desc = desc.replace("Stereo Microphone", "Mic (analog)")
    desc = desc.replace("Digital Microphone", "Mic (digital)")
    return desc.strip() or "unknown"


def get_device_name(kind: str) -> str:
    out = run(["pactl", f"get-default-{kind}"])
    if not out:
        return "unknown"
    desc = run(["pactl", "list", f"{kind}s"])
    # find the block for this device and read Description
    current, in_block = out, False
    for line in desc.splitlines():
        stripped = line.strip()
        if stripped.startswith("Name: ") and stripped.split(": ", 1)[1] == current:
            in_block = True
        elif in_block and stripped.startswith("Description: "):
            return clean_desc(stripped.split(": ", 1)[1])
        elif in_block and stripped.startswith("Name: "):
            break
    return clean_desc(current.split(".")[-1])[:30]


def set_volume(kind: str, value: int) -> None:
    run(["pactl", f"set-{kind}-volume", f"@DEFAULT_{kind.upper()}@", f"{value}%"])
    if value > 0:
        run(["pactl", f"set-{kind}-mute", f"@DEFAULT_{kind.upper()}@", "0"])


def toggle_mute(kind: str) -> None:
    run(["pactl", f"set-{kind}-mute", f"@DEFAULT_{kind.upper()}@", "toggle"])


class Row(Gtk.Box):
    """One device row: header (icon, name, switch, mute) + slider."""

    def __init__(self, kind: str, title: str, icon: str, on_close):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.kind = kind
        self.on_close = on_close

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)

        self.icon_lbl = Gtk.Label(label=icon)
        self.icon_lbl.set_css_classes(["device-name"])
        header.append(self.icon_lbl)
        self._icon_normal = icon

        textbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        textbox.set_hexpand(True)
        self.name_lbl = Gtk.Label(label="...", xalign=0)
        self.name_lbl.set_css_classes(["device-name"])
        self.name_lbl.set_ellipsize(3)  # PANGO_ELLIPSIZE_END
        self.name_lbl.set_max_width_chars(30)
        textbox.append(self.name_lbl)

        self.sub_lbl = Gtk.Label(label=title, xalign=0)
        self.sub_lbl.set_css_classes(["device-sub"])
        textbox.append(self.sub_lbl)
        header.append(textbox)

        self.mute_btn = Gtk.Button(label="󰕾")
        self.mute_btn.set_css_classes(["btn"])
        self.mute_btn.set_tooltip_text("Mute / unmute")
        self.mute_btn.connect("clicked", self._on_mute)
        header.append(self.mute_btn)

        self.switch_btn = Gtk.Button(label="󰒓")
        self.switch_btn.set_css_classes(["btn"])
        self.switch_btn.set_tooltip_text("Change device")
        self.switch_btn.connect("clicked", self._on_switch)
        header.append(self.switch_btn)

        self.append(header)

        slider_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
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
        self.append(slider_row)

        self._loading = False
        self.refresh()

    def refresh(self):
        self._loading = True
        vol = get_volume(self.kind)
        muted = get_muted(self.kind)
        self.scale.set_value(vol)
        self.value_lbl.set_text(f"{vol}%")
        name = get_device_name(self.kind)
        self.name_lbl.set_text(name)
        if muted:
            self.value_lbl.set_css_classes(["muted-value"])
            self.mute_btn.set_css_classes(["btn", "on"])
            self.mute_btn.set_label("󰝟")
            self.icon_lbl.set_text("󰝟")
        else:
            self.value_lbl.set_css_classes(["value"])
            self.mute_btn.set_css_classes(["btn"])
            self.mute_btn.set_label("󰕾")
            self.icon_lbl.set_text(self._icon_normal)
        self._loading = False

    def _on_scale(self, scale):
        if self._loading:
            return
        val = int(round(scale.get_value()))
        set_volume(self.kind, val)
        self.value_lbl.set_text(f"{val}%")
        self.value_lbl.set_css_classes(["value"])
        self.mute_btn.set_css_classes(["btn"])

    def _on_mute(self, _btn):
        toggle_mute(self.kind)
        GLib.timeout_add(80, self._after_toggle)

    def _after_toggle(self):
        self.refresh()
        return False

    def _on_switch(self, _btn):
        subprocess.Popen(
            ["bash", "-lc", AUDIO_SWITCH],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        GLib.timeout_add(1200, self._after_switch)

    def _after_switch(self):
        self.refresh()
        return False


class AudioPanel(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.serialchiller.audiopanel")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("audio-panel")

        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        outer = Gtk.Box()
        outer.set_margin_top(0)
        outer.set_margin_bottom(0)
        outer.set_margin_start(0)
        outer.set_margin_end(0)

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        panel.set_css_classes(["panel"])
        panel.set_size_request(360, -1)

        brand = Gtk.Label(label="A U D I O", xalign=0)
        brand.set_css_classes(["brand"])
        panel.append(brand)

        self.out_row = Row("sink", "Output", "󰕾", win.close)
        panel.append(self.out_row)

        panel.append(Gtk.Separator())

        self.in_row = Row("source", "Input  (microphone)", "󰍬", win.close)
        panel.append(self.in_row)

        outer.append(panel)
        win.set_child(outer)

        # live refresh every second so external changes (media keys,
        # device switch, other apps) show up in the panel
        GLib.timeout_add(1000, self._tick)

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        win.present()

    def _tick(self):
        try:
            self.out_row.refresh()
            self.in_row.refresh()
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
    app = AudioPanel()
    return app.run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
