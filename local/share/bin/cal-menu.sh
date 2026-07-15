#!/usr/bin/env bash
# Agenda for the bar's clock — pick a date, then work on that date's tasks.
#
# Two screens:
#   MONTH  every day of the month as its own row, marked with how many tasks it
#          holds, today highlighted. ‹ › move between months.
#   DAY    that date's tasks. Add, tick off, delete. Esc goes back to the month.
#
# This replaced a single "type when + what" prompt, which asked you to know the
# date before you could see the calendar -- backwards for anything more than a
# quick reminder.
#
# Storage: ~/.local/share/graphite-cal/events.tsv
#   epoch <TAB> state(pending|done) <TAB> text
# Plain text: greppable, editable in any editor, readable without this script.
# cal-remind.sh watches the same file for due, near (2 days) and login alerts.
#
# Keys:  Enter = open / toggle   ·   Ctrl+X = delete   ·   Esc = back
#
# Ctrl+X and not Ctrl+D: rofi binds Control+d internally and REFUSES TO START on
# a collision -- it showed an error dialog instead of the agenda.

set -uo pipefail

THEME="$HOME/.config/rofi/graphite.rasi"
STORE_DIR="$HOME/.local/share/graphite-cal"
STORE="$STORE_DIR/events.tsv"
mkdir -p "$STORE_DIR"; touch "$STORE"

BONE='#e6e6ea'; DIM='#9b9ba4'; FAINT='#6e6e78'; DONE='#5c5c66'

