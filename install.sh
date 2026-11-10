#!/bin/bash
# Install the Serialchiller dotfiles into $HOME.
#
# Config files that ship with placeholders (__HOME__, __WALLPAPER__) are
# rendered into $HOME/.config/dotfiles-rendered/<name> and symlinked from
# there, so the owner's machine paths never leak into another user's install.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
RENDER_DIR="$HOME/.config/dotfiles-rendered"

mkdir -p "$BACKUP_DIR"

CREATED_LINKS=()

# --- helpers -----------------------------------------------------------

backup() {
    local src="$1"
    if [ -e "$src" ] && [ ! -L "$src" ]; then
        mkdir -p "$BACKUP_DIR/$(dirname "${src#"$HOME"/}")"
        mv "$src" "$BACKUP_DIR/${src#"$HOME"/}"
        echo "  backed up: $src"
    fi
}

link() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    backup "$dst"
    ln -sfn "$src" "$dst"
    CREATED_LINKS+=("$dst")
    echo "  linked: $dst"
}

# Render a config containing __HOME__ / __WALLPAPER__ placeholders, then link it.
render_link() {
    local src="$1" dst="$2"
    mkdir -p "$RENDER_DIR/$(dirname "${dst#"$HOME"/.config/}")"
    local out="$RENDER_DIR/${dst#"$HOME"/.config/}"
    mkdir -p "$(dirname "$out")"
    render_placeholders "$src" >"$out"
    link "$out" "$dst"
}

render_placeholders() {
    local src="$1"
    python3 - "$src" "$HOME" "$WALLPAPER" <<'PY'
import sys, pathlib
src, home, wallpaper = sys.argv[1], sys.argv[2], sys.argv[3]
s = pathlib.Path(src).read_text()
s = s.replace("__HOME__", home).replace("__WALLPAPER__", wallpaper)
sys.stdout.write(s)
PY
}

need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        MISSING+=("$1")
    fi
}

MISSING=()

# --- wallpaper fallback -------------------------------------------------

# hyprpaper needs a real image. Reuse the current wallpaper if the user has
# one, otherwise render a plain Serialchiller-coloured PNG so hyprpaper still
# starts cleanly instead of failing on a missing file.
if [ -e "$HOME/.cache/current_wallpaper" ]; then
    WALLPAPER="$HOME/.cache/current_wallpaper"
else
    WALLPAPER="$RENDER_DIR/wallpaper.png"
    mkdir -p "$RENDER_DIR"
    if command -v magick >/dev/null 2>&1; then
        magick -size 1920x1080 xc:'#171717' "$WALLPAPER" 2>/dev/null || true
    elif command -v convert >/dev/null 2>&1; then
        convert -size 1920x1080 xc:'#171717' "$WALLPAPER" 2>/dev/null || true
    fi
    [ -s "$WALLPAPER" ] || WALLPAPER="$HOME/.cache/current_wallpaper"
fi

echo "Backing up existing configs to $BACKUP_DIR..."
echo ""

# --- shell -------------------------------------------------------------

echo "[shell]"
link "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
need zsh

# --- terminal ----------------------------------------------------------

echo "[kitty]"
link "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
link "$DOTFILES_DIR/kitty/serialchiller.conf" "$HOME/.config/kitty/themes/serialchiller.conf"
need kitty

# --- neovim ------------------------------------------------------------

echo "[nvim]"
link "$DOTFILES_DIR/nvim/init.lua" "$HOME/.config/nvim/init.lua"
link "$DOTFILES_DIR/nvim/lazyvim.json" "$HOME/.config/nvim/lazyvim.json"
link "$DOTFILES_DIR/nvim/.neoconf.json" "$HOME/.config/nvim/.neoconf.json"
link "$DOTFILES_DIR/nvim/stylua.toml" "$HOME/.config/nvim/stylua.toml"
for f in autocmds keymaps lazy options; do
    link "$DOTFILES_DIR/nvim/lua/config/$f.lua" "$HOME/.config/nvim/lua/config/$f.lua"
