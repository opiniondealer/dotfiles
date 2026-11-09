pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import QtQuick
import "." as QsServices

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var connectedDevices: Bluetooth.devices.values.filter(device => device.connected)
    readonly property bool powered: adapter?.enabled ?? false
    readonly property bool connected: connectedDevices.length > 0
    readonly property string deviceName: connected ? (connectedDevices[0]?.name ?? connectedDevices[0]?.alias ?? "Device") : ""
    readonly property int connectedCount: connectedDevices.length

    // rfkill soft block: BlueZ refuses to power the adapter on while this is
    // set ("Failed to set power on: org.bluez.Error.Failed"). Quickshell's
    // adapter.enabled has no notion of it, so the switch silently did nothing.
    property bool softBlocked: false
    property bool busy: false
    property string lastError: ""

    function refreshBlockState(): void {
        rfkillCheck.running = true
    }

    function togglePower(): void {
        if (!adapter) return
        if (adapter.enabled) {
            adapter.enabled = false
            return
        }
        powerOn()
    }

    function powerOn(): void {
        if (!adapter || busy) return
        busy = true
        lastError = ""
        // /dev/rfkill is group netdev with an rw ACL for this user, so the
        // unblock needs no privilege escalation (pkexec has no TTY here).
        if (softBlocked) rfkillUnblock.running = true
        else adapter.enabled = true
    }

    Component.onCompleted: refreshBlockState()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refreshBlockState()
    }

    Process {
        id: rfkillCheck
        command: ["/usr/sbin/rfkill", "list", "bluetooth"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.softBlocked = text.includes("Soft blocked: yes")
            }
        }
    }

    Process {
        id: rfkillUnblock
        command: ["/usr/sbin/rfkill", "unblock", "bluetooth"]
        onExited: (code, status) => {
            rfkillCheck.running = true
            if (code === 0) {
                // BlueZ needs a beat before the adapter accepts a power on.
                Qt.callLater(() => {
                    if (root.adapter) root.adapter.enabled = true
                    root.busy = false
                })
            } else {
                root.lastError = "rfkill unblock failed (code " + code + ")"
                QsServices.Logger.warn("Bluetooth", root.lastError)
                root.busy = false
            }
        }
    }

    function setDiscovering(enabled: bool) {
        if (adapter)
            adapter.discovering = enabled
    }
}