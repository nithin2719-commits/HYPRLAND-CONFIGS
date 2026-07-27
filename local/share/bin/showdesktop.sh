#!/bin/bash
SPECIAL=$(hyprctl clients -j | jq '[.[] | select(.workspace.name == "special:minimize")] | length')
if [ "$SPECIAL" -gt 0 ]; then
    hyprctl clients -j | jq -r '.[] | select(.workspace.name == "special:minimize") | .address' | xargs -I{} hyprctl dispatch movetoworkspace e+0,address:{}
else
    hyprctl clients -j | jq -r '.[].address' | xargs -I{} hyprctl dispatch movetoworkspacesilent special:minimize,address:{}
fi
