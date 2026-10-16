#!/bin/bash
set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"

mkdir -p "$BACKUP_DIR"

backup() {
    local src="$1"
    if [ -e "$src" ] && [ ! -L "$src" ]; then
        mv "$src" "$BACKUP_DIR/"
        echo "  backed up: $src"
    fi
}

link() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    backup "$dst"
    ln -sf "$src" "$dst"
    echo "  linked: $dst -> $src"
}

echo "Backing up existing configs to $BACKUP_DIR..."
echo ""

# Shell
echo "[shell]"
link "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
link "$DOTFILES_DIR/zsh/.p10k.zsh" "$HOME/.p10k.zsh"

# Kitty
echo "[kitty]"
link "$DOTFILES_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
link "$DOTFILES_DIR/kitty/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"
mkdir -p "$HOME/.config/kitty/themes"
link "$DOTFILES_DIR/kitty/serialchiller.conf" "$HOME/.config/kitty/themes/serialchiller.conf"

# Neovim (LazyVim)
echo "[nvim]"
link "$DOTFILES_DIR/nvim/init.lua" "$HOME/.config/nvim/init.lua"
link "$DOTFILES_DIR/nvim/lazyvim.json" "$HOME/.config/nvim/lazyvim.json"
link "$DOTFILES_DIR/nvim/.neoconf.json" "$HOME/.config/nvim/.neoconf.json"
link "$DOTFILES_DIR/nvim/stylua.toml" "$HOME/.config/nvim/stylua.toml"
mkdir -p "$HOME/.config/nvim/lua/config"
link "$DOTFILES_DIR/nvim/lua/config/autocmds.lua" "$HOME/.config/nvim/lua/config/autocmds.lua"
link "$DOTFILES_DIR/nvim/lua/config/keymaps.lua" "$HOME/.config/nvim/lua/config/keymaps.lua"
link "$DOTFILES_DIR/nvim/lua/config/lazy.lua" "$HOME/.config/nvim/lua/config/lazy.lua"
link "$DOTFILES_DIR/nvim/lua/config/options.lua" "$HOME/.config/nvim/lua/config/options.lua"
mkdir -p "$HOME/.config/nvim/lua/lua/plugins"
link "$DOTFILES_DIR/nvim/lua/lua/plugins/all-themes.lua" "$HOME/.config/nvim/lua/lua/plugins/all-themes.lua"
link "$DOTFILES_DIR/nvim/lua/lua/plugins/disable-news-alert.lua" "$HOME/.config/nvim/lua/lua/plugins/disable-news-alert.lua"
link "$DOTFILES_DIR/nvim/lua/lua/plugins/snacks-animated-scrolling-off.lua" "$HOME/.config/nvim/lua/lua/plugins/snacks-animated-scrolling-off.lua"
mkdir -p "$HOME/.config/nvim/plugin/after"
link "$DOTFILES_DIR/nvim/plugin/after/transparency.lua" "$HOME/.config/nvim/plugin/after/transparency.lua"

# Git
echo "[git]"
link "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"

# Bin scripts
echo "[bin]"
mkdir -p "$HOME/.local/bin"
link "$DOTFILES_DIR/bin/openapi-checker.sh" "$HOME/.local/bin/openapi-checker.sh"
link "$DOTFILES_DIR/bin/googleapicheck" "$HOME/.local/bin/googleapicheck"
link "$DOTFILES_DIR/bin/basic-recon.sh" "$HOME/.local/bin/basic-recon.sh"
link "$DOTFILES_DIR/bin/memu-connect.sh" "$HOME/.local/bin/memu-connect.sh"

# GTK (Nemo file manager)
echo "[gtk]"
mkdir -p "$HOME/.config/gtk-3.0"
link "$DOTFILES_DIR/gtk/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"

# btop theme
echo "[btop]"
mkdir -p "$HOME/.config/btop/themes"
link "$DOTFILES_DIR/btop/themes/serialchiller.theme" "$HOME/.config/btop/themes/serialchiller.theme"
if [ -f "$HOME/.config/btop/btop.conf" ]; then
    sed -i 's/^color_theme = .*/color_theme = "serialchiller"/' "$HOME/.config/btop/btop.conf"
    echo "  set color_theme = serialchiller in btop.conf"
fi

# Macchina
echo "[macchina]"
if command -v macchina >/dev/null 2>&1; then
    mkdir -p "$HOME/.config/macchina/themes"
    link "$DOTFILES_DIR/macchina/macchina.toml" "$HOME/.config/macchina/macchina.toml"
    link "$DOTFILES_DIR/macchina/themes/serialchiller.toml" "$HOME/.config/macchina/themes/serialchiller.toml"
else
    echo "  macchina not found, skipped"
fi

echo ""
echo "Done. Restart your shell to apply changes."
echo ""
echo "Make sure ~/.local/bin is in your PATH:"
echo "  export PATH=\"\$HOME/bin:\$PATH\""
