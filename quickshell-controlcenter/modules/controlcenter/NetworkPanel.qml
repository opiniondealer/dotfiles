// WiFi popup panel: adapter toggle, scan, network list, connect/disconnect,
// and a password dialog for unsaved secured networks. Hover auto-close is
// suppressed while the dialog is open, and Escape closes the dialog first.
//   quickshell ipc -p ~/.config/quickshell-controlcenter call network toggle

import QtQuick 6.8
import QtQuick.Layouts 6.8
import QtQuick.Controls 6.8
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../services" as QsServices
import "../../components/effects"

PanelWindow {
    id: root

    readonly property var pywal: QsServices.Pywal
    readonly property var network: QsServices.Network

    // Active network first, then signal strength desc.
    readonly property var sortedNetworks: [...network.networks].sort((a, b) => {
        if (a.active !== b.active) return b.active - a.active
        return b.strength - a.strength
    })

    readonly property color cSurface: pywal.surface
    readonly property color cSurfaceContainer: pywal.surfaceContainer
    readonly property color cSurfaceContainerHigh: pywal.surfaceContainerHigh
    readonly property color cPrimary: pywal.primary
    readonly property color cOnSurface: pywal.foreground
    readonly property color cOnSurfaceVariant: pywal.onSurfaceMuted

    property bool shouldShow: false
    property bool passwordOpen: false

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
        command: ["nm-connection-editor"]
        onStarted: root.shouldShow = false
    }

    function toggle(): void {
        root.shouldShow = !root.shouldShow
        if (root.shouldShow) root.network.rescanWifi()
    }

    FocusScope {
        id: panelContent
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            if (passwordDialog.isOpen) passwordDialog.close()
            else root.shouldShow = false
        }

        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (hovered) closeTimer.stop()
                else if (root.shouldShow && !root.passwordOpen) closeTimer.restart()
            }
        }

        Timer {
            id: closeTimer
            interval: 400
            onTriggered: if (!hoverHandler.hovered && !root.passwordOpen) root.shouldShow = false
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: {
                if (passwordDialog.isOpen) passwordDialog.close()
                else root.shouldShow = false
            }
        }

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

                // ---- Header ----
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
                            text: "󰖩"
                            font.family: "Material Design Icons"
                            font.pixelSize: 18
                            color: root.cPrimary
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: "WiFi Networks"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 15
                            font.weight: Font.Bold
                            color: root.cOnSurface
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.network.active ? root.network.active.ssid
                                : (root.network.wifiEnabled ? "Not connected" : "WiFi off")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                            color: root.cOnSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 44
                        Layout.preferredHeight: 24
                        radius: 12
                        color: root.network.wifiEnabled
                            ? root.cPrimary
                            : Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.15)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Rectangle {
                            width: 18; height: 18; radius: 9
                            anchors.verticalCenter: parent.verticalCenter
                            x: root.network.wifiEnabled ? parent.width - width - 3 : 3
                            color: "#ffffff"
                            Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.network.toggleWifi()
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
                    opacity: root.network.wifiEnabled ? 1.0 : 0.45

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            text: root.network.scanning ? "󰑐" : "󰑓"
                            font.family: "Material Design Icons"
                            font.pixelSize: 16
                            color: root.network.scanning ? root.cPrimary : root.cOnSurface

                            RotationAnimation on rotation {
                                running: root.network.scanning
                                from: 0; to: 360; duration: 1000; loops: Animation.Infinite
                            }
                        }

                        Text {
                            text: root.network.scanning ? "Scanning..." : "Scan networks"
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
                        enabled: root.network.wifiEnabled
                        onClicked: root.network.rescanWifi()
                    }
                }

                // ---- Network list ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.sortedNetworks.length > 0
                        ? Math.min(networkList.contentHeight + 8, 280)
                        : 96
                    radius: 16
                    color: root.cSurfaceContainerHigh
                    clip: true

                    ListView {
                        id: networkList
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2
                        model: root.sortedNetworks
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        delegate: Rectangle {
                            id: netItem
                            required property var modelData
                            readonly property bool isActive: modelData.active
                            readonly property string ssid: modelData.ssid
                            readonly property bool isSaved: root.network.isNetworkSaved(ssid)

                            // Row click never disconnects: clicking the network
                            // you are already on must not drop your session.
                            // Only the explicit action button tears it down.
                            function activate(): void {
                                if (isActive) return
                                if (isSaved || !modelData.isSecure) {
                                    root.network.connectToNetwork(ssid, "")
                                } else {
                                    passwordDialog.networkSSID = ssid
                                    passwordDialog.open()
                                }
                            }

                            // Action button: also handles disconnect.
                            function activateOrDisconnect(): void {
                                if (isActive) root.network.disconnectFromNetwork()
                                else activate()
                            }

                            width: networkList.width
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
                                        const s = netItem.modelData.strength
                                        if (s >= 75) return "󰤨"
                                        if (s >= 50) return "󰤥"
                                        if (s >= 25) return "󰤢"
                                        return "󰤟"
                                    }
                                    font.family: "Material Design Icons"
                                    font.pixelSize: 18
                                    color: netItem.isActive ? root.cPrimary : root.cOnSurfaceVariant
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            Layout.fillWidth: true
                                            text: netItem.ssid
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            font.weight: Font.Medium
                                            color: root.cOnSurface
                                            elide: Text.ElideRight
                                        }

                                    }

                                    Text {
                                        text: {
                                            if (netItem.isActive) return "Connected"
                                            if (netItem.isSaved) return "Saved · " + netItem.modelData.strength + "%"
                                            if (netItem.modelData.isSecure) return "Tap to connect"
                                            return netItem.modelData.strength + "%"
                                        }
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                        color: netItem.isActive ? root.cPrimary : root.cOnSurfaceVariant
                                    }
                                }

                                Text {
                                    visible: netItem.modelData.isSecure
                                    Layout.preferredWidth: 12
                                    Layout.alignment: Qt.AlignVCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: "󰌾"
                                    font.family: "Material Design Icons"
                                    font.pixelSize: 11
                                    color: root.cOnSurfaceVariant
                                    opacity: 0.7
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
                                        text: netItem.isActive ? "󰌊" : "󰌘"
                                        font.family: "Material Design Icons"
                                        font.pixelSize: 14
                                        color: netItem.isActive ? root.cPrimary : root.cOnSurfaceVariant
                                    }

                                    MouseArea {
                                        id: actionArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: netItem.activateOrDisconnect()
                                    }
                                }
                            }

                            // z: -1 keeps this behind the action button so the
                            // button keeps its own hover feedback; clicks pass
                            // down through the non-interactive label items.
                            MouseArea {
                                id: itemArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                z: -1
                                onClicked: netItem.activate()
                            }
                        }
                    }

                    // Empty state
                    ColumnLayout {
                        anchors.centerIn: parent
                        visible: root.sortedNetworks.length === 0
                        spacing: 6

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "󰖪"
                            font.family: "Material Design Icons"
                            font.pixelSize: 32
                            color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.2)
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.network.wifiEnabled ? "No networks found" : "WiFi disabled"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: root.cOnSurfaceVariant
                        }
                    }
                }

                // ---- Footer ----
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
                            text: "Network Settings"
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

    // ---- Password dialog (phase 2) ----
    // Sits above the panel. While open, hover auto-close is suppressed and a
    // backdrop click dismisses only the dialog, never the whole panel.
    Item {
        id: passwordDialog
        anchors.fill: parent
        z: 100
        property string networkSSID: ""
        property bool isOpen: false

        visible: opacity > 0
        opacity: isOpen ? 1.0 : 0.0

        function open() {
            isOpen = true
            root.passwordOpen = true
            passwordInput.text = ""
            passwordInput.forceActiveFocus()
        }

        function close() {
            isOpen = false
            root.passwordOpen = false
            passwordInput.text = ""
        }

        Behavior on opacity { NumberAnimation { duration: 140 } }

        Rectangle {
            anchors.fill: parent
            radius: 22
            color: Qt.rgba(0, 0, 0, 0.55)

            MouseArea { anchors.fill: parent; onClicked: passwordDialog.close() }
        }

        Rectangle {
            id: dialogCard
            anchors.centerIn: parent
            width: parent.width - 64
            height: dialogColumn.implicitHeight + 40
            radius: 20
            color: root.cSurfaceContainerHigh
            scale: passwordDialog.isOpen ? 1.0 : 0.92
            Behavior on scale { NumberAnimation { duration: 200; easing.bezierCurve: Material3Anim.springBounce } }

            // Swallow clicks so the backdrop handler above never sees them.
            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: dialogColumn
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "Enter password"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: root.cOnSurface
                }

                Text {
                    Layout.fillWidth: true
                    text: passwordDialog.networkSSID
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: root.cOnSurfaceVariant
                    elide: Text.ElideRight
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 12
                    color: root.cSurfaceContainer
                    border.width: 1
                    border.color: passwordInput.activeFocus ? root.cPrimary : "transparent"

                    TextField {
                        id: passwordInput
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        placeholderText: "Password"
                        placeholderTextColor: Qt.rgba(root.cOnSurfaceVariant.r, root.cOnSurfaceVariant.g, root.cOnSurfaceVariant.b, 0.6)
                        echoMode: TextInput.Password
                        color: root.cOnSurface
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        background: Item {}

                        onAccepted: {
                            if (text.length > 0) {
                                root.network.connectToNetwork(passwordDialog.networkSSID, text)
                                passwordDialog.close()
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item { Layout.fillWidth: true }

                    Rectangle {
                        Layout.preferredWidth: 76
                        Layout.preferredHeight: 32
                        radius: 16
                        color: cancelBtn.pressed
                            ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12)
                            : cancelBtn.containsMouse
                                ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                                : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            color: root.cOnSurface
                        }

                        MouseArea {
                            id: cancelBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: passwordDialog.close()
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 88
                        Layout.preferredHeight: 32
                        radius: 16
                        color: passwordInput.text.length > 0
                            ? root.cPrimary
                            : Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.35)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Connect"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: passwordInput.text.length > 0 ? "#0e0e0e" : Qt.rgba(0.05, 0.05, 0.05, 0.5)
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: passwordInput.text.length > 0
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.network.connectToNetwork(passwordDialog.networkSSID, passwordInput.text)
                                passwordDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
