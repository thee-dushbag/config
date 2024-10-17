#!/usr/bin/env sh

pidfile="${CHBGPID:-$HOME/.chbg.pid}"
bgdir="${CHBGDIR:-$HOME/.local/share/chbg}"
selector="${CHBGSEL:-random}"
selectors=(order random random_shuffle)
sleeptime="${CHBGWAIT:-5m}"

HELP="
Welcome to CHBG, a program to periodicly change xorg background.
Using feh (the only external dependency)
Arguments are passed via global variables, they are.

  CHBGPID    This holds the file in which the chbg instance will
             store its pid which can be used to interact with the
             chbg and/or kill it and also notify of the existence
             of a running one
  CHBGDIR    This holds the directory of background images which
             will be set as backgrounds
  CHBGSEL    This holds the selection startegy for a the next
             background, should be oneof:
               ${selectors[@]}
  CHBGWAIT   This is the time for chbg to wait until it changes
             the background, the format should be (D+(s|m|h|d)?)+
             where D is a digit, the default is 5m
  CHBGFAST   Since the arg verification can be slow, and we don't 
             want to lag the wallpaper during startup, set this 
             to oneof (y|yes|true) to skip the verification direct 
             to the background logic. Be warned, unexpected sh*t 
             can happen if not careful, be sure of the args and 
             you'll be fine.

To reload the backgrounds in "$bgdir", send signal SIGUSR1 to
the running instance of chbg via pid in '$pidfile'. To set the 
next background send SIGUSR2.

Note: Running multiple chbg instances can create some rhythmic
      or chaotic background changes depending on the design.
      Example:
        CHBGWAIT=10s CHBGPID=one.pid chbg &
        CHBGWAIT=8s CHBGPID=two.pid chbg &
      This will make the background change after every
        8s 2s 8s 2s ...
      This can be fun or annoying, your call.

Note: Due to the limitations of feh, the program used to set 
      backgrounds in chbg, it is hard to make some monitors change
      while the others stay put to one background.
"

[[ $# -gt 0 ]] && case "$1" in
  --help | -h | help) echo "$HELP"; exit 0 ;;
  *) echo >&2 "chbg does not support cmdargs, only --help, but got: $*"; exit 1 ;;
esac

if [[ "$CHBGFAST" =~ ^y|yes|true$ ]]; then
  if [ -f "$pidfile" ]; then
    echo >&2 "chbg: there is a chbg instance already running in pid $(<"$pidfile")"
    echo >&2 "      or the last one did not cleanup properly. Send SIGTERM"
    echo >&2 "      to process $(<"$pidfile") or remove the file."
    exit 1
  fi

  if [ ! -d "$bgdir" ]; then
    echo >&2 "chbg: backgrounds directory was not found: '$bgdir'"
    exit 1
  fi

  selector_found=false
  for _selector in "${selectors[@]}"; do
    if [[ "$_selector" == "$selector" ]]; then
      selector_found=true
    fi
  done

  if ! $selector_found; then
    echo >&2 "chbg: unknown selector, expected oneof: ${selectors[@]}"
    exit 1
  fi

  declare -a sleeptime_err=()
  for _sleeptime in $sleeptime; do
    if ! [[ "$_sleeptime" =~ ^[[:digit:]]+(s|m|h|d)?$ ]]; then
      sleeptime_err=("${sleeptime_err[@]}" "$_sleeptime")
    fi
  done

  if [[ "${#sleeptime_err[@]}" -gt 0 ]]; then
    echo >&2 "chbg: sleeptime format match failed on: ${sleeptime_err[@]}"
    echo >&2 "      expected format as taken by the sleep command"
    exit 1
  fi
fi

echo $$ >"$pidfile"

function select_prep {
  [[ $selector == order ]] || return
  ordercnt=1
  chosenbgs=("<remove_this>")
  for i in $(seq 0 $((mons-3))); do 
    chosenbgs+=("${backgrounds[$i]}")
  done
}

function select_order {
  unset chosenbgs[0]
  chosenbgs=("${chosenbgs[@]}" "${backgrounds[$ordercnt]}")
  [[ $((++ordercnt)) -eq $bgs ]] && declare -g ordercnt=0
}

function select_random_shuffle {
  IFS=$'\n' chosenbgs=($(shuf --echo "${backgrounds[@]}" | head -n $((mons-1))))
}

function select_random {
  chosenbgs=()
  for _ in $(seq 2 $mons); do
    chosenbgs+=("${backgrounds[$(($RANDOM % $bgs))]}")
  done
}

function sleep_wrapper {
  sleep $sleeptime &
  until wait; do
    if $STOP_SLEEP; then
      STOP_SLEEP=false
      kill %% 2>/dev/null 
    fi
  done
}

function bgsetter {
  select_prep
  while :; do
    select_$selector
    if ! feh --no-fehbg --bg-fill "${chosenbgs[@]}"; then
      echo >&2 "chbg: feh exited with $? while setting backgrounds:"
      (IFS=$'\n'; echo "${chosenbgs[*]/#/         }")
      continue
    fi
    sleep_wrapper
  done
}

function refresh {
  # set some global variables
  mons=$(xrandr --listactivemonitors | wc -l)
  backgrounds=($bgdir/*)
  bgs=${#backgrounds[@]}
  select_prep
}

function cleanup {
  rm -f "$pidfile"
  exit 0
}

function nextbg {
  STOP_SLEEP=true
}

trap refresh USR1
trap nextbg  USR2
trap cleanup PWR TERM INT

refresh
bgsetter
cleanup

