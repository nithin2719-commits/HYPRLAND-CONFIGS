#!/bin/bash

# wait for hyprland to fully load
sleep 2

# prevent duplicates
pgrep -f rgb.sh && exit

angle=0

while true; do
    hyprctl keyword general:col.active_border "rgba(ff0000ff) rgba(00ff00ff) rgba(0000ffff) rgba(ff00ffff) ${angle}deg"
    angle=$(( (angle + 2) % 360 ))
    sleep 0.03
done
