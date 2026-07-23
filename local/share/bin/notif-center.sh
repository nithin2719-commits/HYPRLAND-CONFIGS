#!/usr/bin/env bash
# Notification centre — dunst history plus the dashboard's pending todos, in
# the bar's own rofi surface (~/.config/rofi/graphite.rasi).
#
# Two things it does that the old version did not:
#   * it always opens. Exiting silently when history was empty made the bell
#     look broken, which is exactly when you press it to check.
#   * it lists todos that are due, because "what needs my attention" is one
#     question, not two. Picking one ticks it off.
#
# Picking a notification pops it back on screen; picking a todo completes it.

THEME="$HOME/.config/rofi/graphite.rasi"
TODO="$HOME/.config/eww/scripts/todo.sh"

paused=$(dunstctl is-paused 2>/dev/null)

# ── todos ────────────────────────────────────────────────────────────────
todo_rows=""
todo_count=0
if [[ -x $TODO ]]; then
    while IFS=$'\t' read -r id text due label overdue; do
        [[ -z $id ]] && continue
        esc=${text//&/&amp;}; esc=${esc//</&lt;}; esc=${esc//>/&gt;}
        (( ${#esc} > 34 )) && esc="${esc:0:31}..."
        if [[ $overdue == true ]]; then
            when="<span foreground='#ff8f8f'><i>$label</i></span>"
        elif [[ -n $label ]]; then
            when="<span foreground='#7d7d87'><i>$label</i></span>"
        else
            when=""
        fi
        todo_rows+="todo:$id||<span foreground='#ededf0'>󰄱  <b>$esc</b></span>  $when"$'\n'
        todo_count=$((todo_count + 1))
    done < <("$TODO" list 2>/dev/null |
             jq -r '.[] | select(.done == false)
                    | [.id, .text, .due, .duelabel, (.overdue|tostring)] | @tsv')
fi

# ── notifications ────────────────────────────────────────────────────────
notif_rows=$(dunstctl history 2>/dev/null | python3 -c "
import sys, json, time, html

try:
    items = json.load(sys.stdin).get('data', [[]])[0]
except Exception:
    sys.exit(0)

icons = {'whatsapp': '󰖣', 'zapzap': '󰖣', 'telegram': '󰔁', 'discord': '󰙯',
         'gmail': '󰊫', 'mail.google': '󰊫', 'google': '󰊫', 'slack': '󰒱',
         'chrome': '󰈹', 'chromium': '󰈹', 'firefox': '󰈹', 'todo': '󰄱',
         'network': '󰤨', 'bluetooth': '󰂯', 'recorder': '󰕧', 'arch linux': '󰣇'}
skip_apps = {'volume', 'brightness', 'osd'}
now = time.time()

for it in items:
    g = lambda k, d='': it.get(k, {}).get('data', d)
    app, summary, body = g('appname', 'unknown'), g('summary'), g('body')
    if app.lower() in skip_apps:
        continue

    icon = next((v for k, v in icons.items() if k in app.lower()), '󰂜')
    age = ''
    ts = g('timestamp', 0)
    if ts:
        s = int(now - ts / 1_000_000)
        if 0 <= s < 604800:
            age = 'now' if s < 60 else f'{s//60}m' if s < 3600 else \
                  f'{s//3600}h' if s < 86400 else f'{s//86400}d'

    text = summary or body
    if len(text) > 30:
        text = text[:27] + '...'
    row = (f\"<span foreground='#ededf0'>{icon}  <b>{html.escape(app)}</b></span>\"
           f\"  <span foreground='#b6b6c0'>{html.escape(text)}</span>\")
    if age:
        row += f\"  <span foreground='#7d7d87'><i>{age}</i></span>\"
    print(f\"notif:{g('id', 0)}||{row}\")
" 2>/dev/null)

notif_count=0
[[ -n $notif_rows ]] && notif_count=$(printf '%s\n' "$notif_rows" | grep -c .)

# ── build the menu ───────────────────────────────────────────────────────
rows=""
[[ -n $todo_rows  ]] && rows+="$todo_rows"
[[ -n $notif_rows ]] && rows+="$notif_rows"$'\n'

if (( todo_count == 0 && notif_count == 0 )); then
    rows+="none||<span foreground='#7d7d87'>󰂛  nothing pending</span>"$'\n'
fi

if [[ $paused == true ]]; then
    rows+="dnd||<span foreground='#ffffff'>󰂛  resume notifications</span>"$'\n'
else
    rows+="dnd||<span foreground='#b6b6c0'>󰂚  do not disturb</span>"$'\n'
fi
(( notif_count > 0 )) && rows+="clear||<span foreground='#ff8f8f'>󰅖  clear history</span>"$'\n'

mesg="$todo_count todo · $notif_count notification"
(( notif_count == 1 )) || mesg+="s"

chosen=$(printf '%s' "$rows" | sed 's/^[^|]*||//' |
         rofi -dmenu -i -markup-rows -theme "$THEME" \
              -p "notifications" -mesg "$mesg" -format i 2>/dev/null)
[[ -z $chosen ]] && exit 0

key=$(printf '%s' "$rows" | grep -c . >/dev/null; printf '%s' "$rows" |
      sed -n "$((chosen + 1))p" | cut -d'|' -f1)

case "$key" in
    todo:*)  "$TODO" toggle "${key#todo:}"
             eww update todos="$("$TODO" list)" >/dev/null 2>&1 ;;
    notif:*) dunstctl history-pop "${key#notif:}" >/dev/null 2>&1 ;;
    dnd)     dunstctl set-paused toggle ;;
    clear)   dunstctl history-clear ;;
esac
