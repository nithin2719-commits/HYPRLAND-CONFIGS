#!/usr/bin/env bash
# Tick or delete a todo and push the new list straight into eww.
#   todo_click.sh toggle|del <id>
# The list poll is deliberately slow (a subprocess every couple of seconds for
# something that only changes when you click is waste), so the click has to
# publish the result itself or the row would sit there looking unresponsive.
dir="$(dirname "$0")"

"$dir/todo.sh" "${1:-}" "${2:-}" >/dev/null 2>&1
eww update todos="$("$dir/todo.sh" list)" >/dev/null 2>&1
