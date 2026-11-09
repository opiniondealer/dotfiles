# Quickshell Control Center (standalone)

Extracted Control Center from https://github.com/tripathiji1312/quickshell
Trimmed to Control Center only. Bar / launcher / dashboard / sidebar / OSD removed.

## Layout

    shell.qml                          entry point (Control Center + IpcHandler)
    modules/controlcenter/             the panel
    services/                          system integrations (audio, net, bt, ...)
    components/                        reusable QML primitives
    config/                            Config.qml reads shell.json
    shell.json                         user settings
    settings.json                      DND / focus-mode persistence
    launch.sh                          launcher (strips QT_SCALE_FACTOR)
    hypr-bind.conf                     keybind snippet to paste into Hyprland

## Run

    systemctl --user status quickshell-controlcenter
    systemctl --user restart quickshell-controlcenter

## Toggle

    quickshell ipc -p ~/.config/quickshell-controlcenter call controlcenter toggle

Or bind it (see hypr-bind.conf):

    bind = $mainMod, C, exec, quickshell ipc -p ~/.config/quickshell-controlcenter call controlcenter toggle

## Dependencies

Runtime: quickshell (Debian backports), pipewire/wireplumber, networkmanager,
bluez, upower, power-profiles-daemon, brightnessctl, grim, slurp, pamixer,
playerctl, wf-recorder, python-pywal (via pipx), nm-connection-editor, wlogout

Fonts: "Inter" and "Material Design Icons" (MDI >= 7.x, NOT the apt package
fonts-materialdesignicons-webfont 1.6.50 -- it lacks the codepoints used here).

## Local modifications vs upstream

1. All `import ... 6.10` lowered to `6.8` (this host runs Qt 6.8.2).
2. Config.qml + Settings.qml read from ~/.config/quickshell-controlcenter/.
3. Panel follows the focused monitor instead of always screens[0].
4. Auto-close on pointer-leave only arms after the pointer entered once, so
   opening via keybind does not close the panel immediately.
5. Dropped `Process.environment` locale overrides in services/Network.qml
   (session locale is already en_US.UTF-8) to silence QVariantHash warnings.

## Notes

- `notifications.registerServer` is false because swaync already owns
  org.freedesktop.Notifications. Set it true only after stopping swaync.
- QT_SCALE_FACTOR=2 is set globally in hyprland.conf. Quickshell already
  handles Wayland scaling, so the service strips it to avoid 2x rendering.

## Bar integration (waybar)

`custom/power` (wlogout) was replaced by `custom/controlcenter` (gear icon,
`U+F0493`) in `config`, `config-single`, `config-triple`.

`custom/notification` no longer calls `swaync-client`. It is now a plain bell
(`U+F009A`) whose click runs:

    quickshell ipc -p ~/.config/quickshell-controlcenter call controlcenter toggleNotifications

`toggleNotifications` opens the panel and scrolls to the notification list;
pressing it again closes the panel.

`style.css` had `#custom-power` renamed to `#custom-controlcenter` so the pill
styling follows the new module.

## Notification daemon

Quickshell now owns `org.freedesktop.Notifications`, so the panel's
NotificationList is populated. `swaync` was masked to stop the two fighting
for the bus:

    systemctl --user unmask swaync.service    # to revert
    systemctl --user enable --now swaync.service

If you revert, also set `shell.json -> notifications.registerServer` to false
and point the bar bell back at swaync-client.

## IPC targets

    controlcenter toggle              open/close
    controlcenter open                open only
    controlcenter close               close only
    controlcenter notifications       open + scroll to notifications
    controlcenter toggleNotifications open at notifications / close if open

## Bar layout (latest)

Right side, left to right:

    [todoist]  [tray]  [cpu memory battery]  [shortcuts network bluetooth bell gear]

- `pulseaudio` was removed from the bar (volume is in the Control Center slider).
- `custom/controlcenter` (gear) is a plain icon now -- the filled pill styling
  (`background: @sc-primary`) was dropped so it matches its neighbours.
- `custom/shortcuts`, `network`, `bluetooth`, the bell and the gear share the
  last pill, terminated by `custom/r_end`.

## Panel contents (latest)

Header buttons, left to right:

    gear   -> nm-connection-editor (network connections)
    lock   -> loginctl lock-session (hyprlock)
    power  -> wlogout

Note: the lock button used to show MDI U+F035C, which is `menu`, not a lock.
It now uses U+F033E (`lock`).

Quick toggle grid:

    Wi-Fi | Bluetooth
    Do Not Disturb | Caffeine
    Gaming Mode | Focus Mode

