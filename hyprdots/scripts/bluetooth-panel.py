#!/usr/bin/env python3
"""bluetooth-panel.py — Bluetooth control as a normal GTK4 window.

Shows the adapter status, a power toggle, a scan toggle, and two lists:
paired/known devices (with connect/disconnect) and newly discovered devices
(with pair/connect).

Usage: bluetooth-panel.py
"""

import os
import pathlib
import re
import signal
import subprocess
import sys

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

SCRIPT_DIR = __file__.rsplit("/", 1)[0] if "/" in __file__ else "."
sys.path.insert(0, SCRIPT_DIR)
from panel_scale import font_scale, make_px, monitor_size, icon_label, NF_CSS  # noqa: E402

BG = "#171717"
CARD = "#0e0e0e"
FG = "#fafafa"
MUTED = "#a1a1a1"
ACCENT = "#91c5ff"
DESTRUCTIVE = "#ff6467"
WARN = "#e0c07b"

PANEL_STATE = "/tmp/opencode-serialchiller-panel.pid"
ADDR_RE = re.compile(r"^Device ([0-9A-F:]{17}) (.+)$")


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
.adapter {{
    color: {FG};
    font-size: {px(15)}px;
    font-weight: bold;
}}
.adapter-off {{
    color: {MUTED};
    font-size: {px(15)}px;
    font-weight: bold;
}}
.device {{
    color: {FG};
    font-size: {px(15)}px;
}}
.device-active {{
    color: {ACCENT};
    font-size: {px(15)}px;
    font-weight: bold;
}}
.sub {{
    color: {MUTED};
    font-size: {px(13)}px;
}}
.badge {{
    color: {ACCENT};
    font-size: {px(12)}px;
}}
.badge-warn {{
    color: {WARN};
    font-size: {px(12)}px;
}}
.section {{
    color: {MUTED};
    font-size: {px(13)}px;
    letter-spacing: 1px;
}}
row {{
    background-color: transparent;
    border-radius: 8px;
    padding: {px(6)}px {px(8)}px;
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
    padding: {px(4)}px {px(12)}px;
    min-height: {px(22)}px;
}}
.btn label {{
    color: {MUTED};
    font-size: {px(13)}px;
    font-weight: bold;
}}
.btn:hover {{
    background-color: #262626;
    border-color: #3a3a3a;
}}
.btn:hover label {{
    color: {FG};
}}
.status {{
    color: {MUTED};
    font-size: {px(13)}px;
}}
.status-error {{
    color: {DESTRUCTIVE};
    font-size: {px(13)}px;
}}
""" + NF_CSS


def run(cmd: list[str], timeout: int = 25) -> str:
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return out.stdout
    except Exception:
        return ""


def bt(*args: str, timeout: int = 25) -> str:
    return run(["bluetoothctl", *args], timeout=timeout)


def adapter_info() -> dict:
    """Parse `bluetoothctl show` into a dict of interesting fields."""
    info: dict = {"name": "bluetooth", "powered": False, "discoverable": False}
    out = bt("show")
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Name:"):
            info["name"] = line.split(":", 1)[1].strip()
        elif line.startswith("Powered:"):
            info["powered"] = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Discoverable:"):
            info["discoverable"] = line.split(":", 1)[1].strip().lower() == "yes"
    return info


def rfkill_soft_blocked() -> bool:
    out = run(["rfkill", "list", "bluetooth"])
    return "Soft blocked: yes" in out


def device_state(mac: str) -> dict:
    """Parse `bluetoothctl info <mac>` into a dict."""
    st = {"paired": False, "connected": False, "trusted": False, "icon": "", "name": ""}
    out = bt("info", mac)
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("Name:"):
            st["name"] = line.split(":", 1)[1].strip()
        elif line.startswith("Icon:"):
            st["icon"] = line.split(":", 1)[1].strip()
        elif line.startswith("Paired:"):
            st["paired"] = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Connected:"):
            st["connected"] = line.split(":", 1)[1].strip().lower() == "yes"
        elif line.startswith("Trusted:"):
            st["trusted"] = line.split(":", 1)[1].strip().lower() == "yes"
    return st


def device_icon(icon: str) -> str:
    table = {
        "audio-headset": "󰋋",
        "audio-headphones": "󰋋",
        "audio-card": "󰓃",
        "input-keyboard": "󰌌",
        "input-mouse": "󰍽",
        "input-gaming": "󰊴",
        "phone": "󰏲",
        "computer": "󰟀",
    }
    return table.get(icon, "󰂯")


def paired_devices() -> list[str]:
    """[{mac, name}] for devices known to the adapter (paired or trusted)."""
    out = bt("devices")
    macs: list[str] = []
    for line in out.splitlines():
        m = ADDR_RE.match(line.strip())
        if m:
            macs.append(m.group(1))
    result = []
    for mac in macs:
        st = device_state(mac)
        if st["paired"] or st["trusted"]:
            result.append((mac, st))
    return result


def adapter_mac() -> str:
    out = bt("show")
    m = re.search(r"Controller ([0-9A-F:]{17})", out)
    return m.group(1) if m else ""


def scan_now() -> list[str]:
    """Run a short discovery pass; return the newly seen MACs."""
    own = adapter_mac()
    before = set(re.findall(r"([0-9A-F:]{17})", bt("devices")))
    both = bt("--timeout", "6", "scan", "on", timeout=12)
    after = set(re.findall(r"([0-9A-F:]{17})", bt("devices") + both))
    after.discard(own)  # never list the adapter itself
    return sorted(after - before)


def claim_panel(me: str) -> None:
    """Close any other panel before showing this one (mutual exclusion)."""
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


class BluetoothPanel(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.serialchiller.bluetoothpanel")
        self.scale = 1.0
        self.listbox = None
        self.newbox = None
        self.adapter_lbl = None
        self.status_lbl = None
        self.power_btn = None
        self.scan_btn = None
        self.new_section = None
        self._poll_busy = False

    # -- ui ------------------------------------------------------------------

    def do_activate(self):
        existing = self.get_active_window() or (self.get_windows() or [None])[0]
        if existing is not None:
            existing.present()
            return

        win = Gtk.ApplicationWindow(application=self)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("bluetooth-panel")

        _sw, _sh = monitor_size()
        scale = font_scale(_sh)
        self.scale = scale
        win.set_default_size(int(430 * scale), int(500 * scale))

        provider = Gtk.CssProvider()
        provider.load_from_string(build_css(scale))
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
        )

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        panel.set_css_classes(["panel"])

        head = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        brand = Gtk.Label(label="B L U E T O O T H", xalign=0)
        brand.set_css_classes(["brand"])
        brand.set_hexpand(True)
        head.append(brand)

        self.scan_btn = Gtk.Button(label="󰑐")
        self.scan_btn.set_css_classes(["btn", "nf-btn"])
        self.scan_btn.set_tooltip_text("Scan for new devices")
        self.scan_btn.connect("clicked", self._on_scan)
        head.append(self.scan_btn)

        self.power_btn = Gtk.Button(label="󰅶")
        self.power_btn.set_css_classes(["btn", "nf-btn"])
        self.power_btn.set_tooltip_text("Toggle power")
        self.power_btn.connect("clicked", self._on_toggle_power)
        head.append(self.power_btn)
        panel.append(head)

        self.adapter_lbl = Gtk.Label(xalign=0)
        self.adapter_lbl.set_css_classes(["adapter-off"])
        panel.append(self.adapter_lbl)

        scroll = Gtk.ScrolledWindow()
        scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scroll.set_vexpand(True)
        scroll.set_size_request(int(394 * scale), int(290 * scale))

        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)

        known_lbl = Gtk.Label(label="PAIRED DEVICES", xalign=0)
        known_lbl.set_css_classes(["section"])
        inner.append(known_lbl)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.listbox.set_css_classes([])
        inner.append(self.listbox)

        self.new_section = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.new_lbl = Gtk.Label(label="NEW DEVICES", xalign=0)
        self.new_lbl.set_css_classes(["section"])
        self.new_section.append(self.new_lbl)
        self.newbox = Gtk.ListBox()
        self.newbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.newbox.set_css_classes([])
        self.new_section.append(self.newbox)
        self.new_section.set_visible(False)
        inner.append(self.new_section)

        scroll.set_child(inner)
        panel.append(scroll)

        self.status_lbl = Gtk.Label(xalign=0)
        self.status_lbl.set_css_classes(["status"])
        panel.append(self.status_lbl)

        win.set_child(panel)

        key = Gtk.EventControllerKey()
        key.connect("key-pressed", self._on_key)
        win.add_controller(key)

        claim_panel("bluetooth")
        win.present()
        self._reload()
        GLib.timeout_add(2000, self._poll_state)

    def _poll_state(self):
        """Refresh the adapter status so external changes (e.g. a manual
        `rfkill unblock`) show up without reopening the panel."""
        try:
            info = adapter_info()
            blocked = rfkill_soft_blocked()
            if info["powered"]:
                self.adapter_lbl.set_text(f"{info['name']} — on")
                self.adapter_lbl.set_css_classes(["adapter"])
                self.power_btn.set_label("󰅶")
                self.power_btn.set_tooltip_text("Power off")
            else:
                suffix = " (rfkill blocked)" if blocked else ""
                self.adapter_lbl.set_text(f"{info['name']} — off{suffix}")
                self.adapter_lbl.set_css_classes(["adapter-off"])
                self.power_btn.set_label("󰂲")
                self.power_btn.set_tooltip_text(
                    "Power on (unblocks rfkill, asks for admin)" if blocked else "Power on"
                )
        except Exception:
            pass
        return True

    def _clear(self, box: Gtk.ListBox):
        while (child := box.get_first_child()) is not None:
            box.remove(child)

    def _reload(self):
        self._clear(self.listbox)
        self._clear(self.newbox)
        self.new_section.set_visible(False)

        info = adapter_info()
        if not self._poll_busy:
            self._set_status("")
        blocked = rfkill_soft_blocked()
        if info["powered"]:
            self.adapter_lbl.set_text(f"{info['name']} — on")
            self.adapter_lbl.set_css_classes(["adapter"])
            self.power_btn.set_label("󰅶")
            self.power_btn.set_tooltip_text("Power off")
        else:
            suffix = " (rfkill blocked)" if blocked else ""
            self.adapter_lbl.set_text(f"{info['name']} — off{suffix}")
            self.adapter_lbl.set_css_classes(["adapter-off"])
            self.power_btn.set_label("󰂲")
            self.power_btn.set_tooltip_text(
                "Power on (unblocks rfkill, asks for admin)" if blocked else "Power on"
            )
        # Scan stays clickable always: clicking while off explains why it can't
        # scan instead of silently doing nothing.
        self.scan_btn.set_sensitive(True)

        devices = paired_devices()
        if not devices:
            lbl = Gtk.Label(label="No paired devices", xalign=0)
            lbl.set_css_classes(["sub"])
            self.listbox.append(lbl)
        for mac, st in devices:
            self.listbox.append(self._make_device_row(mac, st, discovered=False))

    def _make_device_row(self, mac: str, st: dict, discovered: bool):
        name = st.get("name") or mac
        connected = st.get("connected")
        row = Gtk.ListBoxRow()
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)

        icon = icon_label(
            device_icon(st.get("icon", "")),
            ["device-active"] if connected else ["device"],
            width_chars=2,
        )
        box.append(icon)

        text = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        text.set_hexpand(True)
        text.set_valign(Gtk.Align.CENTER)
        nm = Gtk.Label(label=name, xalign=0)
        nm.set_css_classes(["device-active"] if connected else ["device"])
        nm.set_ellipsize(3)
        nm.set_max_width_chars(22)
        text.append(nm)
        sub = Gtk.Label(label=mac, xalign=0)
        sub.set_css_classes(["sub"])
        text.append(sub)
        box.append(text)

        if connected:
            badge = Gtk.Label(label="connected")
            badge.set_css_classes(["badge"])
            badge.set_valign(Gtk.Align.CENTER)
            box.append(badge)

        # action buttons live in a fixed box so the text column stays aligned
        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        actions.set_valign(Gtk.Align.CENTER)

        if discovered and not st.get("paired"):
            act = Gtk.Button(label="Pair")
            act.set_css_classes(["btn"])
            act.connect("clicked", lambda *_: self._on_pair(mac))
            actions.append(act)
        else:
            act = Gtk.Button(label="Disconnect" if connected else "Connect")
            act.set_css_classes(["btn"])
            act.connect(
                "clicked",
                (lambda *_: self._on_disconnect(mac))
                if connected
                else (lambda *_: self._on_connect(mac)),
            )
            actions.append(act)

            unpair = Gtk.Button(label="󰅖")
            unpair.set_css_classes(["btn", "nf-btn"])
            unpair.set_tooltip_text("Unpair / forget this device")
            unpair.connect("clicked", lambda *_: self._on_unpair(mac, name))
            actions.append(unpair)

        box.append(actions)
        row.set_child(box)
        return row

    # -- actions -------------------------------------------------------------

    def _set_status(self, text: str, error: bool = False):
        self.status_lbl.set_text(text)
        self.status_lbl.set_css_classes(["status-error"] if error else ["status"])

    def _on_toggle_power(self, _btn):
        info = adapter_info()
        if info["powered"]:
            self._poll_busy = True
            bt("power", "off")
            self._set_status("Powering off...")
            GLib.timeout_add(700, self._reload_and_false)
            return

        self._poll_busy = True
        if rfkill_soft_blocked():
            self._set_status("Unblocking rfkill (auth prompt)...")
            GLib.timeout_add(50, self._unblock_then_on)
            return

        self._set_status("Powering on...")
        GLib.timeout_add(50, self._do_power_on)

    def _unblock_then_on(self):
        out = run(["pkexec", "rfkill", "unblock", "bluetooth"], timeout=90)
        if rfkill_soft_blocked():
            # pkexec cancelled, no agent, or auth failed.
            self._poll_busy = False
            self._set_status(
                "rfkill still blocked. Run: sudo rfkill unblock bluetooth "
                "sudo systemctl stop systemd-rfkill.service", error=True,
            )
            return False
        self._do_power_on()
        return False

    def _do_power_on(self):
        out = bt("power", "on", timeout=30)
        if "Failed" in out or "NotReady" in out:
            self._poll_busy = False
            self._set_status(f"Power on failed: {out.strip().splitlines()[-1] if out.strip() else 'unknown'}", error=True)
            return False
        self._set_status("Powered on")
        self._poll_busy = False
        GLib.timeout_add(900, self._reload_and_false)
        return False

    def _on_scan(self, _btn):
        if not adapter_info()["powered"]:
            self._set_status("Adapter is off — turn it on first (power button)", error=True)
            return
        self.scan_btn.set_sensitive(False)
        self._set_status("Scanning...")
        GLib.timeout_add(50, self._do_scan)

    def _do_scan(self):
        macs = scan_now()
        self._clear(self.newbox)
        shown = 0
        for mac in macs:
            st = device_state(mac)
            if st.get("paired"):
                continue
            self.newbox.append(self._make_device_row(mac, st, discovered=True))
            shown += 1
        self.new_section.set_visible(shown > 0)
        self._set_status(f"Found {shown} new device(s)" if shown else "No new devices")
        self.scan_btn.set_sensitive(True)
        return False

    def _on_pair(self, mac: str):
        self._set_status(f"Pairing {mac}...")
        GLib.timeout_add(50, lambda: self._do_pair(mac))

    def _do_pair(self, mac: str):
        out = bt("pair", mac, timeout=40)
        if "Failed" in out or "not available" in out:
            self._set_status(f"Pairing failed: {mac}", error=True)
        else:
            bt("trust", mac)
            bt("connect", mac)
            self._set_status(f"Paired {mac}")
            run(["notify-send", "Bluetooth", f"Paired {mac}"])
        GLib.timeout_add(1200, self._reload_and_false)
        return False

    def _on_connect(self, mac: str):
        self._set_status(f"Connecting {mac}...")
        GLib.timeout_add(50, lambda: self._do_connect(mac))

    def _do_connect(self, mac: str):
        out = bt("connect", mac, timeout=40)
        if "Failed" in out or "not available" in out:
            self._set_status(f"Connection failed: {mac}", error=True)
        else:
            self._set_status(f"Connected {mac}")
            run(["notify-send", "Bluetooth", f"Connected {mac}"])
        GLib.timeout_add(1200, self._reload_and_false)
        return False

    def _on_disconnect(self, mac: str):
        self._set_status(f"Disconnecting {mac}...")
        GLib.timeout_add(50, lambda: self._do_disconnect(mac))

    def _do_disconnect(self, mac: str):
        bt("disconnect", mac, timeout=40)
        self._set_status(f"Disconnected {mac}")
        run(["notify-send", "Bluetooth", f"Disconnected {mac}"])
        GLib.timeout_add(1000, self._reload_and_false)
        return False

    def _on_unpair(self, mac: str, name: str):
        self._set_status(f"Unpairing {name}...")
        self._do_unpair(mac, name)

    def _do_unpair(self, mac: str, name: str):
        if device_state(mac).get("connected"):
            bt("disconnect", mac, timeout=20)
        out = bt("remove", mac, timeout=20)
        if "Failed" in out or "not available" in out:
            self._set_status(f"Unpair failed: {name}", error=True)
        else:
            self._set_status(f"Unpaired {name}")
            run(["notify-send", "Bluetooth", f"Unpaired {name}"])
        GLib.timeout_add(800, self._reload_and_false)
        return False

    def _reload_and_false(self):
        self._poll_busy = False
        self._reload()
        return False

    def _on_key(self, _c, keyval, _code, _state):
        if keyval == Gdk.KEY_Escape:
            for w in self.get_windows():
                w.close()
            return True
        return False


def main() -> int:
    return BluetoothPanel().run(sys.argv)


if __name__ == "__main__":
    sys.exit(main())