#!/bin/env sh

xrandr --output DP-2 --primary
xrandr --output eDP-1 --off
xset -b -c # disable bells
# urxvtd -f -o -q # Start urxvt daemon
feh --no-fehbg --bg-fill "$HOME/.local/share/backgrounds"

