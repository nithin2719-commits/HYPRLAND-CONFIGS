#!/usr/bin/env bash
# Waybar custom/notifications exec script for dunst.
# Outputs JSON: icon with count, tooltip listing recent app notifications.

history="$(dunstctl count history 2>/dev/null || echo 0)"
displayed="$(dunstctl count displayed 2>/dev/null || echo 0)"
paused="$(dunstctl is-paused 2>/dev/null || echo false)"

# Build tooltip with recent notification app names from history
tooltip="Notifications"
if ((history > 0)); then
    # Get recent history entries (dunstctl history outputs JSON)
    apps="$(dunstctl history 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    entries = data.get('data', [[]])[0] if isinstance(data.get('data'), list) else []
    seen = []
    for e in entries[:8]:
        app = e.get('appname', {}).get('data', 'Unknown')
        summary = e.get('summary', {}).get('data', '')
        line = f'{app}: {summary}'
        if line not in seen:
            seen.append(line)
    print('\n'.join(seen[:6]))
except:
    print('Error reading history')
" 2>/dev/null)"
    if [[ -n "$apps" ]]; then
        # Escape for JSON
        apps_escaped="$(echo "$apps" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')"
        tooltip="${history} in history\\n${apps_escaped}"
    else
        tooltip="${history} notification(s) in history"
    fi
fi

if [[ "$paused" == "true" ]]; then
    icon="󰂛"
    class="dnd"
elif ((displayed > 0)); then
    icon="󰂚"
    class="active"
elif ((history > 0)); then
    icon="󰂜 ${history}"
    class="idle"
else
    icon="󰂜"
    class="idle"
fi

printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' "$icon" "$tooltip" "$class"
