#!/usr/bin/env sh
# globalcontrol.sh — adapted for Debian (original: roscaa-stack/dotfiles)

# wallpaper var
EnableWallDcol=1
ConfDir="${XDG_CONFIG_HOME:-$HOME/.config}"
CloneDir="$HOME/dotfiles"
cacheDir="$HOME/.cache/hyprdots"
ThemeCtl="${ConfDir}/hyprdots/theme.ctl"
WallbashDir="${ConfDir}/hyprdots/wallbash"

# gtk theme var (gnome tools optional)
if command -v gsettings >/dev/null 2>&1; then
    gtkTheme=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | sed "s/'//g")
    gtkIcon=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null | sed "s/'//g")
    gtkMode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | sed "s/'//g" | awk -F '-' '{print $2}')
fi

# hypr var
hypr_border=$(hyprctl -j getoption decoration:rounding 2>/dev/null | jq '.int' 2>/dev/null)
hypr_width=$(hyprctl -j getoption general:border_size 2>/dev/null | jq '.int' 2>/dev/null)

# debian pkg helpers (substitute untuk pacman fns)
pkg_installed()
{
    local PkgIn=$1
    if dpkg-query -W -f='${Status}' "$PkgIn" 2>/dev/null | grep -q "ok installed"; then
        return 0
    else
        return 1
    fi
}

pkg_available()
{
    local PkgIn=$1
    if apt-cache show "$PkgIn" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# AUR tidak relevan di Debian (dummy biar script lain ga error)
get_aurhlpr()
{
    aurhlpr="apt"
}

aurhlpr="apt"