done
for f in all-themes disable-news-alert snacks-animated-scrolling-off; do
    link "$DOTFILES_DIR/nvim/lua/plugins/$f.lua" "$HOME/.config/nvim/lua/plugins/$f.lua"
done
link "$DOTFILES_DIR/nvim/plugin/after/transparency.lua" "$HOME/.config/nvim/plugin/after/transparency.lua"
# nvim can come from the system or from ~/apps/nvim (the alias in .zshrc
# prefers the local build when it exists).
if ! command -v nvim >/dev/null 2>&1 && [ ! -x "$HOME/apps/nvim/bin/nvim" ]; then
    MISSING+=("nvim (or a build in ~/apps/nvim/bin)")
fi

# --- git ---------------------------------------------------------------

echo "[git]"
link "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
need git

# --- bin ---------------------------------------------------------------

echo "[bin]"
mkdir -p "$HOME/.local/bin"
link "$DOTFILES_DIR/bin/openapi-checker.sh" "$HOME/.local/bin/openapi-checker.sh"
link "$DOTFILES_DIR/bin/googleapicheck" "$HOME/.local/bin/googleapicheck"
link "$DOTFILES_DIR/bin/basic-recon.sh" "$HOME/.local/bin/basic-recon.sh"

# --- gtk ---------------------------------------------------------------

echo "[gtk]"
link "$DOTFILES_DIR/gtk/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"

echo "[gtk-theme]"
link "$DOTFILES_DIR/hypr/themes/gtk-serialchiller.css" "$HOME/.themes/Serialchiller/gtk-3.0/gtk.css"

# --- tui themes --------------------------------------------------------

echo "[btop]"
link "$DOTFILES_DIR/btop/themes/serialchiller.theme" "$HOME/.config/btop/themes/serialchiller.theme"
if [ -f "$HOME/.config/btop/btop.conf" ]; then
    if grep -q '^color_theme' "$HOME/.config/btop/btop.conf"; then
        sed -i 's/^color_theme = .*/color_theme = "serialchiller"/' "$HOME/.config/btop/btop.conf"
        echo "  set color_theme = serialchiller in btop.conf"
    else
        echo "  color_theme not found in btop.conf, set it manually"
    fi
fi
need btop

echo "[fastfetch]"
if command -v fastfetch >/dev/null 2>&1; then
    render_link "$DOTFILES_DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    link "$DOTFILES_DIR/fastfetch/anya.png" "$HOME/.config/fastfetch/anya.png"
else
    echo "  fastfetch not found, skipped"
fi

# --- hyprland ----------------------------------------------------------

echo "[hyprland]"
link "$DOTFILES_DIR/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf"
link "$DOTFILES_DIR/hypr/workspaces.conf" "$HOME/.config/hypr/workspaces.conf"
link "$DOTFILES_DIR/hypr/hypridle.conf" "$HOME/.config/hypr/hypridle.conf"
link "$DOTFILES_DIR/hypr/scripts/maxsize.sh" "$HOME/.config/hypr/scripts/maxsize.sh"
render_link "$DOTFILES_DIR/hypr/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
render_link "$DOTFILES_DIR/hypr/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf"

# Monitor profile: keep an existing runtime symlink (switch-layout.sh owns it),
# otherwise start from the single-monitor profile.
if [ -L "$HOME/.config/hypr/monitors.conf" ] || [ -e "$HOME/.config/hypr/monitors.conf" ]; then
    backup "$HOME/.config/hypr/monitors.conf"
fi
link "$DOTFILES_DIR/hypr/monitors-single.conf" "$HOME/.config/hypr/monitors.conf"
link "$DOTFILES_DIR/hypr/monitors-single.conf" "$HOME/.config/hypr/monitors-single.conf"
link "$DOTFILES_DIR/hypr/monitors-triple.conf" "$HOME/.config/hypr/monitors-triple.conf"
need hyprland
need hyprpaper

