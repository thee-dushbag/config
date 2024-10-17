#!/bin/env sh

xrandr --output DP-2 --primary
xrandr --output eDP-1 --off
xset -b -c # disable bells

chbgpidfile="$HOME/.chbg.pid"

[ -e "$chbgpidfile" ] && {
  kill -s SIGTERM "$(<"$chbgpidfile")" 2>/dev/null
  rm -f "$chbgpidfile"
}

xcompmgr -F &
sleep 0.5 # chbg and the compositor seem to crash each other.
CHBGFAST=yes CHBGWAIT=20m CHBGSEL=random_shuffle CHBGPID="$chbgpidfile" chbg &
# urxvtd -f -o -q # Start urxvt daemon
# feh --no-fehbg --bg-fill "$HOME/.local/share/backgrounds"

