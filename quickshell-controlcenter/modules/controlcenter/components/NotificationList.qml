import QtQuick 6.8
import QtQuick.Layouts 6.8
import QtQuick.Controls 6.8
import Quickshell
import "../../../components"
import "../../../components/effects"

// Notification list with a deterministic height.
//
// Why not just let it grow: the panel's own height is derived from its
// content, and a list whose height is derived from its content (ListView
// height <-> contentHeight, or a Layout's implicitHeight) makes that binding
// circular. Qt then reports a stale height and the panel clips the last card.
//
// So the list gets a fixed, bounded height here and scrolls internally.
// The panel can then size itself from that constant.
Item {
    id: root

    required property var notifs
    property var pywal

    readonly property color cSurfaceContainer: pywal ? pywal.surfaceContainer : "#111111"
    readonly property color cSurfaceContainerHigh: pywal ? pywal.surfaceContainerHigh : "#1a1a1a"
    readonly property color cOnSurface: pywal ? pywal.foreground : "#dddddd"
    readonly property color cOnSurfaceVariant: pywal ? pywal.onSurfaceMuted : "#999999"
    readonly property color cPrimary: pywal ? pywal.primary : "#91c5ff"

    readonly property int headerHeight: 24
    readonly property int cardSpacing: 8
    // Empty state gets room to breathe: the panel used to collapse to ~64px
    // of body, which read as "cramped" rather than intentional.
    readonly property int emptyHeight: 168

    // Scroll after this many pixels of cards (~3 cards).
    readonly property int maxListHeight: 240

    readonly property int count: notifs.recentNotifications?.length ?? 0

    // ListView.contentHeight is the sum of the delegate heights; it does not
    // depend on the view's own height, so this is not a circular binding.
    // The ListView always gets a constant height (maxListHeight) so its
    // contentHeight is well defined; the body box then shrinks to the real
    // content. Sizing the ListView from bodyHeight would be circular.
    readonly property int bodyHeight: count > 0
        ? Math.min(Math.max(listView.contentHeight, 1), maxListHeight)
        : emptyHeight

    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    implicitHeight: 16 + headerHeight + 10 + bodyHeight + 16

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: root.cSurfaceContainer
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        // ---- header ----
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: root.headerHeight
            spacing: 8

            Text {
                text: "Notifications"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 12
                font.weight: Font.Bold
                color: root.cOnSurface
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                visible: root.count > 0
                Layout.preferredWidth: clearAllText.implicitWidth + 20
                Layout.preferredHeight: 26
                radius: 13
                color: clearAllMouse.containsMouse
                       ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                       : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    id: clearAllText
                    anchors.centerIn: parent
                    text: "Clear All"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.weight: Font.Medium
                    color: root.cOnSurfaceVariant
                }

                MouseArea {
                    id: clearAllMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: root.notifs.clearAll()
                }
            }
        }

        // ---- body: exact height, no content-derived sizing ----
        Item {
            id: body
            Layout.fillWidth: true
            Layout.preferredHeight: root.bodyHeight
            clip: true

            ListView {
                id: listView
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.maxListHeight
                visible: root.count > 0
                clip: true
                spacing: root.cardSpacing
                model: root.notifs.recentNotifications ?? []

                ScrollBar.vertical: ScrollBar {
                    policy: root.count > 3 ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
                }

                delegate: Rectangle {
                    id: notifDelegate
                    required property var modelData

                    width: ListView.view.width
                    height: cardItem.implicitHeight + 16
                    radius: 14
                    color: notifMouse.containsMouse
                           ? Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.08)
                           : root.cSurfaceContainerHigh
                    Behavior on color { ColorAnimation { duration: 150 } }

                    MouseArea {
                        id: notifMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (notifDelegate.modelData.actions?.length > 0)
                            notifDelegate.modelData.actions[0].invoke()
                    }

                    NotificationCard {
                        id: cardItem
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        anchors.topMargin: 8
                        height: implicitHeight
                        notification: notifDelegate.modelData
                        pywal: root.pywal
                        showCloseButton: true
                        showTimestamp: false
                        showActions: false
                        showBody: true
                        showAppIcon: false

                        primaryColor: root.cPrimary
                        onSurfaceColor: root.cOnSurface
                        onSurfaceVariantColor: root.cOnSurfaceVariant
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                visible: root.count === 0
                spacing: 6

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰂚"
                    font.family: "Material Design Icons"
                    font.pixelSize: 34
                    color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.14)
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "No Notifications"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    color: Qt.rgba(root.cOnSurface.r, root.cOnSurface.g, root.cOnSurface.b, 0.4)
                }
            }
        }
    }
}