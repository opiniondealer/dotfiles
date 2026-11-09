pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick 6.8
import "../config" as QsConfig
import "." as QsServices

Singleton {
    id: root
    
    // === Serialchiller palette (waybar/themes/Serialchiller.css) ===========
    // Panel colors follow the waybar theme instead of the wallpaper. pgrep
    // old pywal palette is kept below but is no longer referenced: the
    // FileView loader at the bottom of this file is disabled.
    //   bg #171717 · card #0e0e0e · fg #fafafa · border #262626
    //   accent sc-chart1 #91c5ff · sc-chart2 #3a81f6 · sc-destructive #ff6467
    readonly property color scBg: "#171717"
    readonly property color scCard: "#0e0e0e"
    readonly property color scFg: "#fafafa"
    readonly property color scMutedFg: "#a1a1a1"
    readonly property color scBorder: "#262626"
    readonly property color scMuted: "#262626"
    readonly property color scAccent: "#404040"
    readonly property color scChart1: "#91c5ff"
    readonly property color scChart2: "#3a81f6"
    readonly property color scChart3: "#2563ef"
    readonly property color scChart4: "#1a4eda"
    readonly property color scChart5: "#1f3fad"
    readonly property color scDestructive: "#ff6467"
    readonly property color scRing: "#737373"

    property color background: root.scBg
    property color foreground: root.scFg
    property color cursor: root.scFg

    property color color0: root.scCard
    property color color1: root.scDestructive
    property color color2: root.scChart1
    property color color3: root.scChart2
    property color color4: root.scChart2
    property color color5: root.scChart3
    property color color6: root.scChart4
    property color color7: root.scFg
    property color color8: root.scMutedFg
    property color color9: root.scDestructive
    property color color10: root.scChart1
    property color color11: root.scDestructive
    property color color12: root.scChart2
    property color color13: root.scChart3
    property color color14: root.scChart4
    property color color15: root.scFg
    
    // === Semantic Color Tokens ===
    // Use these instead of hardcoded colors for consistency
    
    // Primary accent color (derived from pywal)
    readonly property color primary: root.scChart1
    readonly property color primaryContainer: Qt.rgba(color4.r, color4.g, color4.b, 0.2)
    readonly property color onPrimary: foreground
    
    // Secondary accent
    readonly property color secondary: root.scChart2
    readonly property color secondaryContainer: Qt.rgba(color5.r, color5.g, color5.b, 0.2)
    
    // Tertiary accent
    readonly property color tertiary: root.scChart3
    readonly property color tertiaryContainer: Qt.rgba(color6.r, color6.g, color6.b, 0.2)
    
    // Surface colors (Serialchiller: flat neutral cards, not wallpaper-derived)
    readonly property color surface: root.scBg
    readonly property color surfaceDim: "#0e0e0e"
    readonly property color surfaceBright: "#262626"
    readonly property color surfaceContainer: root.scCard
    readonly property color surfaceContainerLow: root.scCard
    readonly property color surfaceContainerHigh: root.scMuted
    readonly property color surfaceContainerHighest: root.scAccent
    readonly property color onSurface: root.scFg
    readonly property color onSurfaceVariant: root.scMutedFg
    readonly property color onSurfaceMuted: Qt.rgba(root.scFg.r, root.scFg.g, root.scFg.b, 0.68)

    // Compatibility aliases kept for existing components now mapped to solid surfaces
    readonly property color glassLow: surfaceContainerLow
    readonly property color glassHigh: surfaceContainerHigh
    readonly property color glassHighest: surfaceContainerHighest
    readonly property color glassBorder: outlineVariant
    readonly property color glassBorderStrong: Qt.rgba(primary.r, primary.g, primary.b, 0.28)
    
    // Outline colors
    readonly property color outline: color8
    readonly property color outlineVariant: Qt.rgba(color8.r, color8.g, color8.b, 0.5)
    
    // State colors
    readonly property color success: root.scChart1 // blue (palette has no green)
    readonly property color onSuccess: background
    readonly property color warning: root.scChart2 // was orange; panel is blue-only
    readonly property color onWarning: background
    readonly property color error: root.scDestructive // Red
    readonly property color onError: foreground
    readonly property color info: root.scChart1   // Blue-ish accent
    
    // Interactive state overlays
    readonly property color stateLayerLight: Qt.rgba(foreground.r, foreground.g, foreground.b, 1)
    readonly property color stateLayerDark: Qt.rgba(background.r, background.g, background.b, 1)
    
    // Inverse colors (for contrast situations)
    readonly property color inverseSurface: foreground
    readonly property color inverseOnSurface: background
    readonly property color inversePrimary: Qt.lighter(primary, 1.5)
    
    // Scrim (overlay for modals)
    readonly property color scrim: Qt.rgba(0, 0, 0, 0.5)
    
    // Shadow color
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.3)
    
    function loadColors(text: string): void {
        try {
            const data = JSON.parse(text);
            if (data.special) {
                root.background = data.special.background || root.background;
                root.foreground = data.special.foreground || root.foreground;
                root.cursor = data.special.cursor || root.cursor;
            }
            if (data.colors) {
                // Load individual colors
                if (data.colors.color0) root.color0 = data.colors.color0;
                if (data.colors.color1) root.color1 = data.colors.color1;
                if (data.colors.color2) root.color2 = data.colors.color2;
                if (data.colors.color3) root.color3 = data.colors.color3;
                if (data.colors.color4) root.color4 = data.colors.color4;
                if (data.colors.color5) root.color5 = data.colors.color5;
                if (data.colors.color6) root.color6 = data.colors.color6;
                if (data.colors.color7) root.color7 = data.colors.color7;
                if (data.colors.color8) root.color8 = data.colors.color8;
                if (data.colors.color9) root.color9 = data.colors.color9;
                if (data.colors.color10) root.color10 = data.colors.color10;
                if (data.colors.color11) root.color11 = data.colors.color11;
                if (data.colors.color12) root.color12 = data.colors.color12;
                if (data.colors.color13) root.color13 = data.colors.color13;
                if (data.colors.color14) root.color14 = data.colors.color14;
                if (data.colors.color15) root.color15 = data.colors.color15;
            }
            QsServices.Logger.debug("Pywal", "colors.json loaded")
        } catch (e) {
            QsServices.Logger.error("Pywal", "Failed to parse colors.json", e?.message ?? e)
        }
    }
    
    // Pywal loading disabled: the panel uses the Serialchiller palette only.
    // FileView has no `active` property in Quickshell 0.3.0, so the loader is
    // simply not instantiated. To restore wallpaper colors, uncomment it.
    /*
    FileView {
        id: pywalFile
        path: QsConfig.Config.paths.pywalColors
        watchChanges: true
        onLoaded: root.loadColors(text())
        onFileChanged: root.loadColors(text())
        onLoadFailed: err => QsServices.Logger.warn("Pywal", `colors.json not loaded: ${FileViewError.toString(err)}`)
    }
    */
}