The three screenshot tiles (Screenshot / Record Screen / Open Captures) were
removed. `modules/controlcenter/ControlCenterWindow.qml` no longer references
QsServices.Screenshot or the `xdg-open` captures process.

## 2026-11-08 — compact layout, Serialchiller palette, tile removal

### Removed
- Lock button in the header (and `lockProcess`).
- Caffeine tile — the machine never blanks anyway: `hypridle.service` is
  masked, no `swayidle`/`xidle` runs, and Hyprland has no dpms timeout bind.
- Focus Mode tile, its 25-minute timer in `shell.qml`, and its keys in
  `settings.json`.
- Unused `idleInhibitor` binding in the window.

Header is now: gear (nm-connection-editor) + power (wlogout).

### Sizing (440x1400 -> 360, content-hugging)

    panel width        440 -> 360
    panel height       fixed 1400 -> content + 48, capped to screen
    card radius        28 -> 22
    outer margins      24 -> 16
    section spacing    24 -> 14, grid gaps 12 -> 8
    clock             42px -> 30px
    header buttons   48x48 -> 36x36, icon 24 -> 19
    quick tiles       80px tall -> 56px, icon 26 -> 19, radius 28 -> 18
    sliders           64px -> 46px, icon 24 -> 18
    system stats     110px -> 74px, value 28 -> 19
    media card       100px -> 68px
    notifications     56px bell -> 36px, card radius 20 -> 14

Result on this machine: **360x569** (was 440x1400).

### Colors: Serialchiller palette instead of pywal wallpaper colors

`services/Pywal.qml` now hard-codes the waybar Serialchiller tokens and the
pywal `FileView` loader is commented out:

    bg #171717 · card #0e0e0e · fg #fafafa · muted fg #a1a1a1
    border #262626 · accent #404040
    blue ramp: chart1 #91c5ff -> chart5 #1f3fad
    destructive #ff6467

`primary` = chart1 (blue), `secondary` = chart2, `error` = destructive.
To go back to wallpaper colors, uncomment the `FileView` block at the bottom
of `services/Pywal.qml`.

### Two upstream bugs fixed along the way

1. **`config` <-> `services` import cycle.** `config/Config.qml` imported
   `../services` (only for Logger) while `services/Pywal.qml` imports
   `../config` for the colors path. Qt refused to resolve the modules and the
   whole shell failed to load once a deeper chain was touched. Config now uses
   `console.log/warn` and no longer imports services.
2. **`config/Appearance.qml` read nonexistent keys.** It referenced
   `Config.appearance.rounding/spacing/padding/font/anim/transparency`, none of
   which exist in `shell.json`, so the singleton always failed. It is now
   self-contained.
3. `components/Anim.qml` imported `qs.config` for tokens; values are inlined.
4. `components/NotificationCard.qml` used `pywal` before declaring it. It is
   now a plain injected property (NotificationList passes it).

## 2026-11-08 (2) — no yellow, notification box fixed

