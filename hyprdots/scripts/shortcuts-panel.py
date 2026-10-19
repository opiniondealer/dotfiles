#!/usr/bin/env python3
"""shortcuts-panel.py — keybind cheatsheet as a normal GTK4 window.

Reads the cheatsheet text produced by shortcuts.sh (render) so the content
stays in one place, then displays it grouped by section.

Usage: shortcuts-panel.py
"""

import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, Gtk  # noqa: E402

SCRIPT_DIR = __file__.rsplit("/", 1)[0] if "/" in __file__ else "."

BG = "#171717"
FG = "#fafafa"
MUTED = "#a1a1a1"
ACCENT = "#91c5ff"

CSS = f"""
window {{
    background-color: {BG};
}}
.panel {{
    background-color: {BG};
    border: 1px solid #262626;
    border-radius: 14px;
    padding: 16px 18px 14px 18px;
}}
label {{
    color: {FG};
}}
.brand {{
    color: {MUTED};
    font-size: 10px;
    letter-spacing: 2px;
}}
.section {{
    color: {ACCENT};
    font-size: 10px;
    font-weight: bold;
    letter-spacing: 1.5px;
}}
.key {{
    color: {FG};
    font-size: 11px;
}}
.desc {{
    color: {MUTED};
    font-size: 11px;
}}
scrolledwindow {{
    background-color: transparent;
}}
"""


def load_cheatsheet() -> str:
    """Run shortcuts.sh with SHEET_ONLY=1 to get the raw text."""
    try:
        out = subprocess.run(
            ["bash", f"{SCRIPT_DIR}/shortcuts.sh", "--print"],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if out.stdout.strip():
            return out.stdout
    except Exception:
        pass
    return ""


def parse(text: str):
    """-> [(section, [(key, desc)])]"""
    result = []
    current = None
    for line in text.splitlines():
        if not line.strip():
            continue
        # section headers have no leading spaces
        if not line.startswith(" "):
            current = (line.strip(), [])
            result.append(current)
            continue
        if current is None:
            continue
        stripped = line.strip()
        # split key from description on 2+ spaces
        parts = stripped.split("  ", 1)
        key = parts[0].strip()
        desc = parts[1].strip() if len(parts) > 1 else ""
        current[1].append((key, desc))
    return result


class ShortcutsPanel(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.serialchiller.shortcutspanel")

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("shortcuts-panel")
        win.set_default_size(520, 620)

        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        panel.set_css_classes(["panel"])

        brand = Gtk.Label(label="K E Y B I N D S", xalign=0)
        brand.set_css_classes(["brand"])
        panel.append(brand)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)

        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)

        sections = parse(load_cheatsheet())
        if not sections:
            lbl = Gtk.Label(label="Could not load keybinds", xalign=0)
            lbl.set_css_classes(["desc"])
            content.append(lbl)
        else:
            for i, (title, items) in enumerate(sections):
                if i > 0:
                    spacer = Gtk.Box()
                    spacer.set_size_request(-1, 10)
                    content.append(spacer)

                head = Gtk.Label(label=title, xalign=0)
                head.set_css_classes(["section"])
                content.append(head)

                grid = Gtk.Grid()
                grid.set_column_spacing(18)
                grid.set_row_spacing(3)
                for r, (key, desc) in enumerate(items):
                    k = Gtk.Label(label=key, xalign=0)
                    k.set_css_classes(["key"])
                    grid.attach(k, 0, r, 1, 1)
                    d = Gtk.Label(label=desc, xalign=0)
                    d.set_css_classes(["desc"])
                    grid.attach(d, 1, r, 1, 1)
                content.append(grid)

        scroll.set_child(content)
        panel.append(scroll)

        win.set_child(panel)

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        win.present()

    def _on_key(self, _c, keyval, _code, _state):
        if keyval == Gdk.KEY_Escape:
            for w in self.get_windows():
                w.close()
            return True
        return False


def main() -> int:
    return ShortcutsPanel().run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
