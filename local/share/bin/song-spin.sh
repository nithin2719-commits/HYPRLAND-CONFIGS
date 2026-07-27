# Now-playing module for the graphite bar: a braille spinner and a scrolling title.
# Now-playing module for the graphite bar: a running cat and a scrolling title.
#
# Two animations, both driven from here because GTK3 CSS can neither transform a
# glyph nor scroll text:
#
#   the spinner -- one braille cell rotating while the music plays, still the
#                moment you pause. If it is turning, sound is coming out.
#   the title -- scrolls right-to-left continuously, so a long track name is
#                readable in full without the chip ever changing width.
#
# The script streams one JSON line per frame; the module has no "interval".

set -uo pipefail

# A single braille cell turning. Braille patterns are one character wide, made
# of eight dots, so rotating which dots are lit gives genuinely smooth circular
# motion at bar size -- no character ever "pops" into a different shape the way
# the cat, the half-circle disc and the equaliser bars all did.
#
# It reads as a record turning: fine, quiet, and it does not compete with the
# track name beside it. Braille is present in JetBrainsMono (unlike the kaomoji
# that rendered as blank tofu), and every frame is exactly one column wide, so
# the title never shifts sideways.
# A CD turning. These four characters are the SAME circle with the fill rotated
# a quarter turn each frame, so the disc genuinely spins -- unlike the earlier
# attempts (cat, equaliser, braille), where each frame was a different shape and
# the eye read it as twitching rather than rotation.
# Static. The quarter-circles were meant to read as a spinning CD and did not
# -- at 12px they look like four unrelated symbols. A single steady note beside
# a moving title is the version that survives looking at it all day.
CD=('󰎈')
REST='󰏤'          # paused: the disc stops, a pause mark instead

FRAME=0.28        # one scroll step. Slower is smoother HERE: the step is a
                  # whole character wide, so a fast rate reads as jerking,
                  # while a slow one reads as gliding.
META_EVERY=7     # re-read the track only every ~2s (see below)
WINDOW=22         # visible characters of the title
GAP='   ·   '     # separator between the end of the title and its repeat

pos=0
spin=0
last=""

clean() {
    sed -E 's/\((Official|Lyric|Music|Audio|Video).*\)//Ig
            s/\[(Official|Lyric|Music|Audio|Video).*\]//Ig
            s/ *- *(Official|Topic).*$//Ig
            s/\s+/ /g
            s/^ +| +$//g'
}

escape() { sed -e 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }

emit() {
    local line="{\"text\":\"$1\",\"class\":\"$2\",\"tooltip\":\"$3\"}"
    [[ "$line" == "$last" ]] && return
    last="$line"
    printf '%s\n' "$line"
}

# One step of the marquee. Short titles are left alone -- scrolling something
# that already fits is just fidgeting.
scroll() {
    local text="$1" len
    len=${#text}
    if ((len <= WINDOW)); then
        printf '%s' "$text"
        return
    fi
    local loop="${text}${GAP}"
    local n=${#loop}
    # Double it so a window starting near the end wraps into the beginning
    # instead of running off the string.
    printf '%s' "${loop}${loop}" | cut -c $((pos % n + 1))-$((pos % n + WINDOW))
}

ticks=0
status=""; title=""; artist=""

while true; do
    # Metadata is re-read every ~2 seconds, not every frame. Three playerctl
    # subprocesses per frame was the real cause of the "frame by frame" feel:
    # each one takes tens of milliseconds and the delay varies, so the scroll
    # advanced in uneven lurches no matter what FRAME was set to.
    if ((ticks % META_EVERY == 0)); then
        status="$(playerctl status 2>/dev/null)"
        title="$(playerctl metadata title 2>/dev/null | clean)"
        artist="$(playerctl metadata artist 2>/dev/null | clean)"
        [[ -n "$artist" && "$title" != *"$artist"* ]] && title="$title — $artist"
    fi
    ticks=$((ticks + 1))

    case "$status" in
        Playing | Paused)
            tip="$(printf '%s' "$title" | escape)"

            if [[ "$status" == "Playing" ]]; then
                frame="${CD[$spin]}"
                label="$(scroll "$title" | escape)"
                emit "$frame  $label" "playing" "$tip"
                spin=$(((spin + 1) % ${#CD[@]}))
                
                pos=$((pos + 1))
            else
                # Paused: the spinner rests and the title stops where it is.
                label="$(scroll "$title" | escape)"
                emit "$REST  $label" "paused" "$tip"
            fi
            ;;
        *)
            emit "" "stopped" ""
            pos=0
            ;;
    esac

    sleep "$FRAME"
done
