// Calendar popup: month view anchored under the Waybar clock.
// Layout mirrors the old GTK panel: month name big on the left, year muted on
// the right, weekday header row, 7-column day grid starting Monday. Today is
// accented and underlined; days from adjacent months are dimmed but real.
//   quickshell ipc -p ~/.config/quickshell-controlcenter call calendar toggle

import QtQuick 6.8
import QtQuick.Layouts 6.8
import Quickshell
import Quickshell.Wayland
import "../../services" as QsServices
import "../../components/effects"

PanelWindow {
    id: root

    readonly property var pywal: QsServices.Pywal

    readonly property color cSurface: pywal.surface
    readonly property color cPrimary: pywal.primary
    readonly property color cOnSurface: pywal.foreground
    readonly property color cOnSurfaceVariant: pywal.onSurfaceMuted
    readonly property color cDim: "#4a4a4a"

    property bool shouldShow: false

    // --- calendar state -----------------------------------------------------
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth() // 0-based

    readonly property var monthNames: [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ]
    readonly property var weekdayNames: ["MO", "TU", "WE", "TH", "FR", "SA", "SU"]

    // Monday-first grid covering the whole month plus adjacent filler days.
    readonly property var weeks: {
        const y = viewYear, m = viewMonth
        const first = new Date(y, m, 1)
        // JS: Sunday=0. Convert to Monday=0 index.
        const lead = (first.getDay() + 6) % 7
        const daysInMonth = new Date(y, m + 1, 0).getDate()
        const cells = []
        // leading filler from the previous month
        for (let i = lead; i > 0; i--) {
            const d = new Date(y, m, 1 - i)
            cells.push({ day: d.getDate(), other: true })
        }
        for (let d = 1; d <= daysInMonth; d++)
            cells.push({ day: d, other: false })
        // trailing filler to complete the last week
        let next = 1
        while (cells.length % 7 !== 0)
            cells.push({ day: next++, other: true })

        const out = []
        for (let i = 0; i < cells.length; i += 7)
            out.push(cells.slice(i, i + 7))
        return out
    }

    // True when this populated cell is the real current date.
    function cellIsToday(cell) {
        if (!cell || cell.other) return false
        const now = new Date()
        return viewYear === now.getFullYear()
            && viewMonth === now.getMonth()
            && cell.day === now.getDate()
    }

    function shiftMonth(delta) {
        let m = viewMonth + delta
        let y = viewYear
        while (m < 0) { m += 12; y -= 1 }
        while (m > 11) { m -= 12; y += 1 }
        viewMonth = m
        viewYear = y
    }

    function goToday() {
        const now = new Date()
        viewYear = now.getFullYear()
        viewMonth = now.getMonth()
    }

    function toggle(): void {
        root.shouldShow = !root.shouldShow
        if (root.shouldShow) root.goToday()
    }

    // --- window -------------------------------------------------------------
    screen: {
        const fm = QsServices.Hypr.focusedMonitor
        if (fm) {
            for (const s of Quickshell.screens)
                if (s.name === fm.name) return s
        }
        return Quickshell.screens[0]
    }

    anchors { top: true; left: true }
    margins { left: 12; top: 12 }

    implicitWidth: 360
    // top 18 + bottom 18 + a little slack so the rounded corners
    // do not clip the last row
    implicitHeight: content.implicitHeight + 44
    color: "transparent"
    visible: shouldShow || panel.opacity > 0

    WlrLayershell.keyboardFocus: shouldShow ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    FocusScope {
        id: panelContent
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: root.shouldShow = false
        Keys.onLeftPressed: root.shiftMonth(-1)
        Keys.onRightPressed: root.shiftMonth(1)
        // Qt has no Keys.onHomePressed; Home means "jump to today" here.
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Home) {
                root.goToday()
                event.accepted = true
            }
        }

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

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: root.shouldShow = false
        }

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: 22
            color: root.cSurface
            opacity: root.shouldShow ? 1.0 : 0.0
            scale: root.shouldShow ? 1.0 : 0.92
            transformOrigin: Item.TopLeft

            Behavior on opacity { NumberAnimation { duration: 180; easing.bezierCurve: Material3Anim.standard } }
            Behavior on scale { NumberAnimation { duration: 260; easing.bezierCurve: Material3Anim.springBounce } }

            MouseArea { anchors.fill: parent; onClicked: (mouse) => mouse.accepted = true }

            WheelHandler {
                onWheel: (event) => root.shiftMonth(event.angleDelta.y > 0 ? -1 : 1)
            }

            ColumnLayout {
                id: content
                width: parent.width - 36
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: 18
                spacing: 10

                // ---- Year, right aligned like the print layout ----
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: root.viewYear
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    color: root.cOnSurfaceVariant
                }

                // ---- Nav row: prev | MONTH | next ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 26
                        radius: 7
                        color: prevArea.containsMouse
                            ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.10)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅁"
                            font.family: "Material Design Icons"
                            font.pixelSize: 20
                            color: prevArea.containsMouse ? root.cOnSurface : root.cOnSurfaceVariant
                        }

                        MouseArea {
                            id: prevArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(-1)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: root.monthNames[root.viewMonth]
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 17
                        font.weight: Font.Bold
                        font.letterSpacing: 1
                        color: root.cOnSurface
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 26
                        radius: 7
                        color: nextArea.containsMouse
                            ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.10)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰅂"
                            font.family: "Material Design Icons"
                            font.pixelSize: 20
                            color: nextArea.containsMouse ? root.cOnSurface : root.cOnSurfaceVariant
                        }

                        MouseArea {
                            id: nextArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                // ---- Weekday header ----
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.weekdayNames

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            color: modelData === "SU" ? root.cPrimary : root.cOnSurface
                        }
                    }
                }

                // ---- Day grid ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: root.weeks

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Repeater {
                                model: modelData

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 28

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.day
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 13
                                        font.weight: root.cellIsToday(modelData) ? Font.Bold : Font.Normal
                                        font.underline: root.cellIsToday(modelData)
                                        color: root.cellIsToday(modelData)
                                            ? root.cPrimary
                                            : (modelData.other ? root.cDim : root.cOnSurface)
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- Jump to today ----
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
                    radius: 9
                    color: todayArea.containsMouse
                        ? Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.14)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Today"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: todayArea.containsMouse ? root.cPrimary : root.cOnSurfaceVariant
                    }

                    MouseArea {
                        id: todayArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToday()
                    }
                }
            }
        }
    }
}