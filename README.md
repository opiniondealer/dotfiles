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

- **.zshrc** - Shell config (Oh My Zsh, Powerlevel10k, aliases, functions, PATH)
- **kitty/** - Kitty terminal config + `serialchiller.conf` theme
- **nvim/** - Neovim config (LazyVim + lazy.nvim)
- **git/.gitconfig** - Git config
- **bin/** - Custom scripts (openapi-checker.sh, googleapicheck, basic-recon.sh)
- **btop/** - btop theme "serialchiller"
- **fastfetch/** - fastfetch config + the image used as its logo

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
git clone git@github.com:opiniondealer/dotfiles.git
cd dotfiles
chmod +x install.sh
./install.sh
```

Existing configs are backed up to `~/.dotfiles-backup/`.

`install.sh` symlinks each config into place. Two things it deliberately does
not touch:

- `hypr/monitors.conf` and `waybar/config` are runtime symlinks that
  `switch-layout.sh` rewrites whenever the monitor count changes, so they stay
  out of git.
- `~/.config/quickshell-controlcenter` is linked as a whole directory, so new
  QML files need no `install.sh` change.

After install, enable the Quickshell service once:

```bash
systemctl --user enable --now quickshell-controlcenter.service
```

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