echo "[hyprdots]"
mkdir -p "$HOME/.config/hyprdots/scripts"
for s in audio-switch globalcontrol hypr-monitor-listener shortcuts systemupdate wallpaper ws volume-slider switch-layout; do
    [ -e "$DOTFILES_DIR/hyprdots/scripts/$s.sh" ] && \
        link "$DOTFILES_DIR/hyprdots/scripts/$s.sh" "$HOME/.config/hyprdots/scripts/$s.sh"
done
for p in audio-panel brightness-panel calendar-panel shortcuts-panel todoist-tasks panel_scale; do
    [ -e "$DOTFILES_DIR/hyprdots/scripts/$p.py" ] && \
        link "$DOTFILES_DIR/hyprdots/scripts/$p.py" "$HOME/.config/hyprdots/scripts/$p.py"
done

# --- waybar ------------------------------------------------------------

echo "[waybar]"
link "$DOTFILES_DIR/waybar/style.css" "$HOME/.config/waybar/style.css"
link "$DOTFILES_DIR/waybar/themes/Serialchiller.css" "$HOME/.config/waybar/themes/Serialchiller.css"
link "$DOTFILES_DIR/waybar/themes/theme.css" "$HOME/.config/waybar/themes/theme.css"
render_link "$DOTFILES_DIR/waybar/config-single" "$HOME/.config/waybar/config-single"
render_link "$DOTFILES_DIR/waybar/config-triple" "$HOME/.config/waybar/config-triple"

# ~/.config/waybar/config is a runtime symlink owned by switch-layout.sh.
# Point it at the single profile on a fresh install.
if [ -L "$HOME/.config/waybar/config" ] || [ -e "$HOME/.config/waybar/config" ]; then
    backup "$HOME/.config/waybar/config"
fi
link "$HOME/.config/waybar/config-single" "$HOME/.config/waybar/config"
need waybar

# --- launchers ---------------------------------------------------------

echo "[wofi]"
render_link "$DOTFILES_DIR/wofi/config" "$HOME/.config/wofi/config"
render_link "$DOTFILES_DIR/wofi/drun.conf" "$HOME/.config/wofi/drun.conf"
link "$DOTFILES_DIR/wofi/style.css" "$HOME/.config/wofi/style.css"
need wofi

echo "[swaync]"
link "$DOTFILES_DIR/swaync/config.json" "$HOME/.config/swaync/config.json"
link "$DOTFILES_DIR/swaync/style.css" "$HOME/.config/swaync/style.css"
need swaync

# --- quickshell control center -----------------------------------------

echo "[quickshell-controlcenter]"
link "$DOTFILES_DIR/quickshell-controlcenter" "$HOME/.config/quickshell-controlcenter"
link "$DOTFILES_DIR/systemd/user/quickshell-controlcenter.service" \
     "$HOME/.config/systemd/user/quickshell-controlcenter.service"
need quickshell
# Only touch the live systemd user session when $HOME really is the user that
# session belongs to. Overriding HOME (e.g. a dry run into a fake home) must not
# enable a unit on the real session.
unit_ok=0
if command -v systemctl >/dev/null 2>&1 && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
    runtime_home=$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f6)
    [ "$HOME" = "$runtime_home" ] && unit_ok=1
fi
if [ "$unit_ok" = 1 ]; then
    systemctl --user daemon-reload 2>/dev/null || true
    if systemctl --user enable --now quickshell-controlcenter.service 2>/dev/null; then
        echo "  enabled + started quickshell-controlcenter.service"
    else
        echo "  unit linked; after logging in run: systemctl --user enable --now quickshell-controlcenter.service"
    fi
else
    echo "  unit linked; after logging in run: systemctl --user enable --now quickshell-controlcenter.service"
fi

# --- verify ------------------------------------------------------------

# Checks the result, not just that the commands above ran. Everything here is
# static (file contents, JSON syntax, path targets) so it stays fast and does
# not need a desktop session.
echo "[verify]"
VERIFY_FAIL=0
vfail() { echo "  FAIL: $1"; VERIFY_FAIL=$((VERIFY_FAIL+1)); }
vok()   { echo "  ok:   $1"; }

