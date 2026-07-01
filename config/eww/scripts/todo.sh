#!/usr/bin/env bash
# JSON-backed todo store for the dashboard.
#   todo.sh list                 -> JSON array [{id,text,done,due,overdue,duelabel}]
#   todo.sh add "text" [YYYY-MM-DD]
#   todo.sh toggle <id>
#   todo.sh del <id>
#   todo.sh clear                -> drop finished items
#   todo.sh remind               -> desktop notification for anything due/overdue
#
# An item keeps nagging (see remind, wired to login) until it is ticked off,
# which is the point: a due date you can ignore is not a due date.

store="$HOME/.local/share/eww/todo.json"
mkdir -p "$(dirname "$store")"
[[ -s $store ]] || echo '[]' > "$store"

# Never let a failed jq blank the board: validate, keep a backup, swap atomically.
write() {
    local new=$1
    [[ -n $new ]] && printf '%s' "$new" | jq -e 'type == "array"' >/dev/null 2>&1 || {
        echo "todo.sh: refusing to write invalid store" >&2; return 1; }
    cp -f "$store" "$store.bak" 2>/dev/null
    printf '%s\n' "$new" > "$store.tmp" && mv -f "$store.tmp" "$store"
}
today=$(date +%F)

case "$1" in
  list)
      # Decorate each item with how its due date reads today.
      jq -c --arg today "$today" '
        [ .[] | . + {
            due:      (.due // ""),
            overdue:  ((.due // "") != "" and .done == false and .due < $today),
            duelabel: (
              if (.due // "") == "" then ""
              elif .due == $today then "today"
              else (.due | strptime("%Y-%m-%d") | strftime("%d %b"))
              end)
          } ]
        # undone first, then by due date (dated before undated), then newest
        | sort_by(.done, (if .due == "" then "9999-99-99" else .due end), .id)
      ' "$store"
      ;;
  add)
      text=$(printf '%s' "$2" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [[ -z $text ]] && exit 0
      due=${3:-}
      [[ $due =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || due=""
      write "$(jq -c --arg t "$text" --arg d "$due" \
          '. + [{id:((map(.id)|max // 0) + 1), text:$t, done:false, due:$d}]' "$store")"
      ;;
  toggle)
      write "$(jq -c --argjson i "$2" \
          'map(if .id == $i then .done = (.done | not) else . end)' "$store")" ;;
  del)
      write "$(jq -c --argjson i "$2" 'map(select(.id != $i))' "$store")" ;;
  clear)
      write "$(jq -c 'map(select(.done | not))' "$store")" ;;
  remind)
      # Nag at every login while the day is still ahead, and go quiet once it
      # has passed: a reminder for a date that is gone is just noise.
      jq -r --arg today "$today" '
        .[] | select(.done == false and (.due // "") != "" and .due >= $today)
        | "\(.due)\t\(.text)"' "$store" |
      while IFS=$'\t' read -r due text; do
          # Task first, date underneath: the summary is what you read at a
          # glance, and "buy cable" is more useful there than "due Wednesday".
          if [[ $due == "$today" ]]; then
              notify-send -u critical -a Todo "$text" "Due today"
          else
              days=$(( ( $(date -d "$due" +%s) - $(date -d "$today" +%s) ) / 86400 ))
              [[ $days -eq 1 ]] && when="tomorrow" || when="in $days days"
              notify-send -u normal -a Todo "$text" \
                  "Due $(date -d "$due" +'%A %d %B') · $when"
          fi
      done
      ;;
  *) echo "usage: todo.sh list|add|toggle|del|clear|remind" >&2; exit 1 ;;
esac
