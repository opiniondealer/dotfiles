import QtQuick 6.8
import QtQuick.Layouts 6.8
import QtQuick.Controls 6.8
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../../services" as QsServices
import "../../config" as QsConfig
import "../../components"
import "../../components/effects"
import "components"

PanelWindow {
    id: root

    readonly property var pywal: QsServices.Pywal
    readonly property var network: QsServices.Network
    readonly property var bluetooth: QsServices.Bluetooth
    readonly property var audio: QsServices.Audio
    readonly property var brightness: QsServices.Brightness
    readonly property var mpris: QsServices.Players
    readonly property var notifs: QsServices.Notifs
    readonly property var systemUsage: QsServices.SystemUsage
    readonly property var gamingMode: QsServices.GamingMode
    readonly property var settings: QsServices.Settings

    property bool shouldShow: false

    // Opening always starts at the top; scrollToNotifications() then moves
    // down for the bell icon. Without this the previous scroll offset was
    // kept and the header/first row were clipped on the next open.
    onShouldShowChanged: if (shouldShow) Qt.callLater(() => contentFlick.contentY = 0)

    // Called from shell.qml via IPC so the bar's notification icon can open
    // the panel scrolled to the notification list.
    function scrollToNotifications(): void {
        Qt.callLater(() => contentFlick.scrollToNotifications())
    }

    // Follow the focused monitor (fallback to first screen).
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
    
    implicitWidth: 392
    // Height follows the content, capped to the screen.
    implicitHeight: Math.min(contentColumn.implicitHeight + 16 + 14 + 16 + 8, screen.height - 40)
    color: "transparent"
    visible: shouldShow || panelContent.opacity > 0

    WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Process { id: settingsProcess; command: ["nm-connection-editor"] }
    Process { id: powerProcess; command: ["wlogout"] }
    // M3 Solid Color Tokens
    readonly property color cSurface: pywal.surface
    readonly property color cSurfaceContainer: pywal.surfaceContainer
    readonly property color cSurfaceContainerHigh: pywal.surfaceContainerHigh
    readonly property color cPrimary: pywal.primary
    readonly property color cSecondary: pywal.secondary
    readonly property color cOnSurface: pywal.foreground
    readonly property color cOnSurfaceVariant: pywal.onSurfaceMuted

    FocusScope {
        id: panelContent
        anchors.fill: parent

        transformOrigin: Item.TopRight
        scale: root.shouldShow ? 1.0 : 0.75
        opacity: root.shouldShow ? 1.0 : 0.0

        focus: true
        Keys.onEscapePressed: root.shouldShow = false

        // Auto-close only after the pointer has entered once, so opening via a
        // keyboard shortcut (pointer elsewhere) does not close it immediately.
        property bool armed: false
        onVisibleChanged: if (!root.shouldShow) armed = false

        HoverHandler {
            id: hoverHandler
            onHoveredChanged: {
                if (hovered) {
                    closeTimer.stop()
                    panelContent.armed = true
                } else if (root.shouldShow && panelContent.armed) {
                    closeTimer.restart()
                }
            }
        }

        Timer {
            id: closeTimer
            interval: 600
            onTriggered: if (!hoverHandler.hovered && panelContent.armed) root.shouldShow = false
        }

        MouseArea { anchors.fill: parent; z: -1; onClicked: root.shouldShow = false }

        Behavior on scale { NumberAnimation { duration: 350; easing.bezierCurve: Material3Anim.springBounce } }
        Behavior on opacity { NumberAnimation { duration: 200; easing.bezierCurve: Material3Anim.standard } }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 22
            color: root.cSurface
            clip: true

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 14

                // Header - M3 Expressive Typography
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        spacing: 0
                        Text {
                            id: timeText
                            text: Qt.formatTime(new Date(), "hh:mm")
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 26
                            font.weight: Font.Black
                            color: root.cOnSurface
                            lineHeight: 0.9
                        }
                        Text {
                            text: Qt.formatDate(new Date(), "dddd, MMMM d").toUpperCase()
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.Medium
                            color: root.cOnSurfaceVariant
                            font.letterSpacing: 1.5
                        }
                        Timer { interval: 1000; running: true; repeat: true; onTriggered: timeText.text = Qt.formatTime(new Date(), "hh:mm") }
                    }
                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 6

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: settingsBtnMouse.pressed ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12) : settingsBtnMouse.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            scale: settingsBtnMouse.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.bezierCurve: Material3Anim.springGentle } }

                            Text { anchors.centerIn: parent; text: "󰒓"; font.family: "Material Design Icons"; font.pixelSize: 19; color: root.cOnSurfaceVariant }
                            MouseArea { id: settingsBtnMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: settingsProcess.running = true }
                        }


                        Rectangle {
                            width: 48; height: 48; radius: 24
                            color: powerBtnMouse.pressed ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.12) : powerBtnMouse.containsMouse ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08) : "transparent"
                            Behavior on color { ColorAnimation { duration: 150 } }
                            scale: powerBtnMouse.pressed ? 0.95 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.bezierCurve: Material3Anim.springGentle } }

                            Text { anchors.centerIn: parent; text: "󰐥"; font.family: "Material Design Icons"; font.pixelSize: 19; color: root.cOnSurfaceVariant }
                            MouseArea { id: powerBtnMouse; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; hoverEnabled: true; onClicked: powerProcess.running = true }
                        }
                    }
                }

                StyledFlickable {
                    id: contentFlick
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 0
                    Layout.preferredHeight: contentColumn.implicitHeight
                    contentHeight: contentColumn.height + 8
                    clip: true

                    // Scroll straight to the notification list (bound to the
                    // notification icon in the bar).
                    function scrollToNotifications() {
                        const maxY = Math.max(0, contentHeight - height)
                        contentY = maxY
                    }

                    ColumnLayout {
                        id: contentColumn
                        width: contentFlick.width
                        spacing: 12

                        // Quick Toggles Grid
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 2
                            rowSpacing: 8
                            columnSpacing: 8

                            QuickToggle { Layout.fillWidth: true; icon: "󰖩"; label: "Wi-Fi"; subLabel: root.network.connected ? root.network.ssid : "Off"; active: root.network.wifiEnabled; activeColor: root.cPrimary; onClicked: root.network.toggleWifi() }
                            QuickToggle { Layout.fillWidth: true; icon: "󰂯"; label: "Bluetooth"; subLabel: root.bluetooth.softBlocked ? "Blocked" : (root.bluetooth.powered ? "On" : "Off"); active: root.bluetooth.powered; activeColor: root.cPrimary; onClicked: root.bluetooth.togglePower() }
                            QuickToggle { Layout.fillWidth: true; icon: "󰔎"; label: "Do Not Disturb"; subLabel: root.notifs.dnd ? "On" : "Off"; active: root.notifs.dnd; activeColor: pywal.warning; onClicked: root.notifs.toggleDnd() }
                            QuickToggle { Layout.fillWidth: true; icon: "󰾴"; label: "Gaming Mode"; subLabel: root.gamingMode.enabled ? "Performance" : "Balanced"; active: root.gamingMode.enabled; activeColor: pywal.success; onClicked: root.gamingMode.toggle() }
                        }

                        // Sliders Container
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            VolumeSlider { Layout.fillWidth: true; audio: root.audio; pywal: root.pywal }
                            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.05) }
                            BrightnessSlider { Layout.fillWidth: true; brightness: root.brightness; pywal: root.pywal }
                        }

                        SystemStats { Layout.fillWidth: true; systemUsage: root.systemUsage; pywal: root.pywal }
                        MediaCard { Layout.fillWidth: true; mpris: root.mpris; pywal: root.pywal }
                        NotificationList { Layout.fillWidth: true; notifs: root.notifs; pywal: root.pywal }

                        Item { Layout.preferredHeight: 4 }
                    }
                }
            }
        }
    }
}
