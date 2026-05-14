#!/usr/bin/env bash
# Live monochrome border: a highlight that sweeps slowly around the focused
# window, replacing the old rainbow rgb.sh.
#
# Why a script at all: Hyprland's own `animation = borderangle, 1, N, linear,
# loop` is configured and reports enabled/style:loop on 0.56.1, but the rendered
# gradient does not advance -- sampled across frames at maximum speed, the
# border pixels are byte-identical. Changing the angle at runtime DOES render,
# so the rotation is driven from here instead.
#
# Cost, versus what this replaces: rgb.sh stepped the angle every 0.03s (33
# hyprctl calls a second, forever). This steps every 0.25s -- 4 a second, an
# eighth of the load -- and takes 15s per revolution, because the point is a
# slow sheen you notice at the edge of your vision, not a spinning light show.

set -uo pipefail

STEP=2            # degrees per tick
PERIOD=0.035      # -> 360/2 * 0.035 = 6.3s per revolution, ~29 updates/sec
                  # Smoothness is the STEP, not the period: 6 degrees every
                  # 0.17s covers the same ground but arrives in visible jumps.
                  # 2 degrees every 0.07s is the same 12s lap, gliding.

# A COMET, not an even fade. The five evenly-bright stops this replaces washed
# the whole border pale and the rotation was barely perceptible; here one short
# white head runs into a long dark tail, so there is a definite bright point
# travelling around the window. Stops are unevenly weighted on purpose:
#   white -> silver, then a long fall through graphite to near-black, and only
#   at the very end back to white, which is the wrap point.
GRADIENT="rgba(ffffffff) rgba(dededfee) rgba(6e6e78cc) rgba(2a2a30bb) rgba(1a1a20aa) rgba(2a2a30bb) rgba(ffffffff)"

# One instance only: a second copy would fight the first over the same option
# and produce a stutter rather than a sweep.
#
# flock, NOT `pgrep -f border-sheen.sh`: any shell that merely MENTIONS this
# script -- the terminal you launch it from, a hyprland exec-once line -- has
# the name in its own command line, so pgrep matches it and the script decides
# it is a duplicate and exits instantly. Which is exactly what happened.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/border-sheen.lock"
flock -n 9 || exit 0

# Leave the border in a sane static state if we are stopped.
trap 'hyprctl keyword general:col.active_border "$GRADIENT 45deg" >/dev/null 2>&1; exit 0' TERM INT HUP

angle=0
while true; do
    hyprctl keyword general:col.active_border "$GRADIENT ${angle}deg" >/dev/null 2>&1
    angle=$(((angle + STEP) % 360))
    sleep "$PERIOD"
done
