#!/usr/bin/env bash
# Reminder daemon for the agenda (cal-menu.sh). Three kinds of alert:
#
#   login   once at startup: everything overdue, plus what is due today. This is
#           the "if I forget" case -- a task you never opened the agenda to see.
#   near    two days before a task is due, once per task.
#   due     at the due time, once per task.
#
# Each alert type is recorded in .fired with its own prefix, so a task can warn
# you at T-2days AND again when it is actually due without repeating either.

set -uo pipefail

STORE_DIR="$HOME/.local/share/graphite-cal"
STORE="$STORE_DIR/events.tsv"
FIRED="$STORE_DIR/.fired"
NEAR_DAYS=2
POLL=60

mkdir -p "$STORE_DIR"; touch "$STORE" "$FIRED"

# One instance: two daemons means every reminder twice. flock, not pgrep -- any
# shell that merely mentions this script's name matches a pgrep -f pattern,
# which is how an earlier guard here killed itself instantly.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/cal-remind.lock"
flock -n 9 || exit 0

seen()  { grep -qxF "$1" "$FIRED" 2>/dev/null; }
mark()  { printf '%s\n' "$1" >> "$FIRED"; }

# ---- login summary -------------------------------------------------------
# Waits for a notification daemon to exist: at login this script and dunst race,
# and a notification sent into the void is simply lost.
for _ in $(seq 1 30); do
    busctl --user status org.freedesktop.Notifications >/dev/null 2>&1 && break
    sleep 2
done

now=$(date +%s)
today_end=$(date -d "today 23:59:59" +%s)
overdue=0; due_today=0; lines=""

while IFS=$'\t' read -r epoch state text; do
    [[ -z "${epoch:-}" || "$state" != pending ]] && continue
    if ((epoch < now)); then
        ((overdue++)); lines+="  ▍ ${text}  ·  $(date -d "@$epoch" '+%d %b')"$'\n'
    elif ((epoch <= today_end)); then
        ((due_today++)); lines+="  ▍ ${text}  ·  $(date -d "@$epoch" +%H:%M)"$'\n'
    fi
done < "$STORE"

if ((overdue + due_today > 0)); then
    summary="$overdue overdue"
    ((due_today > 0)) && summary+=" · $due_today due today"
    ((overdue == 0)) && summary="$due_today due today"
    notify-send -u critical -a "Agenda" "$summary" "${lines%$'\n'}" 2>/dev/null
fi

# ---- watch ---------------------------------------------------------------
while true; do
    now=$(date +%s)

    while IFS=$'\t' read -r epoch state text; do
        [[ -z "${epoch:-}" || "$state" != pending ]] && continue

        # Key on epoch+text so rescheduling the same wording can alert again.
        id="$epoch|$text"

        # Two days out, once.
        near_at=$((epoch - NEAR_DAYS * 86400))
        if ((now >= near_at && now < epoch)) && ! seen "near|$id"; then
            days=$(( (epoch - now + 86399) / 86400 ))
            notify-send -a "Agenda" "$text" \
                "in ${days}d  ·  $(date -d "@$epoch" '+%a %d %b %H:%M')" 2>/dev/null
            mark "near|$id"
        fi

        # Due, once.
        if ((now >= epoch)) && ! seen "due|$id"; then
            late=$(( (now - epoch) / 60 ))
            ((late >= 1)) && body="was due ${late}m ago" || body="due now"
            # critical: it waits for you rather than vanishing while you look
            # away. dunstrc still clears it after 20s.
            notify-send -u critical -a "Agenda" "$text" "$body" 2>/dev/null
            mark "due|$id"
        fi
    done < "$STORE"

    sleep "$POLL"
done
