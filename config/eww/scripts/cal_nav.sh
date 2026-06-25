#!/usr/bin/env bash
# Move the dashboard calendar by <delta> months, or "reset" to today.
dir="$(dirname "$0")"
f="$HOME/.cache/eww/cal_offset"
mkdir -p "$(dirname "$f")"

cur=$(cat "$f" 2>/dev/null || echo 0)
case "$1" in
    reset) new=0 ;;
    *)     new=$(( cur + ${1:-0} )) ;;
esac

echo "$new" > "$f"
eww update cal="$("$dir/cal.sh" "$new")"
