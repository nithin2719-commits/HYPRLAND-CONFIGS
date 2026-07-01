#!/usr/bin/env bash
# Toggle the dashboard (plus its click-catcher), starting the daemon if needed.
eww ping >/dev/null 2>&1 || eww daemon >/dev/null 2>&1

open=$(eww active-windows 2>/dev/null | grep -c '^dashboard')

if [[ $1 == close || $open -gt 0 ]]; then
    eww close dashboard >/dev/null 2>&1
    rm -f "$HOME/.cache/eww/dash-open"
    # Give Escape back to whatever else wants it.
    hyprctl keyword unbind ,escape >/dev/null 2>&1
else
    # Always come up on the current month, whatever was browsed last time.
    echo 0 > "$HOME/.cache/eww/cal_offset"
    eww update todo_date="" todo_draft="" >/dev/null 2>&1
    # Revealers that map already-open stay collapsed, so the picker always
    # starts closed and animates from there.
    eww update netpanel="" netask="" netpass="" >/dev/null 2>&1
    eww update cal="$(~/.config/eww/scripts/cal.sh 0)" >/dev/null 2>&1

    : > "$HOME/.cache/eww/dash-open"

    # Push the state the eye lands on first. Without this the radio pills show
    # their initial "off" for up to a poll interval after opening, which reads
    # as "my wifi is off" rather than "this has not refreshed yet".
    eww update radios="$(~/.config/eww/scripts/radios.sh state)" >/dev/null 2>&1
    eww update music="$(~/.config/eww/scripts/music.sh)" >/dev/null 2>&1

    eww open dashboard

    # Warm the picker caches in the background so a double click on Wi-Fi or
    # Bluetooth has a current list to show instantly.
    ( for k in wifi bt; do
          out=$(~/.config/eww/scripts/nets.sh "$k" list 2>/dev/null)
          printf '%s' "$out" | jq -e 'type == "array"' >/dev/null 2>&1 &&
              printf '%s' "$out" > "$HOME/.cache/eww/netlist-$k.json"
      done ) >/dev/null 2>&1 &
    # Escape closes the panel, but only while it is up: registering the bind at
    # open time and dropping it at close keeps the key free for everything else.
    hyprctl keyword bind ,escape,exec,~/.config/eww/scripts/toggle.sh close >/dev/null 2>&1
fi
