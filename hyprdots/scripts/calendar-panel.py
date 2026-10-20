#!/usr/bin/env python3
"""calendar-panel.py — month calendar as a normal GTK4 window.

Layout mirrors a classic print planner: the month name big on the left and
the year muted on the right, a row of weekday headers, then a 7-column grid
of days starting on Monday. Today is highlighted; days from the previous and
next month are dimmed.

Navigation: click the arrows, use the mouse wheel, or press Left/Right to
step months; press Home (or click the month title) to jump back to today.

Usage: calendar-panel.py
"""

import calendar
import datetime
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

BG = "#171717"
CARD = "#0e0e0e"
FG = "#fafafa"
MUTED = "#a1a1a1"
DIM = "#4a4a4a"
ACCENT = "#91c5ff"

# Monday-first, matching the print layout.
WEEKDAYS = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
MONTHS = [
    "", "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
    "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER",
]


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
    padding: {px(18)}px {px(20)}px {px(18)}px {px(20)}px;
}}
label {{
    color: {FG};
}}
.month {{
    color: {FG};
    font-size: {px(19)}px;
    font-weight: bold;
    letter-spacing: 1px;
}}
.year {{
    color: {MUTED};
    font-size: {px(19)}px;
    font-weight: bold;
}}
.weekday {{
    color: {FG};
    font-size: {px(10)}px;
    font-weight: bold;
    letter-spacing: 0;
}}
.weekday-sun {{
    color: {ACCENT};
    font-size: {px(10)}px;
    font-weight: bold;
    letter-spacing: 0;
}}
.day {{
    color: {FG};
    font-size: {px(14)}px;
}}
.day-other {{
    color: {DIM};
    font-size: {px(14)}px;
}}
.day-today {{
    color: {ACCENT};
    font-size: {px(14)}px;
    font-weight: bold;
    text-decoration: underline;
}}
.slot {{
    min-width: {px(30)}px;
    min-height: {px(26)}px;
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
    padding: {px(2)}px {px(10)}px;
    min-height: {px(22)}px;
}}
.btn label {{
    color: {MUTED};
    font-size: {px(15)}px;
}}
.btn:hover {{
    background-color: #262626;
    border-color: #3a3a3a;
}}
.btn:hover label {{
    color: {FG};
}}
.month-btn {{
    background-color: transparent;
    background-image: none;
    border: none;
    box-shadow: none;
    padding: 0;
    min-height: 0;
}}
.month-btn:hover {{
    background-color: transparent;
}}
""" + NF_CSS


class CalendarPanel(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.serialchiller.calendarpanel")
        self.scale = 1.0
        today = datetime.date.today()
        self.year = today.year
        self.month = today.month
        self.month_lbl = None
        self.year_lbl = None
        self.grid = None

    def do_activate(self):
        existing = self.get_active_window() or (self.get_windows() or [None])[0]
        if existing is not None:
            existing.present()
            return

        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("calendar-panel")

        _sw, _sh = monitor_size()
        scale = font_scale(_sh)
        self.scale = scale
        win.set_default_size(int(360 * scale), -1)

        provider = Gtk.CssProvider()
        provider.load_from_string(build_css(scale))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=9)
        panel.set_css_classes(["panel"])

        # --- header: year on the right (month lives in the nav row below) ---
        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        head.set_halign(Gtk.Align.END)
        self.year_lbl = Gtk.Label(xalign=1)
        self.year_lbl.set_css_classes(["year"])
        head.append(self.year_lbl)
        panel.append(head)

        nav = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        prev = Gtk.Button(label="\U000f0141")   # chevron-left
        prev.set_css_classes(["btn", "nf-btn"])
        prev.set_tooltip_text("Previous month")
        prev.connect("clicked", lambda *_: self._shift(-1))
        nav.append(prev)

        # The middle control carries the month name; clicking it jumps back to
        # the current month. Styled as a plain title (no button chrome, no
        # hover feedback) so it reads as a label, not a control.
        self.month_btn = Gtk.Button()
        self.month_btn.set_css_classes(["month-btn"])
        self.month_btn.set_hexpand(True)
        self.month_btn.set_tooltip_text("Click to jump to today")
        self.month_btn.connect("clicked", lambda *_: self._go_today())
        self.month_lbl = Gtk.Label()
        self.month_lbl.set_css_classes(["month"])
        self.month_btn.set_child(self.month_lbl)
        nav.append(self.month_btn)

        nxt = Gtk.Button(label="\U000f0142")    # chevron-right
        nxt.set_css_classes(["btn", "nf-btn"])
        nxt.set_tooltip_text("Next month")
        nxt.connect("clicked", lambda *_: self._shift(1))
        nav.append(nxt)
        panel.append(nav)

        # --- weekday header row ---
        wk = Gtk.Grid(column_homogeneous=True, row_spacing=6, column_spacing=4)
        for i, name in enumerate(WEEKDAYS):
            lbl = Gtk.Label(label=name)
            # Sunday (last column) stays accented; other days match the date text.
            lbl.set_css_classes(["weekday-sun" if name == "SUNDAY" else "weekday"])
            wk.attach(lbl, i, 0, 1, 1)
        panel.append(wk)

        # --- day grid ---
        self.grid = Gtk.Grid(column_homogeneous=True, row_spacing=4, column_spacing=6)
        panel.append(self.grid)

        win.set_child(panel)

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        scroll = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.VERTICAL)
        scroll.connect("scroll", self._on_scroll)
        win.add_controller(scroll)

        register_panel("calendar")
        win.present()
        self._render()

    # -- rendering -----------------------------------------------------------

    def _render(self):
        self.month_lbl.set_text(MONTHS[self.month])
        self.year_lbl.set_text(str(self.year))

        while (child := self.grid.get_first_child()) is not None:
            self.grid.remove(child)

        today = datetime.date.today()
        # Monday-first: months_calendar already gives weeks starting Monday.
        cal = calendar.Calendar(firstweekday=0)
        weeks = cal.monthdayscalendar(self.year, self.month)

        for r, week in enumerate(weeks):
            for c, day in enumerate(week):
                if day == 0:
                    # filler slot from an adjacent month: show the real date,
                    # dimmed, like the print layout
                    text, cls = self._filler(self.year, self.month, r, c), "day-other"
                elif (self.year, self.month, day) == (today.year, today.month, today.day):
                    text, cls = str(day), "day-today"
                else:
                    text, cls = str(day), "day"
                lbl = Gtk.Label(label=text)
                lbl.set_css_classes([cls, "slot"])
                self.grid.attach(lbl, c, r, 1, 1)

    def _filler(self, year: int, month: int, r: int, c: int) -> str:
        """Date number for a leading/trailing filler cell (adjacent month)."""
        first = datetime.date(year, month, 1)
        # first weekday index Monday=0
        lead = first.weekday()
        # cell index within the whole grid
        idx = r * 7 + c
        if idx < lead:
            d = first - datetime.timedelta(days=lead - idx)
        else:
            last = calendar.monthrange(year, month)[1]
            offset = idx - lead - last
            d = first + datetime.timedelta(days=lead + last + offset)
        return str(d.day)

    # -- navigation ----------------------------------------------------------

    def _shift(self, delta: int):
        m = self.month + delta
        y = self.year
        while m < 1:
            m += 12
            y -= 1
        while m > 12:
            m -= 12
            y += 1
        self.month, self.year = m, y
        self._render()

    def _go_today(self):
        t = datetime.date.today()
        self.year, self.month = t.year, t.month
        self._render()

    def _on_scroll(self, _c, _dx, dy):
        if dy > 0:
            self._shift(1)
        elif dy < 0:
            self._shift(-1)
        return True

    def _on_key(self, _c, keyval, _code, _state):
        if keyval == Gdk.KEY_Escape:
            for w in self.get_windows():
                w.close()
            return True
        if keyval in (Gdk.KEY_Left, Gdk.KEY_Page_Up):
            self._shift(-1)
            return True
        if keyval in (Gdk.KEY_Right, Gdk.KEY_Page_Down):
            self._shift(1)
            return True
        if keyval == Gdk.KEY_Home:
            self._go_today()
            return True
        return False


def main() -> int:
    if toggle_panel("calendar"):
        return 0
    try:
        return CalendarPanel().run(sys.argv)
    finally:
        release_panel("calendar")


if __name__ == "__main__":
    sys.exit(main())