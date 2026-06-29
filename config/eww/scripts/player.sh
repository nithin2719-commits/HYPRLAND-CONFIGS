#!/usr/bin/env bash
# Run a playerctl command against whichever player is actually playing.
# With Spotify and a browser both on the bus, bare playerctl answers for the
# one that registered first, so the buttons would drive the wrong player.
player=""
while read -r p; do
    [[ -z $p ]] && continue
    [[ -z $player ]] && player=$p
    if [[ $(playerctl -p "$p" status 2>/dev/null) == Playing ]]; then player=$p; break; fi
done < <(playerctl -l 2>/dev/null)

if [[ -n $player ]]; then
    exec playerctl -p "$player" "$@"
else
    exec playerctl "$@"
fi