### Colors: yellow removed
The palette is now strictly Serialchiller. `warning` used to be `#FF9F00`
(orange) and `success` was `#37B679` (green); both were outside the theme.

    color3 / warning  -> scChart2 (#3a81f6)
    color2 / success  -> scChart1 (#91c5ff)
    BrightnessSlider accent: warning -> primary (blue)
    SystemStats: dropped the >50% yellow tier; blue below 80, red at 80+

Verified by scanning the rendered panel: 0.1% yellowish pixels left (antialiasing
on the media artwork, not UI chrome).

### Notification box clipped out of the panel — real cause chain

Three separate sizing bugs, all in the same component:

1. `components/NotificationCard.qml` — `implicitHeight: contentLayout.implicitHeight`
   but `contentLayout` was only anchored left/right, never top. A ColumnLayout
   with no vertical anchor reports 0, so every card measured 0px.
   Fixed: added `anchors.top: parent.top`.

2. `NotificationList.qml` delegate — `height: cardContent.implicitHeight + 16`
   while `cardContent` was `anchors.fill: parent`. Classic binding loop; Qt
   would have warned and used a stale height. Fixed: card is top-anchored with
   `height: implicitHeight`, delegate height = card + 16 (8px top + 8px bottom).

3. `ControlCenterWindow.qml` — the outer `ColumnLayout` sits inside a
   `StyledFlickable`, so its height was not propagated; the Flickable's
   `Layout.preferredHeight` read an undefined column height and the panel
   under-measured itself by exactly the amount that got clipped.
   Fixed: the Flickable uses `Layout.preferredHeight: contentColumn.implicitHeight`
   and `contentHeight: contentColumn.height + 8`.

Also: `ListView` is given a constant `maxListHeight` (240px) so its
`contentHeight` is well-defined, and the visible box shrinks to the real
`contentHeight`. Sizing the ListView *from* `bodyHeight` was circular.

### Other fixes in this pass
- Panel scroll resets to the top on open. It used to keep the previous
  `contentY` from `scrollToNotifications()`, which clipped the header and the
  Wi-Fi row.
- `armed` (hover auto-close state) is now qualified as `panelContent.armed`;
  the HoverHandler's scope could not see it (`Invalid write to global property`).
- When the notification list is empty the bell glyph showed `U+F009` + "A"
  because JS `"\uF009A"` reads exactly 4 hex digits. Now a literal codepoint.

State: panel is 360 wide, height 603 (empty) / 614 (1 notif) / 779 (4+ notifs).

## 2026-11-08 (3) — clear all, font, pill order

### Clear All did nothing
`Notifs.clearAll()` called `n.close()` on every entry, but `close()` only sets
`closed = true` and dismisses it from the daemon. The rendered model is
`recentNotifications`, which filters by timestamp (last 24h) and **keeps closed
entries** on purpose. So the list never emptied.

Fixed: `clearAll()` now dismisses each notification and then replaces the model
with `[]`. `clearApp()` had the same flaw and was fixed the same way.
Verified: panel height 699 -> 603 after clearing two notifications.

### Font matches the bar
The bar uses `JetBrainsMono Nerd Font` (`waybar/style.css: * { font-family }`).
The panel was hard-coded to `Inter` in 60 places.

    Inter -> "JetBrainsMono Nerd Font"   (14 QML files + NotificationCard fallbacks)
    shell.json appearance.fontFamily    -> "JetBrainsMono Nerd Font"
    config/Config.qml default           -> "JetBrainsMono Nerd Font"

Because JetBrainsMono is monospace (~0.6em advance vs Inter's ~0.5em), the same
pixel size overflowed and every label showed an ellipsis. Two compensations:

    font sizes scaled down one step (13->12, 16->14, 28->24, ...)
    panel width 360 -> 392

### Right pill order
Waybar renders `modules-right` left-to-right, so the requested right-to-left
order had to be reversed in the list. Final config (`config` and `config-single`,
`config` is a symlink to `config-triple`):

    list:   shortcuts, network, bluetooth, memory, cpu, battery, notification, controlcenter
    visual: controlcenter(gear) | notification | battery | cpu | memory | bluetooth | wifi | shortcuts

One pill, terminated by `custom/r_end`. `memory` precedes `cpu` in the list so
CPU ends up to the left of RAM on screen, matching the requested order.

## 2026-11-08 (4) — gap between RAM and CPU

`waybar/style.css` had `#cpu { padding-left: 16px }` left over from the old
layout where `cpu` was the first module of its own pill and needed the wide
lead-in. Now that every module shares one pill it produced a 22px gap between
`memory` and `cpu` while every other pair sat at 10-16px.

    #cpu padding-left: 16px -> 4px

Resulting gaps: shortcuts->wifi 14, wifi->bt 10, bt->ram 14, ram->cpu 10,
cpu->battery 12, battery->bell 12, bell->gear 16.

## 2026-11-08 (5) — nm-applet tray icon -> wifi glyph

The blue signal-bars icon in the tray was `nm-applet`, not the waybar `network`
module. nm-applet publishes a StatusNotifierItem whose `IconName` is
`nm-signal-<strength>` (00/25/50/75/100), which GTK resolves from the icon
theme. It is not a bitmap the app draws, so the glyph can be replaced by
dropping SVGs with those names into a user icon theme.

What was done:

1. Created `~/.local/share/icons/hicolor/index.theme` (none existed) so the
   user hicolor theme is a valid, inheriting icon theme.
2. Added a wifi SVG as every variant under
   `~/.local/share/icons/hicolor/scalable/apps/`:

        nm-signal-{00,25,50,75,100}{,-secure}.svg
        nm-signal-{...}-symbolic.svg
        network-wireless-signal-{none,weak,ok,good,excellent}.svg

   Verified with `Gtk.IconTheme.lookup_icon("nm-signal-50", 16, 0)` resolving
   to the user file rather than `/usr/share/icons/hicolor/...`.
3. `gtk-update-icon-cache -f -t ~/.local/share/icons/hicolor`
4. Removed the `network` module from `modules-right` in both waybar configs:
   the wifi glyph now comes only from the tray, sitting where the signal bars
   used to be. No duplicate icon.

Note: `#network` CSS rules are now unused but were left in place so restoring
the module is a one-line change.
