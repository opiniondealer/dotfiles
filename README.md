# dotfiles

Personal configuration for a Hyprland desktop on Debian: Hyprland window
manager, Waybar bar, Quickshell control center, and the CLI/TUI tools around
them. Theme is "Serialchiller" (neutral dark, blue accent) shared across
Waybar, Kitty, btop, fastfetch and GTK.

## What's included

### Desktop

- **hypr/** - Hyprland config: keybinds, monitors (single/triple profiles),
  workspaces, hyprpaper, hyprlock, hypridle, GTK theme
- **waybar/** - Bar config for single (`config-single`) and triple
  (`config-triple`) monitor setups, plus `style.css` and Serialchiller theme
- **hyprdots/scripts/** - Helper scripts and GTK4 panels the bar calls
- **wofi/** - Launcher, bound to `SUPER+Space`
- **quickshell-controlcenter/** - Standalone Quickshell panel: control center,
  Bluetooth popup, WiFi popup with password dialog, notification daemon

### CLI / TUI

- **.zshrc** - Shell config (Oh My Zsh, custom prompt, aliases, functions, PATH).
  Resolves its own real location, so `bin/` is on PATH no matter where the
  repo was cloned and even though the file is symlinked into `$HOME`.
- **kitty/** - Kitty terminal config + `serialchiller.conf` theme
- **nvim/** - Neovim config (LazyVim + lazy.nvim)
- **git/.gitconfig** - Git config
- **bin/** - Custom scripts (openapi-checker.sh, googleapicheck, basic-recon.sh)
- **btop/** - btop theme "serialchiller"
- **fastfetch/** - fastfetch config + the image used as its logo
- **systemd/user/** - systemd user units (Quickshell control center)

### Legacy

- **swaync/** - Notification daemon config, kept for reference. It is masked:
  Quickshell owns `org.freedesktop.Notifications` now.

## Quickshell panels

`quickshell-controlcenter/` runs as a systemd user service and provides:

| Panel | Opened by | What it does |
|-------|-----------|--------------|
| Control center | `SUPER+C`, Waybar gear | Clock, quick toggles (WiFi, Bluetooth, DND, Gaming Mode), volume/brightness sliders, CPU/RAM/DISK, notifications |
| Bluetooth | Waybar bluetooth icon | Adapter power (unblocks rfkill first), scan, device list, connect/disconnect |
| WiFi | Waybar network icon | Radio toggle, scan, network list, connect to saved/open networks, password dialog for new secured ones |

IPC targets, useful in keybinds and scripts:

```bash
quickshell ipc -p ~/.config/quickshell-controlcenter call controlcenter toggle
quickshell ipc -p ~/.config/quickshell-controlcenter call bluetooth toggle
quickshell ipc -p ~/.config/quickshell-controlcenter call network toggle
```

Service management:

```bash
systemctl --user status quickshell-controlcenter
systemctl --user restart quickshell-controlcenter
```

## Custom commands

| Command | Function |
|---------|----------|
| `mkdir namafolder` | Create directory and enter it |
| `cekip` | Check public IP via ipconfig.io |
| `extract file.zip` | Universal extract (tar, zip, 7z, gz, xz) |
| `path` | Show all PATH entries |
| `reload` | Restart shell without closing terminal |

### Aliases

| Alias | Command |
|-------|---------|
| `..` | `cd ..` |
| `...` | `cd ../..` |
| `....` | `cd ../../..` |
| `ll` | `ls -lah` |
| `vim` | `nvim` |

## Install

```bash
git clone https://github.com/opiniondealer/dotfiles.git
cd dotfiles
./install.sh
```

Existing files are backed up to `~/.dotfiles-backup/<timestamp>/` before being
replaced. The script is idempotent: re-running it only relinks and re-renders.

### Placeholders

Some configs need absolute paths and their consumers do not expand `~` or
`$HOME` (fastfetch, wofi) or must point at files specific to the machine
(wallpapers). Those files ship with placeholders instead of hardcoded paths:

| Placeholder | Replaced with |
|-------------|---------------|
| `__HOME__` | `$HOME` |
| `__WALLPAPER__` | `~/.cache/current_wallpaper` if present, otherwise a generated 1920x1080 `#171717` PNG |

Rendered copies go to `~/.config/dotfiles-rendered/` and are symlinked into
place, so the repository itself stays portable. Edit the source file in the
repo, then re-run `./install.sh` to re-render.

Affected files: `fastfetch/config.jsonc`, `wofi/config`, `wofi/drun.conf`,
`waybar/config-single`, `waybar/config-triple`, `hypr/hyprlock.conf`,
`hypr/hyprpaper.conf`.

### Runtime symlinks

Two paths are owned by `switch-layout.sh` and rewritten whenever the monitor
count changes:

- `~/.config/hypr/monitors.conf`
- `~/.config/waybar/config`

`install.sh` points both at the single-monitor profile on a fresh install and
leaves them alone on a re-run. They are tracked in git but only as symlinks.

### Quickshell service

The systemd unit ships in `systemd/user/quickshell-controlcenter.service` and is
linked to `~/.config/systemd/user/`. The script enables and starts it when the
current user actually owns the running systemd user session; otherwise it prints
the command to run after logging in:

```bash
systemctl --user enable --now quickshell-controlcenter.service
```

### Dependency report

The script ends with a full check of everything the configs call, not just the
handful it links. Each dependency is printed with its status, and anything
missing comes with the apt package that provides it:

```
[dependencies]
  ok      hyprland
  ok      waybar
  MISSING playerctl  (media controls)  -> apt install playerctl
  ...

[assets]
  ok      Nerd Font (JetBrainsMono)
  MISSING Material Design Icons font  -> apt install fonts-materialdesignicons-webfont
```

The `[assets]` section covers things that are not binaries: the two icon fonts
and the screenshot directory (which the script creates). A missing font does not
stop the bar from starting, but every glyph renders as a box, so it is worth
fixing.

Nothing is installed automatically — this is a report, not an installer.

### Verification

The last step re-checks the result instead of trusting that the commands ran.
It confirms that no placeholders survived, that every symlink the script made
resolves, that the JSON configs parse, that Waybar's module commands point at
files that exist, that fastfetch renders its config, and that the systemd unit
is valid. Any failure is printed and the script exits non-zero.

This is a static check — it does not start Waybar or Hyprland. See "Known issue"
below for the one hardware-dependent crash it cannot catch.

## Prerequisites

- Hyprland on Wayland
- **Waybar** - bar
- **Quickshell** - control center and panels (Qt 6)
- **Wofi** - launcher
- **Kitty** - terminal
- **Neovim** + [LazyVim](https://www.lazyvim.org/)
- **hyprpaper**, **hyprlock** - wallpaper and lock screen
- **nmcli** (NetworkManager) - WiFi in both Waybar and the Quickshell panel
- **blueman** - `blueman-manager`, opened from the Bluetooth panel footer
- **brightnessctl**, **pactl** (PipeWire/PulseAudio) - sliders and media keys
- **JetBrainsMono Nerd Font** - UI font
- **Material Design Icons** font - panel glyphs
- [btop](https://github.com/aristocratos/btop) - optional, for the serialchiller theme
- [fastfetch](https://github.com/fastfetch-cli/fastfetch) - system info on shell start

`hypridle` is present in the repo but currently masked on this machine.

The font packages are `ttf-jetbrains-mono-nerd` and `fonts-materialdesignicons-webfont`
on Debian.

## Known issue: no Bluetooth adapter kills the whole bar

Waybar 0.12.0 (the version in Debian trixie) **segfaults** when the `bluetooth`
module is enabled and the machine has no `/dev/rfkill`, which takes the entire
bar down with it. This affects VMs, containers, and laptops with Bluetooth
disabled in the BIOS. Verified by running the config under a headless Sway
container: with the module present Waybar dies, without it stays up.

If your machine has no Bluetooth adapter, remove `"bluetooth"` from
`modules-right` in `waybar/config-single` (and `config-triple`), or replace it
with a `custom/bluetooth` module that shells out to `bluetoothctl` behind an
existence check. Waybar 0.13 and newer are not affected.

There is a matching note in `waybar/config-single` next to the module.
