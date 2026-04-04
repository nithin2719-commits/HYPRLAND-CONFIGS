#!/bin/bash

colors=(
    "ff0000" "ff3300" "ff6600" "ff9900" "ffcc00" "ffff00"
    "99ff00" "00ff00" "00ff99" "00ffff" "0099ff" "0000ff"
    "6600ff" "9900ff" "ff00ff" "ff0066"
)

i=0
while true; do
    c1=${colors[$i % ${#colors[@]}]}
    c2=${colors[$(($i + 4)) % ${#colors[@]}]}
    c3=${colors[$(($i + 8)) % ${#colors[@]}]}
    c4=${colors[$(($i + 12)) % ${#colors[@]}]}

    hyprctl keyword general:col.active_border "rgb($c1) rgb($c2) rgb($c3) rgb($c4) 45deg" > /dev/null 2>&1

    i=$(($i + 1))
    sleep 0.15
done
