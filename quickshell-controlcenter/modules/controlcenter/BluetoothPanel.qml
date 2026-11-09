// Bluetooth popup panel: adapter power, scan, device list, settings.
// Separate PanelWindow so it can be anchored under the bar's bluetooth icon
// without touching the Control Center window. Toggled over IPC:
//   quickshell ipc -p ~/.config/quickshell-controlcenter call bluetooth toggle

import QtQuick 6.8
import QtQuick.Layouts 6.8
import Quickshell
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Io
import "../../services" as QsServices
import "../../components/effects"

PanelWindow {
    id: root

    readonly property var pywal: QsServices.Pywal
    readonly property var bluetooth: QsServices.Bluetooth
    readonly property var adapter: Bluetooth.defaultAdapter

    // Connected first, then paired, then by name.
    readonly property var devices: [...Bluetooth.devices.values].sort((a, b) => {
        if (a.connected !== b.connected) return b.connected - a.connected
        if (a.bonded !== b.bonded) return b.bonded - a.bonded
        return (a.name ?? "").localeCompare(b.name ?? "")
    })

    readonly property color cSurface: pywal.surface
    readonly property color cSurfaceContainer: pywal.surfaceContainer
    readonly property color cSurfaceContainerHigh: pywal.surfaceContainerHigh
    readonly property color cPrimary: pywal.primary
    readonly property color cOnSurface: pywal.foreground
    readonly property color cOnSurfaceVariant: pywal.onSurfaceMuted

    property bool shouldShow: false

    screen: {
        const fm = QsServices.Hypr.focusedMonitor
        if (fm) {
            for (const s of Quickshell.screens)
                if (s.name === fm.name) return s
        }
        return Quickshell.screens[0]
    }

    anchors { top: true; right: true }
    margins { right: 12; top: 12 }

    implicitWidth: 344
    implicitHeight: content.implicitHeight + 32
    color: "transparent"
    visible: shouldShow || panel.opacity > 0

    WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Process {
        id: settingsProcess
        command: ["blueman-manager"]
        onStarted: root.shouldShow = false
    }

    function toggle(): void { root.shouldShow = !root.shouldShow }

    FocusScope {
        id: panelContent
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.shouldShow = false

        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (hovered) closeTimer.stop()
                else if (root.shouldShow) closeTimer.restart()
            }
        }

        Timer {
            id: closeTimer
            interval: 400
            onTriggered: if (!hoverHandler.hovered) root.shouldShow = false
        }

        // Click outside closes.
        MouseArea { anchors.fill: parent; z: -1; onClicked: root.shouldShow = false }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 22
            color: root.cSurface
            opacity: root.shouldShow ? 1.0 : 0.0
            scale: root.shouldShow ? 1.0 : 0.92
            transformOrigin: Item.TopRight

            Behavior on opacity { NumberAnimation { duration: 180; easing.bezierCurve: Material3Anim.standard } }
            Behavior on scale { NumberAnimation { duration: 260; easing.bezierCurve: Material3Anim.springBounce } }

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            ColumnLayout {
                id: content
                width: parent.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 16
                spacing: 12

                // ---- Header: icon + title + connected device + toggle ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        radius: 12
                        color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.15)

                        Text {
                            anchors.centerIn: parent
                            text: "󰂯"
                            font.family: "Material Design Icons"
                            font.pixelSize: 18
                            color: root.cPrimary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "Bluetooth"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: root.cOnSurface
                        }

                        Text {
                            readonly property var connected: root.devices.filter(d => d.connected)
                            text: {
                                if (root.bluetooth.softBlocked) return "Blocked by rfkill"
                                if (connected.length > 0)
                                    return connected[0].name ?? connected[0].alias ?? "Device"
                                return root.adapter?.enabled ? "No device connected" : "Bluetooth off"
                            }
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: root.cOnSurfaceVariant
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // M3 switch
                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 24
                        radius: 12
                        color: root.adapter?.enabled
                            ? root.cPrimary
                            : Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.adapter?.enabled ? parent.width - width - 3 : 3
                            color: "#ffffff"
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bluetooth.togglePower()
                        }
                    }
                }

                // ---- Scan button ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 12
                    color: scanArea.pressed
                        ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12)
                        : scanArea.containsMouse
                            ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                            : root.cSurfaceContainer
                    Behavior on color { ColorAnimation { duration: 150 } }
                    opacity: root.adapter?.enabled ?? false ? 1.0 : 0.45

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: root.adapter?.discovering ? "󰑐" : "󰑓"
                            font.family: "Material Design Icons"
                            font.pixelSize: 16
                            color: root.adapter?.discovering ? root.cPrimary : root.cOnSurface

                            RotationAnimation on rotation {
                                running: root.adapter?.discovering ?? false
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                            }
                        }

                        Text {
                            text: root.adapter?.discovering ? "Scanning..." : "Scan for devices"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: root.cOnSurface
                        }
                    }

                    MouseArea {
                        id: scanArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.adapter) root.adapter.discovering = !root.adapter.discovering
                    }
                }

                // ---- Device list ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.devices.length > 0
                        ? Math.min(deviceList.contentHeight + 8, 260)
                        : 96
                    radius: 16
                    color: root.cSurfaceContainerHigh
                    clip: true

                    ListView {
                        id: deviceList
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2
                        model: root.devices
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: deviceItem
                            required property var modelData
                            readonly property bool isConnected: modelData.connected

                            width: deviceList.width
                            height: 52
                            radius: 12
                            color: itemArea.pressed
                                ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12)
                                : itemArea.containsMouse
                                    ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                                    : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10

                                Text {
                                    text: {
                                        const icon = deviceItem.modelData.icon || ""
                                        if (icon.includes("audio")) return "󰋋"
                                        if (icon.includes("phone")) return "󰄜"
                                        if (icon.includes("computer")) return "󰌢"
                                        if (icon.includes("mouse")) return "󰍽"
                                        if (icon.includes("keyboard")) return "󰌌"
                                        return "󰂯"
                                    }
                                    font.family: "Material Design Icons"
                                    font.pixelSize: 18
                                    color: deviceItem.isConnected ? root.cPrimary : root.cOnSurfaceVariant
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        Layout.fillWidth: true
                                        text: deviceItem.modelData.name ?? deviceItem.modelData.address ?? "Unknown"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 12
                                        font.weight: Font.Medium
                                        color: root.cOnSurface
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        text: {
                                            if (deviceItem.modelData.state === BluetoothDeviceState.Connecting) return "Connecting..."
                                            if (deviceItem.isConnected) return "Connected"
                                            if (deviceItem.modelData.state === BluetoothDeviceState.Disconnecting) return "Disconnecting..."
                                            if (deviceItem.modelData.bonded) return "Paired"
                                            return "Available"
                                        }
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: deviceItem.isConnected ? root.cPrimary : root.cOnSurfaceVariant
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    radius: 14
                                    color: actionArea.pressed
                                        ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.15)
                                        : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: deviceItem.isConnected ? "󰌊" : "󰌘"
                                        font.family: "Material Design Icons"
                                        font.pixelSize: 14
                                        color: deviceItem.isConnected ? root.cPrimary : root.cOnSurfaceVariant
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            const d = deviceItem.modelData
                                            if (d.connected) d.disconnect()
                                            else d.connect()
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                z: -1
                            }
                        }
                    }

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: root.devices.length === 0
                        spacing: 6

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰂲"
                            font.family: "Material Design Icons"
                            font.pixelSize: 32
                            color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.2)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.adapter?.enabled ? "No devices found" : "Bluetooth disabled"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: root.cOnSurfaceVariant
                        }
                    }
                }

                // ---- Footer: settings ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 12
                    color: settingsArea.pressed
                        ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12)
                        : settingsArea.containsMouse
                            ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                            : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            text: "󰒓"
                            font.family: "Material Design Icons"
                            font.pixelSize: 14
                            color: root.cOnSurfaceVariant
                        }

                        Text {
                            text: "Bluetooth Settings"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: root.cOnSurfaceVariant
                        }
                    }

                    MouseArea {
                        id: settingsArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: settingsProcess.running = true
                    }
                }
            }
        }
    }
}