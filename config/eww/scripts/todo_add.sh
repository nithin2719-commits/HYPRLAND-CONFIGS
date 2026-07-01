#!/usr/bin/env bash
# File the dashboard's inline entry as a todo, then reset entry + date chip.
#   todo_add.sh "text"
# The due date is read back from eww rather than passed in: interpolating it
# into the widget would rebuild the entry every time a day is picked, which
# drops whatever is half-typed.
dir="$(dirname "$0")"

text=${1:-}
due=$(eww get todo_date 2>/dev/null)

[[ -n ${text//[[:space:]]/} ]] || exit 0

"$dir/todo.sh" add "$text" "$due"

eww update todo_draft="" todo_date=""
eww update todos="$("$dir/todo.sh" list)"
