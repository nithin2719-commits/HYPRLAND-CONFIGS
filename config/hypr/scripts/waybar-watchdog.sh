#!/usr/bin/env bash
# Supervise waybar: respawn it when it crashes, leave it down when it is killed
# on purpose (Ctrl+Alt+W toggle, wbarconfgen.sh bar switching).
#
# Background: waybar 0.15.0 on gtk3 3.24.52 segfaults inside libgdk-3 while
# dispatching wayland events (cursor buffer handling) after the GTK cursor
# theme is reloaded -- HyDE's theme switching runs
# `gsettings set org.gnome.desktop.interface cursor-theme ...`, which frees the
# wl_cursor_theme while waybar still holds pointers into it. The bar then dies
# the next time the pointer moves over it. Nothing restarts it, so the bar
# looks like it "hides" permanently.
#
# Handover: wbarconfgen.sh restarts the bar by running `killall waybar` and then
# immediately launching a new supervisor. The new supervisor therefore has to
# take the lock away from the outgoing one instead of giving up on it -- doing
# the latter leaves *no* waybar running at all, which is what made a theme
# change look like it killed the bar for good.

set -u

# Default config: the graphite bar.
#
# This is the single source of truth for WHICH bar comes up. Several things
# restart waybar behind your back -- HyDE's wbarconfgen.sh on every theme or
# wallpaper change, gamemode.sh, a bare `waybar` -- and each of them used to
# decide the config for itself. That is why the bar vanished after a theme
# switch: wbarconfgen killed the running bar and relaunched it against HyDE's
# regenerated config.jsonc, so a design living anywhere else was gone.
#
# Now a caller that does not name a config gets the graphite one. Callers that
# pass -c/--config explicitly are still respected, so nothing is taken away.
graphite_conf="$HOME/.config/waybar/graphite/config.jsonc"
graphite_style="$HOME/.config/waybar/graphite/style.css"
case " ${*:-} " in
    *" -c "* | *" --config "*) : ;;             # caller chose: leave it alone
    *)
        if [ -f "$graphite_conf" ]; then
            set -- -c "$graphite_conf" -s "$graphite_style" ${@:+"$@"}
        fi
        ;;
esac

runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
# .v2 because the old lock file is permanently poisoned: fd 9 leaked into every
# process this script ever spawned (see the 9>&- below), and any surviving
# grandchild -- a kitty that outlived its launch -- keeps holding the lock. A
# new supervisor then waited 10s on flock and exited silently, which looked
# exactly like "the bar just does not start any more". Nothing can revoke that
# leaked fd, so the fix is a new name plus not leaking it again.
lock_file="$runtime_dir/waybar-watchdog.v2.lock"
pid_file="$runtime_dir/waybar-watchdog.v2.pid"

# Only one supervisor at a time -- but the newest one wins.
exec 9>"$lock_file"
if ! flock -n 9; then
    old_pid="$(cat "$pid_file" 2>/dev/null || true)"
    old_pid="${old_pid//[!0-9]/}"
    if [ -n "$old_pid" ] && [ "$old_pid" -ne $$ ]; then
        kill -TERM "$old_pid" 2>/dev/null
    fi
    # Wait for it to let go. If it will not, stay out rather than run two.
    flock -w 10 9 || exit 0
fi
echo $$ >"$pid_file"

waybar_pid=0
shutting_down=0

cleanup() {
    shutting_down=1
    if [ "$waybar_pid" -gt 0 ]; then
        kill -TERM "$waybar_pid" 2>/dev/null
        wait "$waybar_pid" 2>/dev/null
    fi
    [ "$(cat "$pid_file" 2>/dev/null)" = "$$" ] && rm -f "$pid_file"
    exit 0
}
trap cleanup TERM INT HUP

max_restarts=10   # give up after this many crashes ...
window=60         # ... within this many seconds
restarts=0
window_start=$SECONDS

while true; do
    # 9>&- closes the lock fd in the child. Without it waybar -- and anything
    # waybar ever spawns, a terminal from a click action included -- inherits
    # the lock and holds it for its whole life, long after this supervisor is
    # gone.
    waybar "$@" 9>&- &
    waybar_pid=$!
    wait "$waybar_pid"
    status=$?
    waybar_pid=0

    # Superseded by a newer supervisor (or logging out) -> just go away.
    [ "$shutting_down" -eq 1 ] && exit 0

    case $status in
        0 | 130 | 143)
            # clean exit / SIGINT / SIGTERM -> intentional, stay down
            [ "$(cat "$pid_file" 2>/dev/null)" = "$$" ] && rm -f "$pid_file"
            exit 0
            ;;
    esac

    # Reset the counter once the crash window has elapsed.
    if ((SECONDS - window_start > window)); then
        restarts=0
        window_start=$SECONDS
    fi

    restarts=$((restarts + 1))
    if ((restarts > max_restarts)); then
        notify-send -u critical "waybar" \
            "Crashed $restarts times in ${window}s (last exit $status). Not restarting." 2>/dev/null
        [ "$(cat "$pid_file" 2>/dev/null)" = "$$" ] && rm -f "$pid_file"
        exit 1
    fi

    sleep 1
done
