#!/usr/bin/env bash
# Bluetooth picker for the bar's bluetooth chip.
# Matches wifi-menu.sh exactly: same rofi surface, same shape, same keys.

set -uo pipefail

THEME="$HOME/.config/rofi/graphite.rasi"
ROFI=(rofi -dmenu -i -markup-rows -theme "$THEME" -p "bluetooth")

BONE='#e6e6ea'; DIM='#9b9ba4'; FAINT='#6e6e78'

notify() { notify-send -a "Bluetooth" "$1" "${2:-}" 2>/dev/null; }
pango_escape() { sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

# Read current bluetooth power state
powered="$(bluetoothctl show 2>/dev/null | awk '/Powered:/{print $2}')"

if [[ "$powered" != "yes" ]]; then
    choice="$(printf '󰂯  turn bluetooth on\n󰅖  cancel' | "${ROFI[@]}" -mesg "bluetooth is off")"
    if [[ "$choice" == *"turn bluetooth on"* ]]; then
        rfkill unblock bluetooth 2>/dev/null
        bluetoothctl power on >/dev/null 2>&1
        notify "Bluetooth on"
        sleep 0.5
        exec "$0"  # Immediately show device list without extra clicks!
    fi
    exit 0
fi

# Paired devices first
mapfile -t paired < <(bluetoothctl devices Paired 2>/dev/null | cut -d' ' -f2-)
mapfile -t nearby < <(bluetoothctl devices 2>/dev/null | cut -d' ' -f2-)

declare -a macs=()
menu=""

add_row() {  # $1 = mac, $2 = name, $3 = paired?
    local mac="$1" name="$2" connected icon colour
    connected="$(bluetoothctl info "$mac" 2>/dev/null | awk '/Connected:/{print $2}')"
    if [[ "$connected" == "yes" ]]; then icon="󰂱"; colour="$BONE"
    elif [[ "$3" == "paired" ]];       then icon="󰂲"; colour="$DIM"
    else                                    icon="󰂳"; colour="$FAINT"
    fi
    macs+=("$mac")
    menu+="$(printf "<span foreground='%s'>%s  %s</span>  <span foreground='%s'>%s</span>" \
             "$colour" "$icon" "$(printf '%s' "$name" | pango_escape)" "$FAINT" \
             "$([[ "$connected" == yes ]] && printf 'connected' || printf "$3")")"$'\n'
}

seen=""
for line in "${paired[@]}"; do
    mac="${line%% *}"; name="${line#* }"
    [[ -z "$mac" ]] && continue
    seen+="|$mac|"; add_row "$mac" "$name" "paired"
done
for line in "${nearby[@]}"; do
    mac="${line%% *}"; name="${line#* }"
    [[ -z "$mac" || "$seen" == *"|$mac|"* ]] && continue
    add_row "$mac" "$name" "in range"
done

menu+="$(printf "<span foreground='%s'>󰐇  scan for devices</span>" "$FAINT")"$'\n'
menu+="$(printf "<span foreground='%s'>󰂲  turn bluetooth off</span>" "$FAINT")"$'\n'
menu+="$(printf "<span foreground='%s'>󰢻  open blueman…</span>" "$FAINT")"

idx="$(printf '%s' "$menu" | "${ROFI[@]}" -format i \
        -mesg "$( ((${#macs[@]})) && printf '%d device(s)' "${#macs[@]}" || printf 'no devices yet — scan')")"
[[ -z "$idx" ]] && exit 0

n=${#macs[@]}
case "$idx" in
    "$n")                       # scan
        notify "Scanning…" "10 seconds"
        bluetoothctl --timeout 10 scan on >/dev/null 2>&1
        exec "$0"
        ;;
    "$((n + 1))")               # turn off
        bluetoothctl power off >/dev/null 2>&1
        rfkill block bluetooth 2>/dev/null
        notify "Bluetooth off"
        ;;
    "$((n + 2))")               # blueman
        setsid blueman-manager >/dev/null 2>&1 &
        ;;
    *)
        mac="${macs[$idx]}"
        name="$(bluetoothctl info "$mac" 2>/dev/null | awk -F': ' '/Name:/{print $2; exit}')"
        if [[ "$(bluetoothctl info "$mac" 2>/dev/null | awk '/Connected:/{print $2}')" == "yes" ]]; then
            bluetoothctl disconnect "$mac" >/dev/null 2>&1 && notify "Disconnected" "${name:-$mac}"
        else
            notify "Connecting…" "${name:-$mac}"
            if [[ "$(bluetoothctl info "$mac" 2>/dev/null | awk '/Paired:/{print $2}')" != "yes" ]]; then
                bluetoothctl pair "$mac" >/dev/null 2>&1
                bluetoothctl trust "$mac" >/dev/null 2>&1
            fi
            if bluetoothctl connect "$mac" >/dev/null 2>&1; then
                notify "Connected" "${name:-$mac}"
            else
                notify -u critical "Could not connect" "${name:-$mac}"
            fi
        fi
        ;;
esac
