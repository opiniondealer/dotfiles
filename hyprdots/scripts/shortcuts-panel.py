#!/usr/bin/env python3
"""shortcuts-panel.py — keybind cheatsheet as a normal GTK4 window.

Reads the cheatsheet text produced by shortcuts.sh (render) so the content
stays in one place, then displays it grouped by section.

Sections are laid out in two balanced columns so the panel fits without
scrolling on a normal screen. Scrolling stays enabled as a fallback for very
small displays or when many bindings are added.

Usage: shortcuts-panel.py
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


class ShortcutsPanel(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.serialchiller.shortcutspanel")

    def do_activate(self):
        # Single instance: if a window is already open, just focus it.
        existing = self.get_active_window() or (self.get_windows() or [None])[0]
        if existing is not None:
            existing.present()
            return

        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("shortcuts-panel")

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

        sections = parse(load_cheatsheet())
        columns = []

        if not sections:
            content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
            lbl = Gtk.Label(label="Could not load keybinds", xalign=0)
            lbl.set_css_classes(["desc"])
            content.append(lbl)
            scroll.set_child(content)
        else:
            # Two balanced columns: fill column 0, then column 1, splitting so
            # both halves carry a similar number of rows.
            columns = self._split_balanced(sections)
            cols = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=28)
            for col_sections in columns:
                col = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
                for i, (title, items) in enumerate(col_sections):
                    if i > 0:
                        spacer = Gtk.Box()
                        spacer.set_size_request(-1, 10)
                        col.append(spacer)

                    head = Gtk.Label(label=title, xalign=0)
                    head.set_css_classes(["section"])
                    col.append(head)

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
                    col.append(grid)
                cols.append(col)
            scroll.set_child(cols)

        panel.append(scroll)

        win.set_child(panel)

        # Size the window from the actual content instead of measure(): count
        # the rows in the tallest column and convert to pixels. Deterministic
        # and independent of GTK's layout timing.
        tallest = 0
        for col_sections in columns:
            n = sum(len(items) + 1 for _, items in col_sections) + max(len(col_sections) - 1, 0)
            tallest = max(tallest, n)
        ROW_PX = 18      # key/desc line height incl. row spacing
        PAD = 74         # brand + panel padding + margins
        est_h = PAD + tallest * ROW_PX
        disp = Gdk.Display.get_default()
        mont = disp.get_monitors().get_item(0) if disp else None
        max_h = mont.get_geometry().height - 90 if mont else est_h
        win.set_default_size(780, min(est_h, max_h))

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        claim_panel("shortcuts")
        win.present()

    @staticmethod
    def _split_balanced(sections):
        """Split sections into two columns with a similar total row count.

        Sections keep their order. We greedily assign each section to the
        currently shorter column, which balances the two halves well enough
        for a cheatsheet.
        """
        left, right = [], []
        left_rows = right_rows = 0
        for sec in sections:
            # +1 accounts for the section header row.
            size = len(sec[1]) + 1
            if left_rows <= right_rows:
                left.append(sec)
                left_rows += size
            else:
                right.append(sec)
                right_rows += size
        return [left, right]

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
