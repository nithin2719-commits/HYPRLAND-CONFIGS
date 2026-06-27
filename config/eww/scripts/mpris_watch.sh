#!/usr/bin/env bash
# Reacts to MPRIS the moment it changes, instead of waiting for the next poll.
#
#   * on new artwork it starts rendering the disc immediately, so the frames
#     are usually on disk before the panel's one-second poll even asks for them
#   * it keeps the player's status in a file, so the spin loop can read it for
#     free rather than calling playerctl mid-animation (that call was a visible
#     hitch every time it fired)
#
# Runs as a small background service (exec-once in Hyprland), not as an eww
# deflisten: eww never starts a listener whose variable no widget reads, and
# this one exists for its side effects.
dir="$(dirname "$0")"

# One instance only.
pidfile="$HOME/.cache/eww/mpris_watch.pid"
mkdir -p "$(dirname "$pidfile")"
if [[ -s $pidfile ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then exit 0; fi
echo $$ > "$pidfile"
statefile="$HOME/.cache/eww/player-status"
mkdir -p "$(dirname "$statefile")"

write_status() { printf '%s' "$1" > "$statefile.tmp" && mv -f "$statefile.tmp" "$statefile"; }

# Seed it: playerctl -F blocks until a player appears, so without this the file
# stays empty — and an empty file means the disc never spins — until the first
# state change after startup.
write_status "$(playerctl status 2>/dev/null || echo Stopped)"

# Status follower. playerctl -F exits the moment the last player leaves the bus,
# so it is restarted in a loop — otherwise closing the browser left the status
# file frozen and the disc would never spin again for the next player.
(
    while true; do
        playerctl -F status 2>/dev/null | while read -r st; do write_status "$st"; done
        write_status Stopped
        sleep 2
    done
) &

# Track follower: run the resolver the instant the track changes rather than
# waiting up to a second for the next poll. music.sh decides what artwork is
# good enough to press — the browser's thumbnail never is — and starts the
# high-resolution lookup and the render itself.
while true; do
    playerctl -F metadata --format '{{mpris:trackid}}' 2>/dev/null | while read -r _; do
        "$dir/music.sh" >/dev/null 2>&1
    done
    sleep 2
done
