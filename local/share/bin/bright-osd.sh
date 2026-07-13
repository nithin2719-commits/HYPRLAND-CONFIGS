#!/usr/bin/env bash
set -uo pipefail

STEP=5

case "${1:-}" in
    up)   brightnessctl set "${STEP}%+" >/dev/null 2>&1 || brightnessctl set +5% >/dev/null 2>&1 ;;
    down) brightnessctl set "${STEP}%-" >/dev/null 2>&1 || brightnessctl set 5%- >/dev/null 2>&1 ;;
esac

b_cur="$(brightnessctl get 2>/dev/null || echo 0)"
b_max="$(brightnessctl max 2>/dev/null || echo 100)"
if ((b_max > 0)); then
    b_perc=$(( (b_cur * 100) / b_max ))
else
    b_perc=50
fi

if ((b_perc > 100)); then b_perc=100; fi
if ((b_perc < 0)); then b_perc=0; fi

notify-send -a "brightness" -r 9901 -t 1000 \
    -h "int:value:${b_perc}" \
    -h "string:x-dunst-stack-tag:osd" \
    "Brightness  ${b_perc}%"
