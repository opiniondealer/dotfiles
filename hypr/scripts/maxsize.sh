#!/usr/bin/env bash
# maxsize.sh — resize window aktif ke max 80% lebar monitor
MON=$(hyprctl activewindow -j | jq -r '.monitor')
read W H < <(hyprctl monitors -j | jq -r ".[] | select(.name==\"$MON\") | \"\(.width) \(.height)\"")
MAXW=$(( W * 80 / 100 ))
MAXH=$(( H * 85 / 100 ))
hyprctl dispatch resizeactive exact $MAXW $MAXH
