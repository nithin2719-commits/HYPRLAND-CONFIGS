#!/usr/bin/env bash
# Volume control for the bar's sound chip.
#
# pavucontrol threw a full application window on screen for what is a two-click
# job -- and it is a mixer, not a volume control: tabs, device lists, per-app
# streams. This is the same small rofi surface as the wifi and bluetooth menus:
# mute, a few levels, and which output. pavucontrol stays on right-click for the
# times you genuinely need the mixer.

set -uo pipefail

THEME="$HOME/.config/rofi/graphite.rasi"
ROFI=(rofi -dmenu -i -markup-rows -theme "$THEME" -p "volume")
BONE='#e6e6ea'; DIM='#9b9ba4'; FAINT='#6e6e78'

escape() { sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

vol="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -o '[0-9]\+%' | head -1)"
muted="$(pactl get-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')"
sink_desc="$(pactl list sinks 2>/dev/null | awk '/^\tName: /{n=$2} /^\tDescription: /{sub(/^\tDescription: /,""); d=$0} /^\tState: RUNNING/{print d}' | head -1)"
# Fall back to the DEFAULT sink's human description, not its id: `pactl info`
# returns names like "alsa_output.pci-0000_00_1f.3.analog-stereo", which is
# what was being printed in the header.
if [[ -z "$sink_desc" ]]; then
    default_name="$(pactl info 2>/dev/null | awk -F': ' '/Default Sink/{print $2}')"
    sink_desc="$(pactl list sinks 2>/dev/null | awk -v want="$default_name" '
        /^\tName: /{cur=$2}
        /^\tDescription: /{ if (cur==want) { sub(/^\tDescription: /,""); print; exit } }')"
    sink_desc="${sink_desc:-$default_name}"
fi

if [[ "$muted" == "yes" ]]; then
    mute_row="󰕾  unmute"
else
    mute_row="󰝟  mute"
fi

# A short ladder rather than a slider: rofi cannot draw a slider, and scrolling
# the chip already does fine-grained steps of 5%.
menu="$(printf "<span foreground='%s'>%s</span>" "$BONE" "$mute_row")"$'\n'
for lvl in 100 75 50 25; do
    menu+="$(printf "<span foreground='%s'>󰕾  %s%%</span>" "$DIM" "$lvl")"$'\n'
done

# Outputs, so switching to headphones does not need the mixer either.
mapfile -t sinks < <(pactl list short sinks 2>/dev/null | cut -f2)
declare -a sink_names=()
for s in "${sinks[@]}"; do
    [[ -z "$s" ]] && continue
    desc="$(pactl list sinks 2>/dev/null | awk -v want="$s" '
        /^\tName: /{cur=$2}
        /^\tDescription: /{ if (cur==want) { sub(/^\tDescription: /,""); print; exit } }')"
    sink_names+=("$s")
    menu+="$(printf "<span foreground='%s'>󰓃  %s</span>" "$FAINT" "$(printf '%s' "${desc:-$s}" | escape)")"$'\n'
done

menu+="$(printf "<span foreground='%s'>󰢻  open mixer…</span>" "$FAINT")"

# A drawn level reads instantly; "95%" has to be parsed.
num="${vol%\%}"; num="${num:-0}"
filled=$(( (num + 6) / 7 )); ((filled > 14)) && filled=14
bar=""
for ((i = 0; i < 14; i++)); do
    if ((i < filled)); then bar+="▰"; else bar+="▱"; fi
done

idx="$(printf '%s' "$menu" | "${ROFI[@]}" -format i \
        -mesg "$(printf "<span foreground='%s'>%s</span>   <span foreground='%s'>%s  ·  %s</span>" \
                 "$BONE" "$bar" "$FAINT" "${vol:-?}" \
                 "$(printf '%s' "${sink_desc:-output}" | escape)")")"
[[ -z "$idx" ]] && exit 0

n=${#sink_names[@]}
case "$idx" in
    0) pactl set-sink-mute @DEFAULT_SINK@ toggle ;;
    1) pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ 100% ;;
    2) pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ 75% ;;
    3) pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ 50% ;;
    4) pactl set-sink-mute @DEFAULT_SINK@ 0; pactl set-sink-volume @DEFAULT_SINK@ 25% ;;
    *)
        if ((idx >= 5 && idx < 5 + n)); then
            sink="${sink_names[$((idx - 5))]}"
            pactl set-default-sink "$sink"
            # Move what is already playing, otherwise the switch only applies to
            # the next thing you open and looks like it did nothing.
            for input in $(pactl list short sink-inputs 2>/dev/null | cut -f1); do
                pactl move-sink-input "$input" "$sink" 2>/dev/null
            done
        else
            setsid pavucontrol >/dev/null 2>&1 &
        fi
        ;;
esac