escape() { sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

today_ymd="$(date +%Y-%m-%d)"

# Tasks for one Y-M-D, as "epoch<TAB>state<TAB>text" lines, soonest first.
tasks_on() {
    local ymd="$1"
    awk -F'\t' -v d="$ymd" 'NF>=3 { if (strftime("%Y-%m-%d", $1) == d) print }' "$STORE" 2>/dev/null | sort -n
}

count_on() { tasks_on "$1" | wc -l; }
pending_on() { tasks_on "$1" | awk -F'\t' '$2=="pending"' | wc -l; }

# ---------------------------------------------------------------- day view
day_view() {
    local ymd="$1"
    while true; do
        local menu rows=() n=0
        menu="$(printf "<span foreground='%s'>＋  add a task to this date</span>" "$BONE")"$'\n'

        while IFS=$'\t' read -r epoch state text; do
            [[ -z "${epoch:-}" ]] && continue
            rows+=("$epoch"$'\t'"$state"$'\t'"$text"); ((n++))
            local esc time_lbl
            esc="$(printf '%s' "$text" | escape)"
            time_lbl="$(date -d "@$epoch" +%H:%M)"
            if [[ "$state" == done ]]; then
                menu+="$(printf "<span foreground='%s'>󰄬  <s>%s</s>  ·  %s</span>" "$DONE" "$esc" "$time_lbl")"$'\n'
            elif ((epoch < $(date +%s))); then
                menu+="$(printf "<span foreground='%s'>󰄰  %s</span>  <span foreground='%s'>· %s · overdue</span>" "$BONE" "$esc" "$FAINT" "$time_lbl")"$'\n'
            else
                menu+="$(printf "<span foreground='%s'>󰄰  %s</span>  <span foreground='%s'>· %s</span>" "$DIM" "$esc" "$FAINT" "$time_lbl")"$'\n'
            fi
        done < <(tasks_on "$ymd")

        ((n == 0)) && menu+="$(printf "<span foreground='%s'>nothing on this date yet</span>" "$FAINT")"$'\n'
        menu+="$(printf "<span foreground='%s'>‹  back to the month</span>" "$FAINT")"

        local sel rc
        sel="$(printf '%s' "$menu" | rofi -dmenu -i -markup-rows -format i -theme "$THEME" \
                -theme-str 'window { width: 560px; } listview { lines: 10; }' \
                -p "$(date -d "$ymd" '+%a %d %b')" -kb-custom-1 'Control+x' \
                -mesg "$(printf "<span foreground='%s'>%s</span>  <span foreground='%s'>· enter ticks off · ctrl+x deletes · esc back</span>" \
                         "$BONE" "$(date -d "$ymd" '+%A %d %B %Y')" "$FAINT")")"
        rc=$?
        [[ -z "$sel" ]] && return 0

        if ((sel == 0)); then
            local entry hhmm text epoch
            entry="$(printf '' | rofi -dmenu -theme "$THEME" -p "task" \
                     -mesg "$(printf "<span foreground='%s'>%s</span>  <span foreground='%s'>· optionally start with a time: 14:30 buy milk</span>" \
                              "$BONE" "$(date -d "$ymd" '+%a %d %b')" "$FAINT")")"
            [[ -z "$entry" ]] && continue
            # A leading HH:MM sets the time; without one the task lands at 09:00,
            # which is when a day's reminders should arrive anyway.
            if [[ "$entry" =~ ^([0-2]?[0-9]:[0-5][0-9])[[:space:]]+(.*)$ ]]; then
                hhmm="${BASH_REMATCH[1]}"; text="${BASH_REMATCH[2]}"
            else
                hhmm="09:00"; text="$entry"
            fi
            epoch="$(date -d "$ymd $hhmm" +%s 2>/dev/null)" || continue
            printf '%s\t%s\t%s\n' "$epoch" "pending" "$text" >> "$STORE"
            notify-send -a "Agenda" "Added" "$text  ·  $(date -d "@$epoch" '+%a %d %b %H:%M')" 2>/dev/null
            continue
        fi

        local idx=$((sel - 1))
        ((idx < 0 || idx >= n)) && return 0        # the "back" row (or empty row)

        IFS=$'\t' read -r epoch state text <<< "${rows[$idx]}"
        if ((rc == 10)); then
            grep -vxF "$(printf '%s\t%s\t%s' "$epoch" "$state" "$text")" "$STORE" > "$STORE.tmp" && mv "$STORE.tmp" "$STORE"
            notify-send -a "Agenda" "Deleted" "$text" 2>/dev/null
        else
            local new=pending; [[ "$state" == pending ]] && new=done
            awk -F'\t' -v OFS='\t' -v e="$epoch" -v t="$text" -v st="$new" \
                '$1==e && $3==t {$2=st} {print}' "$STORE" > "$STORE.tmp" && mv "$STORE.tmp" "$STORE"
            [[ "$new" == done ]] && notify-send -a "Agenda" "Done" "$text" 2>/dev/null
        fi
    done
}

# -------------------------------------------------------------- month view
month="$(date +%Y-%m)"

while true; do
    first="$month-01"
    days_in="$(date -d "$first +1 month -1 day" +%d)"
    label="$(date -d "$first" '+%B %Y')"

    menu="$(printf "<span foreground='%s'>‹  %s</span>" "$FAINT" "$(date -d "$first -1 month" '+%B')")"$'\n'
    menu+="$(printf "<span foreground='%s'>›  %s</span>" "$FAINT" "$(date -d "$first +1 month" '+%B')")"$'\n'

    declare -a dates=()
    for ((d = 1; d <= days_in; d++)); do
        ymd="$(printf '%s-%02d' "$month" "$d")"
        dates+=("$ymd")
        cnt="$(count_on "$ymd")"; pend="$(pending_on "$ymd")"
        dow="$(date -d "$ymd" '+%a')"
        # Dots, one per task, so a busy day is visible without reading numbers.
        marks=""
        for ((i = 0; i < cnt && i < 6; i++)); do marks+="●"; done
        ((cnt > 6)) && marks+="+"

        if [[ "$ymd" == "$today_ymd" ]]; then
            menu+="$(printf "<span foreground='%s'><b>%s %02d  ·  today</b></span>  <span foreground='%s'>%s</span>" \
                     "$BONE" "$dow" "$d" "$DIM" "$marks")"$'\n'
        elif ((pend > 0)); then
            menu+="$(printf "<span foreground='%s'>%s %02d</span>  <span foreground='%s'>%s</span>" \
                     "$DIM" "$dow" "$d" "$FAINT" "$marks")"$'\n'
        else
            menu+="$(printf "<span foreground='%s'>%s %02d</span>  <span foreground='%s'>%s</span>" \
                     "$FAINT" "$dow" "$d" "$DONE" "$marks")"$'\n'
        fi
    done

    total_pending="$(awk -F'\t' '$2=="pending"' "$STORE" 2>/dev/null | wc -l)"
    sel="$(printf '%s' "$menu" | rofi -dmenu -i -markup-rows -format i -theme "$THEME" \
            -theme-str 'window { width: 520px; } listview { lines: 14; }' \
            -p "$label" \
            -mesg "$(printf "<span foreground='%s'>%s</span>  <span foreground='%s'>· %s pending · pick a date</span>" \
                     "$BONE" "$label" "$FAINT" "$total_pending")")"
    [[ -z "$sel" ]] && exit 0

    case "$sel" in
        0) month="$(date -d "$first -1 month" +%Y-%m)" ;;
        1) month="$(date -d "$first +1 month" +%Y-%m)" ;;
        *) day_view "${dates[$((sel - 2))]}" ;;
    esac
done
