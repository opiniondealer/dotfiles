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

- **.zshrc** - Shell config (Oh My Zsh, custom prompt, aliases, functions, PATH)
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

### Missing commands

At the end the script lists any binaries it did not find, so you know what to
install before the setup is fully functional.

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
- **Nemo** - file manager
- **JetBrainsMono Nerd Font** - UI font
- **Material Design Icons** font - panel glyphs
- [btop](https://github.com/aristocratos/btop) - optional, for the serialchiller theme
- [fastfetch](https://github.com/fastfetch-cli/fastfetch) - system info on shell start

`hypridle` is present in the repo but currently masked on this machine.

The font packages are `ttf-jetbrains-mono-nerd` and `fonts-materialdesignicons-webfont`
on Debian.