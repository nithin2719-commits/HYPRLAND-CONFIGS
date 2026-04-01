#!/bin/bash
mapfile -t clients < <(hyprctl -j clients | jq -r '.[] | select(.workspace.id > 0) | .address')
current=$(hyprctl -j activewindow | jq -r '.address')
len=${#clients[@]}

for i in "${!clients[@]}"; do
    if [[ "${clients[$i]}" == "$current" ]]; then
        next=$(( (i + 1) % len ))
        hyprctl dispatch focuswindow address:${clients[$next]}
        exit 0
    fi
done

hyprctl dispatch focuswindow address:${clients[0]}
