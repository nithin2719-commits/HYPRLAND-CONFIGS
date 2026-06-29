#!/usr/bin/env bash
# Emits the CD's frame index (0-59).
#
# eww repaints an image swap about ten times a second and no faster, whatever
# rate it is fed — measured, not assumed. So the dial is the ANGLE per frame,
# not the tick rate: the set is cut at 6 degrees, giving 60 deg/s. A finer cut
# would be smoother and slower; a coarser one faster and jumpier.
#
# Two things keep the rotation even:
#   * the player's status is read from a file that mpris_watch.sh keeps current,
#     not by calling playerctl here — that call took tens of milliseconds and
#     produced a visible hitch every time it fired mid-spin;
#   * the wait is a read timeout on a fifo rather than sleep(1), so no process
#     is forked between frames (verified: 12 iterations/s at 0.08s, not a spin).
#
# It idles while the dashboard is closed: nobody can see the disc then.
flag="$HOME/.cache/eww/dash-open"
statefile="$HOME/.cache/eww/player-status"
fifo="${XDG_RUNTIME_DIR:-/tmp}/eww-spin.$$"

mkfifo "$fifo" 2>/dev/null
exec 3<>"$fifo"
rm -f "$fifo"
trap 'exec 3>&-' EXIT

pause() { read -r -t "$1" -u 3 _ 2>/dev/null; }

i=0
while true; do
    if [[ ! -f $flag ]]; then
        pause 0.5
        continue
    fi
    echo "$i"
    # Hold on frame 0 until every frame of the current set is a real rotation;
    # spinning through a half-rendered set lurches.
    cur=$(cat "$HOME/.cache/eww/cd-current" 2>/dev/null)
    if [[ -n $cur && ! -f "$cur/.complete" ]]; then
        i=0
    elif [[ $(< "$statefile") == Playing ]]; then
        # One frame a tick: the set is cut at 6 degrees, which at the 10fps
        # repaint ceiling is 60 deg/s. The frame count, not the tick rate, is
        # the dial — eww will not repaint faster than about ten times a second.
        i=$(( (i + 1) % 60 ))
    fi
    pause 0.1
done
