#!/usr/bin/env bash
# Single click toggles the radio, double click opens the inline picker.
#   radio_click.sh wifi|bt
#
# GTK/eww give us plain clicks only, so the distinction is made here: the first
# click parks briefly; if a second lands in that window the pending toggle is
# cancelled and the panel opens instead.
#
# The panel opens from a cached list so it is on screen immediately — scanning
# takes seconds, and waiting for it made the double click feel broken.
kind=${1:-wifi}
dir="$(dirname "$0")"
cache="$HOME/.cache/eww/netlist-$kind.json"
mark="$HOME/.cache/eww/.click-$kind"
mkdir -p "$(dirname "$mark")"

refresh() {
    local out
    out=$("$dir/nets.sh" "$kind" list 2>/dev/null)
    # A truncated or empty result would blank a list the user is looking at.
    if printf '%s' "$out" | jq -e 'type == "array" and length > 0' >/dev/null 2>&1; then
        printf '%s' "$out" > "$cache"
        eww update netlist="$out" >/dev/null 2>&1
    fi
}

if [[ -f $mark ]]; then
    rm -f "$mark"

    # Straight to the screen with whatever was found last time.
    if [[ -s $cache ]]; then
        eww update netpanel="$kind" netlist="$(cat "$cache")" >/dev/null 2>&1
    else
        eww update netpanel="$kind" netlist="[]" >/dev/null 2>&1
    fi

    # Then bring it up to date without holding anything up.
    (
        [[ $kind == wifi ]] && "$dir/nets.sh" wifi rescan || "$dir/nets.sh" bt scan
        refresh
        sleep 2
        refresh          # a scan started above usually lands within a second or two
    ) >/dev/null 2>&1 &
    exit 0
fi

: > "$mark"
sleep 0.25
if [[ -f $mark ]]; then
    rm -f "$mark"
    "$dir/radios.sh" "$kind" >/dev/null 2>&1 &
fi