# 1. no placeholder may survive in the rendered config
if grep -rq "__HOME__\|__WALLPAPER__" "$RENDER_DIR" 2>/dev/null; then
    vfail "unrendered placeholders left in $RENDER_DIR"
else
    vok "placeholders rendered"
fi

# 2. every symlink we created must resolve
broken=0
for l in "${CREATED_LINKS[@]}"; do
    [ -e "$l" ] || { vfail "broken symlink: $l"; broken=1; }
done
[ "$broken" = 0 ] && vok "all symlinks resolve"

# 3. JSON/JSONC configs must parse
parse_json() { # file, label
    python3 - "$1" <<'PY'
import json, re, sys
p = sys.argv[1]
s = re.sub(r"^\s*//.*$", "", open(p).read(), flags=re.M)
json.loads(s)
PY
}
for f in "$HOME/.config/waybar/config" "$HOME/.config/waybar/config-single" \
         "$HOME/.config/waybar/config-triple" "$HOME/.config/swaync/config.json"; do
    [ -e "$f" ] || continue
    if parse_json "$f" 2>/dev/null; then
        vok "valid JSON: ${f#"$HOME"/}"
    else
        vfail "invalid JSON: ${f#"$HOME"/}"
    fi
done

# 4. waybar module commands must point at files that exist
if [ -e "$HOME/.config/waybar/config" ]; then
    missing=$(python3 - "$HOME" <<'PY'
import json, os, re, sys
home = sys.argv[1]
cfg = os.path.join(home, ".config/waybar/config")
s = re.sub(r"^\s*//.*$", "", open(cfg).read(), flags=re.M)
try:
    d = json.loads(s)
except Exception:
    sys.exit(0)
missing = []
for name, mod in d.items():
    if not isinstance(mod, dict):
        continue
    for key in ("exec", "on-click", "on-click-right"):
        cmd = mod.get(key)
        if not cmd:
            continue
        for path in re.findall(r"(/home/[^\s'\"]+)", cmd):
            if not os.path.exists(path):
                missing.append(f"{name}.{key} -> {path}")
print("\n".join(missing))
PY
)
    if [ -n "$missing" ]; then
        while IFS= read -r m; do vfail "waybar target missing: $m"; done <<<"$missing"
    else
        vok "waybar module targets exist"
    fi
fi

# 5. fastfetch must render its config
if command -v fastfetch >/dev/null 2>&1; then
    if fastfetch --config "$HOME/.config/fastfetch/config.jsonc" >/dev/null 2>&1; then
        vok "fastfetch renders its config"
    else
        vfail "fastfetch failed on its config"
    fi
fi

# 6. the quickshell unit must be syntactically valid
if command -v systemd-analyze >/dev/null 2>&1; then
    unit="$HOME/.config/systemd/user/quickshell-controlcenter.service"
    out=$(systemd-analyze verify "$unit" 2>&1 || true)
    # Keep only lines that talk about our unit. The verifier also reports on
    # unrelated units already present on the machine, and complains about a
    # missing /usr/bin/quickshell, which is covered by the dependency list.
    real=$(echo "$out" \
        | grep -i "quickshell-controlcenter" \
        | grep -vi "is not executable" \
        | grep -vi "Command /usr/bin/quickshell" || true)
    if [ -n "$real" ]; then
        vfail "systemd unit: $real"
    else
        vok "quickshell unit parses"
    fi
fi

# --- summary -----------------------------------------------------------

echo ""
if [ ${#MISSING[@]} -gt 0 ]; then
    echo "Missing commands (install these for the config to work fully):"
    printf '  - %s\n' "${MISSING[@]}" | sort -u
    echo ""
fi

if [ "$VERIFY_FAIL" -gt 0 ]; then
    echo "Verification reported $VERIFY_FAIL problem(s) above."
    echo "Configs are linked, but fix those before relying on the setup."
    exit 1
fi

echo "Done. Log out and back in (or restart Hyprland) to apply everything."
echo ""
echo "Make sure ~/.local/bin is in your PATH:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""