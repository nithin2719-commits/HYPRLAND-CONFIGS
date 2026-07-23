#!/usr/bin/env bash
# Pop all notification history items at once when waybar bell is clicked
count="$(dunstctl count history 2>/dev/null || echo 0)"
if ((count == 0)); then
    notify-send -a "Arch Linux" "No notifications" "Notification history is empty" -t 1500
    exit 0
fi
# Pop up to 10 history items
for ((i=0; i < count && i < 10; i++)); do
    dunstctl history-pop
    sleep 0.05
done
