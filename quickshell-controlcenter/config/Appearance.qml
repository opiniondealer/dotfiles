pragma Singleton

import Quickshell

// Self-contained design tokens. The upstream version read
// Config.appearance.rounding/spacing/padding/font/anim/transparency, none of
// which exist in shell.json, which made the whole type fail to load.
Singleton {
    readonly property var rounding: ({
        small: 8,
        normal: 12,
        large: 18,
        full: 9999
    })

    readonly property var spacing: ({
        xs: 4,
        small: 8,
        normal: 12,
        large: 16,
        xl: 24
    })

    readonly property var padding: ({
        small: 8,
        normal: 12,
        large: 16
    })

    readonly property var font: ({
        family: "JetBrainsMono Nerd Font",
        iconFamily: "Material Design Icons",
        body: 12,
        label: 10,
        title: 13,
        display: 30
    })

    readonly property var anim: ({
        durations: {
            short: 120,
            normal: 200,
            long: 320
        },
        curves: {
            standard: [0.2, 0, 0, 1],
            emphasized: [0.05, 0.7, 0.1, 1]
        }
    })

    readonly property var transparency: ({
        surface: 1.0,
        overlay: 0.5
    })
}
