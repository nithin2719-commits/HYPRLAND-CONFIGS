#!/usr/bin/env bash
set -uo pipefail

STEP="5%"

case "${1:-}" in
    up)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}+" --limit 1.0 2>/dev/null
        ;;
    down)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 2>/dev/null
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "${STEP}-" 2>/dev/null
        ;;
    mute)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null
        ;;
esac

# Read wpctl volume and mute state
raw="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || echo "Volume: 0.50")"

if [[ "$raw" == *"[MUTED]"* ]]; then
    title="Volume  Muted"
    value=0
else
    num="$(echo "$raw" | awk '{print $2}')"
    value="$(python3 -c "print(min(100, max(0, int(round(float('$num') * 100)))))" 2>/dev/null || echo 50)"
    title="Volume  ${value}%"
fi

notify-send -a "volume" -r 9901 -t 1000 \
    -h "int:value:${value}" \
    -h "string:x-dunst-stack-tag:osd" \
    "${title}"
