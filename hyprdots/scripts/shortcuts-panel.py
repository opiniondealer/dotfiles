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
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

SCRIPT_DIR = __file__.rsplit("/", 1)[0] if "/" in __file__ else "."
sys.path.insert(0, SCRIPT_DIR)
from panel_scale import (  # noqa: E402
    font_scale,
    make_px,
    monitor_size,
    register_panel,
    release_panel,
    toggle_panel,
)

BG = "#171717"
FG = "#fafafa"
MUTED = "#a1a1a1"
ACCENT = "#91c5ff"

# Font scale: sizes are expressed in px against a 1080p reference and scaled
# with the monitor height, so the cheatsheet looks the same on a 1080p panel
# and on a HiDPI laptop panel.
FS_BASE = 14.0  # key/desc font at the reference height


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
    padding: {px(16)}px {px(18)}px {px(14)}px {px(18)}px;
}}
label {{
    color: {FG};
}}
.brand {{
    color: {MUTED};
    font-size: {px(13)}px;
    letter-spacing: 2px;
}}
.section {{
    color: {ACCENT};
    font-size: {px(13)}px;
    font-weight: bold;
    letter-spacing: 1.5px;
}}
.key {{
    color: {FG};
    font-size: {px(FS_BASE)}px;
}}
.desc {{
    color: {MUTED};
    font-size: {px(FS_BASE)}px;
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
        # Single instance: if a window is already open, just focus it.
        existing = self.get_active_window() or (self.get_windows() or [None])[0]
        if existing is not None:
            existing.present()
            return

        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("shortcuts-panel")

        # Scale fonts and geometry with the monitor the window opens on, so the
        # panel looks identical on 1080p and HiDPI panels.
        sw, sh = monitor_size()
        scale = font_scale(sh)

        provider = Gtk.CssProvider()
        provider.load_from_string(build_css(scale))
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
        # Let the scrolled window report the child's natural height upward so
        # the window can be sized to the content instead of a guessed value.
        scroll.set_propagate_natural_height(True)

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

        # Width is a share of the monitor; height follows the content (fitted
        # after the first layout pass, capped to a share of the monitor) so a
        # short cheatsheet stays tight and a long one scrolls.
        W_PCT = 0.42        # width as a share of the monitor width
        MIN_W_PCT = 0.34    # never narrower than this share
        MAX_H_PCT = 0.68    # never taller than this share of the monitor

        w = max(int(sw * W_PCT), int(sw * MIN_W_PCT))
        win.set_default_size(w, 1)  # height comes from the content (see below)

        # Freeze the height once the content has been measured, capped to a
        # share of the monitor. Uses the scrolled window's propagated natural
        # height, which is only valid after the first layout pass.
        def _fit_height(_win=None):
            _, nat_h, _, _ = scroll.measure(Gtk.Orientation.VERTICAL, -1)
            if nat_h <= 1:
                return False
            chrome = int(51 * scale) + 2  # brand + panel padding (scaled)
            h = min(nat_h + chrome + 8, int(sh * MAX_H_PCT))
            win.set_default_size(w, h)
            return False

        win.connect("realize", lambda *_: GLib.idle_add(_fit_height))

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        register_panel("shortcuts")
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
    if toggle_panel("shortcuts"):
        return 0
    try:
        return ShortcutsPanel().run(sys.argv)
    finally:
        release_panel("shortcuts")


if __name__ == "__main__":
    sys.exit(main())
