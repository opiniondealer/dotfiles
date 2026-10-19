#!/usr/bin/env python3
"""wifi-panel.py — Wi-Fi picker as a normal GTK4 window.

Lists nearby networks with signal %, marks the connected one, and connects
on selection (asks for a password when the profile is not saved).

Usage: wifi-panel.py
"""

import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

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
.ssid {{
    color: {FG};
    font-size: 12px;
}}
.ssid-active {{
    color: {ACCENT};
    font-size: 12px;
    font-weight: bold;
}}
.signal {{
    color: {MUTED};
    font-size: 11px;
}}
.badge {{
    color: {ACCENT};
    font-size: 9px;
}}
row {{
    background-color: transparent;
    border-radius: 8px;
    padding: 6px 8px;
}}
row:hover {{
    background-color: #1f1f1f;
}}
list {{
    background-color: transparent;
}}
scrolledwindow {{
    background-color: transparent;
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
    padding: 4px 12px;
    min-height: 22px;
}}
.btn label {{
    color: {MUTED};
    font-size: 10px;
    font-weight: bold;
}}
.btn:hover {{
    background-color: #262626;
    border-color: #3a3a3a;
}}
.btn:hover label {{
    color: {FG};
}}
entry {{
    background-color: {CARD};
    color: {FG};
    border: 1px solid #2e2e2e;
    border-radius: 7px;
    padding: 6px 9px;
    font-size: 12px;
}}
entry:focus {{
    border-color: {ACCENT};
}}
.status {{
    color: {MUTED};
    font-size: 10px;
}}
.status-error {{
    color: {DESTRUCTIVE};
    font-size: 10px;
}}
"""


def run(cmd: list[str], timeout: int = 20) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return out.stdout
    except Exception:
        return ""


def scan() -> list[tuple[str, int, bool]]:
    """[(ssid, signal, connected)]"""
    raw = run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "dev", "wifi", "list", "--rescan", "yes"])
    seen: dict[str, tuple[int, bool]] = {}
    for line in raw.splitlines():
        parts = line.split(":")
        if len(parts) < 3:
            continue
        in_use, ssid, sig = parts[0], ":".join(parts[1:-1]), parts[-1]
        ssid = ssid.strip()
        if not ssid:
            continue
        try:
            signal = int(sig)
        except ValueError:
            continue
        connected = in_use.strip() == "*"
        prev = seen.get(ssid)
        if prev is None or signal > prev[0] or connected:
            seen[ssid] = (signal, connected)
    return sorted(
        ((s, sig, con) for s, (sig, con) in seen.items()),
        key=lambda t: (not t[2], -t[1]),
    )


def icon_for(signal: int) -> str:
    if signal >= 75:
        return "󰤨"
    if signal >= 50:
        return "󰤥"
    if signal >= 25:
        return "󰤢"
    return "󰤟"


def has_profile(ssid: str) -> bool:
    out = run(["nmcli", "-t", "-f", "NAME", "connection", "show"])
    return ssid in out.splitlines()


def connected_ssid() -> str:
    out = run(["nmcli", "-t", "-f", "NAME", "connection", "show", "--active"])
    return out.strip().splitlines()[0] if out.strip() else ""


def autoclose_on_blur(win):
    """Close the window as soon as it loses focus (click elsewhere).

    Suppressed while a child dialog (password prompt) is open, otherwise
    the main panel would vanish the moment the dialog takes focus.
    """

    # Only arm auto-close once the window has actually been focused, so a
    # launch that starts unfocused (e.g. from a terminal) does not vanish.
    state = {"armed": False}

    def _on_active(w, _pspec):
        if w.is_active():
            state["armed"] = True
            return
        if not state["armed"]:
            return
        for other in w.get_application().get_windows():
            if other is not w and other.get_transient_for() is w:
                return
        w.close()

    win.connect("notify::is-active", _on_active)


class WifiPanel(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.serialchiller.wifipanel")
        self.listbox = None
        self.status_lbl = None

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("wifi-panel")
        win.set_default_size(430, 480)

        provider = Gtk.CssProvider()
        provider.load_from_string(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        panel.set_css_classes(["panel"])

        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        brand = Gtk.Label(label="N E T W O R K", xalign=0)
        brand.set_css_classes(["brand"])
        brand.set_hexpand(True)
        head.append(brand)

        self.refresh_btn = Gtk.Button(label="󰑐")
        self.refresh_btn.set_css_classes(["btn"])
        self.refresh_btn.set_tooltip_text("Rescan")
        self.refresh_btn.connect("clicked", self._on_refresh)
        head.append(self.refresh_btn)
        panel.append(head)

        self.current_lbl = Gtk.Label(xalign=0)
        self.current_lbl.set_css_classes(["status"])
        panel.append(self.current_lbl)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        scroll.set_size_request(394, 360)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.listbox.set_css_classes([])
        scroll.set_child(self.listbox)
        panel.append(scroll)

        self.status_lbl = Gtk.Label(xalign=0)
        self.status_lbl.set_css_classes(["status"])
        panel.append(self.status_lbl)

        win.set_child(panel)

        self._reload()

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        autoclose_on_blur(win)
        win.present()

    def _reload(self):
        while (child := self.listbox.get_first_child()) is not None:
            self.listbox.remove(child)

        nets = scan()
        cur = connected_ssid()
        self.current_lbl.set_text(f"Connected: {cur}" if cur else "Not connected")

        if not nets:
            lbl = Gtk.Label(label="No networks found", xalign=0)
            lbl.set_css_classes(["status"])
            self.listbox.append(lbl)
            return

        for ssid, signal, conn in nets:
            self.listbox.append(self._make_row(ssid, signal, conn))

    def _make_row(self, ssid: str, signal: int, conn: bool):
        row = Gtk.ListBoxRow()
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        icon = Gtk.Label(label=icon_for(signal))
        icon.set_css_classes(["ssid-active"] if conn else ["ssid"])
        box.append(icon)

        name = Gtk.Label(label=ssid, xalign=0)
        name.set_css_classes(["ssid-active"] if conn else ["ssid"])
        name.set_hexpand(True)
        name.set_ellipsize(3)
        name.set_max_width_chars(24)
        box.append(name)

        if conn:
            badge = Gtk.Label(label="connected")
            badge.set_css_classes(["badge"])
            box.append(badge)

        sig = Gtk.Label(label=f"{signal}%")
        sig.set_css_classes(["signal"])
        box.append(sig)

        row.set_child(box)

        gesture = Gtk.GestureClick()
        gesture.connect("released", lambda *_: self._on_pick(ssid, conn))
        row.add_controller(gesture)
        return row

    def _set_status(self, text: str, error: bool = False):
        self.status_lbl.set_text(text)
        self.status_lbl.set_css_classes(["status-error"] if error else ["status"])

    def _on_pick(self, ssid: str, is_connected: bool):
        if is_connected:
            self._set_status(f"Disconnecting from {ssid}...")
            GLib.timeout_add(50, lambda: self._disconnect(ssid))
            return

        if has_profile(ssid):
            self._set_status(f"Connecting to {ssid}...")
            GLib.timeout_add(50, lambda: self._connect(ssid))
        else:
            self._ask_password(ssid)

    def _disconnect(self, ssid: str):
        run(["nmcli", "connection", "down", ssid])
        self._set_status(f"Disconnected from {ssid}")
        run(["notify-send", "WiFi", f"Disconnected from {ssid}"])
        GLib.timeout_add(900, self._reload_and_false)
        return False

    def _connect(self, ssid: str):
        out = run(["nmcli", "connection", "up", ssid])
        if out is not None:
            self._set_status(f"Connected to {ssid}")
            run(["notify-send", "WiFi", f"Connected to {ssid}"])
        else:
            self._set_status(f"Failed to connect to {ssid}", error=True)
            run(["notify-send", "-u", "critical", "WiFi", f"Failed to connect to {ssid}"])
        GLib.timeout_add(900, self._reload_and_false)
        return False

    def _reload_and_false(self):
        self._reload()
        return False

    def _ask_password(self, ssid: str):
        dialog = Gtk.Window(application=self)
        dialog.set_decorated(False)
        dialog.set_resizable(False)
        dialog.set_title("wifi-password")
        dialog.set_transient_for(self.get_active_window())

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        box.set_css_classes(["panel"])
        box.set_size_request(340, -1)

        lbl = Gtk.Label(label=f"Password for {ssid}", xalign=0)
        lbl.set_css_classes(["ssid"])
        lbl.set_ellipsize(3)
        lbl.set_max_width_chars(34)
        box.append(lbl)

        entry = Gtk.Entry()
        entry.set_visibility(False)
        entry.set_input_purpose(Gtk.InputPurpose.PASSWORD)
        entry.set_placeholder_text("password")
        entry.connect("activate", lambda e: self._do_connect_with_pass(ssid, e.get_text(), dialog))
        box.append(entry)

        btns = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        btns.set_halign(Gtk.Align.END)
        cancel = Gtk.Button(label="Cancel")
        cancel.set_css_classes(["btn"])
        cancel.connect("clicked", lambda *_: dialog.close())
        btns.append(cancel)
        ok = Gtk.Button(label="Connect")
        ok.set_css_classes(["btn"])
        ok.connect("clicked", lambda *_: self._do_connect_with_pass(ssid, entry.get_text(), dialog))
        btns.append(ok)
        box.append(btns)

        dialog.set_child(box)
        dialog.present()
        entry.grab_focus()

    def _do_connect_with_pass(self, ssid: str, password: str, dialog):
        dialog.close()
        if not password:
            return
        self._set_status(f"Connecting to {ssid}...")
        run(["nmcli", "dev", "wifi", "connect", ssid, "password", password])
        self._set_status(f"Connected to {ssid}")
        run(["notify-send", "WiFi", f"Connected to {ssid}"])
        GLib.timeout_add(900, self._reload_and_false)

    def _on_refresh(self, _btn):
        self._set_status("Scanning...")
        GLib.timeout_add(50, lambda: (self._reload(), self._set_status(""), False)[-1])

    def _on_key(self, _c, keyval, _code, _state):
        if keyval == Gdk.KEY_Escape:
            for w in self.get_windows():
                w.close()
            return True
        return False


def main() -> int:
    return WifiPanel().run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())
