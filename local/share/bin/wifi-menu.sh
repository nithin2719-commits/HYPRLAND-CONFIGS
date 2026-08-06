#!/usr/bin/env bash
# Wi-Fi picker for the bar's network chip.
#
# Replaces `kitty -e nmtui`, which was the wrong tool for a click: nmtui opened
# in a tiny terminal with its own light-on-blue palette, and its first screen is
# a menu ("Please select an option") rather than a network list -- so a click on
# the wifi icon showed no networks and no obvious way to connect.
#
# This lists real networks straight away, connects on Enter, and only asks for a
# password when NetworkManager actually needs one (a saved connection or an open
# network never prompts).

set -uo pipefail

THEME="$HOME/.config/rofi/graphite.rasi"
ROFI=(rofi -dmenu -i -markup-rows -theme "$THEME" -p "wifi")

BONE='#e6e6ea'; DIM='#9b9ba4'; FAINT='#6e6e78'

notify() { notify-send -a "Network" "$1" "${2:-}" 2>/dev/null; }

# Signal strength as four bars, so scanning the list is visual rather than
# reading two-digit numbers.
bars() {
    local s="${1:-0}"
    if   ((s >= 75)); then printf '󰤨'
    elif ((s >= 50)); then printf '󰤥'
    elif ((s >= 25)); then printf '󰤢'
    else                   printf '󰤟'
    fi
}

pango_escape() { sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

if [[ "$(nmcli -t radio wifi 2>/dev/null)" == "disabled" ]]; then
    if [[ "$(printf 'enable wi-fi\ncancel' | "${ROFI[@]}" -mesg "wi-fi is off")" == "enable wi-fi" ]]; then
        nmcli radio wifi on && notify "Wi-Fi enabled" "scanning…"
    fi
    exit 0
fi

# --rescan auto, NOT yes. `yes` forces a fresh scan and BLOCKS for 3-8
# seconds before rofi can even open -- the click looked like it did nothing,
# which is exactly when you give up and reach for something else. The cached
# list opens in ~20ms; a rescan runs in the background for next time.
nmcli device wifi rescan >/dev/null 2>&1 &
mapfile -t rows < <(nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY \
                          device wifi list --rescan auto 2>/dev/null)

menu=""; declare -a ssids=()
seen=""
for row in "${rows[@]}"; do
    # nmcli escapes colons inside fields as '\:', so split on unescaped ones.
    IFS=':' read -r inuse ssid signal security <<< "${row//\\:/§}"
    ssid="${ssid//§/:}"
    [[ -z "$ssid" ]] && continue
    # The same SSID appears once per band/AP; keep the strongest, which is the
    # first row since nmcli sorts by signal.
    [[ "$seen" == *"|$ssid|"* ]] && continue
    seen+="|$ssid|"

    lock="󰌾"; [[ -z "$security" || "$security" == "--" ]] && lock="󰌿"
    mark=" "; colour="$DIM"
    [[ "$inuse" == "*" ]] && { mark="󰄬"; colour="$BONE"; }

    esc="$(printf '%s' "$ssid" | pango_escape)"
    menu+="$(printf "<span foreground='%s'>%s %s  %s</span>  <span foreground='%s'>%s %s%%</span>" \
             "$colour" "$mark" "$(bars "$signal")" "$esc" "$FAINT" "$lock" "$signal")"$'\n'
    ssids+=("$ssid")
done

if ((${#ssids[@]} == 0)); then
    notify "No networks found" "try again in a moment"
    exit 0
fi

menu+="$(printf "<span foreground='%s'>󰖪  turn wi-fi off</span>" "$FAINT")"$'\n'
menu+="$(printf "<span foreground='%s'>󰢻  advanced settings…</span>" "$FAINT")"

active="$(nmcli -t -f NAME connection show --active 2>/dev/null | head -1)"
idx="$(printf '%s' "$menu" | "${ROFI[@]}" -format i \
        -mesg "${active:+connected: $(printf '%s' "$active" | pango_escape)}")"
[[ -z "$idx" ]] && exit 0

# The two trailing rows are actions, not networks.
if ((idx == ${#ssids[@]})); then
    nmcli radio wifi off && notify "Wi-Fi off"
    exit 0
elif ((idx > ${#ssids[@]})); then
    setsid nm-connection-editor >/dev/null 2>&1 &
    exit 0
fi

ssid="${ssids[$idx]}"

# Try without a password first: this succeeds for saved networks and open ones,
# and is the common case. Only on failure do we ask for a secret.
if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
    notify "Connected" "$ssid"
    exit 0
fi

pass="$(printf '' | rofi -dmenu -password -theme "$THEME" \
        -p "password" -mesg "password for $(printf '%s' "$ssid" | pango_escape)")"
[[ -z "$pass" ]] && exit 0

if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
    notify "Connected" "$ssid"
else
    notify -u critical "Could not connect" "$ssid — wrong password?"
fi
