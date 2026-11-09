// Minimal shell: Control Center only.
// Trigger: quickshell ipc call controlcenter toggle
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QSG_RENDER_LOOP=threaded
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Io
import QtQuick
import "services" as QsServices
import "config" as QsConfig
import "modules/controlcenter"

ShellRoot {
    id: root

    readonly property var notifs: QsServices.Notifs
    readonly property var pywal: QsServices.Pywal

    // Register as notification daemon so NotificationList has content.
    // Set "notifications": {"registerServer": false} in shell.json to disable.
    Loader {
        active: QsConfig.Config.notifications.registerServer
        sourceComponent: NotificationServer {
            keepOnReload: false
            actionsSupported: true
            bodyHyperlinksSupported: true
            bodyMarkupSupported: true
            imageSupported: true
            persistenceSupported: true

            onNotification: notif => {
                notif.tracked = true
                QsServices.Notifs.addNotification(notif)
            }
        }
    }

    ControlCenterWindow {
        id: cc

        // IPC: quickshell ipc call controlcenter toggle|open|close
        IpcHandler {
            target: "controlcenter"

            function toggle(): void { cc.shouldShow = !cc.shouldShow }
            function open(): void { cc.shouldShow = true }
            function close(): void { cc.shouldShow = false }

            // Clear every notification (same as the "Clear All" button).
            function clearAllNotifications(): void { QsServices.Notifs.clearAll() }

            // Open the panel and jump to the notification list.
            function notifications(): void {
                cc.shouldShow = true
                cc.scrollToNotifications()
            }

            // From the bar: if already open, close it; else open at notifications.
            function toggleNotifications(): void {
                if (cc.shouldShow) {
                    cc.shouldShow = false
                } else {
                    cc.shouldShow = true
                    cc.scrollToNotifications()
                }
            }
        }
    }

    BluetoothPanel {
        id: bt

        IpcHandler {
            target: "bluetooth"

            function toggle(): void { bt.toggle() }
            function open(): void { bt.shouldShow = true }
            function close(): void { bt.shouldShow = false }
        }
    }

    NetworkPanel {
        id: net

        IpcHandler {
            target: "network"

            function toggle(): void { net.toggle() }
            function open(): void { net.shouldShow = true; QsServices.Network.rescanWifi() }
            function close(): void { net.shouldShow = false }
        }
    }

    Component.onCompleted: QsServices.Logger.info("Shell", "Control Center shell loaded")
}