#!/usr/bin/env bash
# Emits one JSON blob describing the currently active MPRIS player.
# Used by the dashboard music card (polled once a second).

cache="$HOME/.cache/eww/art"
mkdir -p "$cache"

# With Spotify and a browser both on the bus, plain playerctl answers for
# whichever registered first — usually the wrong one. Prefer the one playing.
player=""
while read -r p; do
    [[ -z $p ]] && continue
    [[ -z $player ]] && player=$p
    if [[ $(playerctl -p "$p" status 2>/dev/null) == Playing ]]; then player=$p; break; fi
done < <(playerctl -l 2>/dev/null)

pc() { if [[ -n $player ]]; then playerctl -p "$player" "$@" 2>/dev/null; else playerctl "$@" 2>/dev/null; fi; }
meta() { pc metadata --format "$1"; }

status=$(pc status)
if [[ -z $status ]]; then
    blank=$("$(dirname "$0")/cd.sh" "" 2>/dev/null)
    jq -nc --arg cddir "$blank" '{status:"Stopped",title:"Nothing playing",artist:"",album:"",
             art:"",cddir:$cddir,cdready:"yes",position:0,length:0,progress:0,player:"",elapsed:"0:00",total:"0:00"}'
    exit 0
fi

title=$(meta '{{title}}')
artist=$(meta '{{artist}}')
album=$(meta '{{album}}')
playername=$(meta '{{playerName}}')
arturl=$(meta '{{mpris:artUrl}}')
url=$(meta '{{xesam:url}}')
length=$(meta '{{mpris:length}}')   # microseconds
position=$(pc position)

[[ -z $title ]] && title="Unknown track"
[[ -z $length || $length == "0" ]] && length=0
[[ -z $position ]] && position=0

# Resolve cover art to a local path.
art=""
case "$arturl" in
    file://*) art="${arturl#file://}" ;;
    http*)
        key=$(printf '%s' "$arturl" | md5sum | cut -d' ' -f1)
        art="$cache/$key"
        # Fetched in the background: an 8s curl inside a 1s poll stacks up
        # requests and stalls the whole panel.
        if [[ ! -s $art ]]; then
            ( curl -sfL --max-time 8 -o "$art.part" "$arturl" &&
              mv -f "$art.part" "$art" ) >/dev/null 2>&1 &
            art=""
            pending=1     # its own cover is on the way; do not go looking online
        fi
        ;;
esac
[[ -n $art && ! -s $art ]] && art=""

# Browsers publish a thumbnail barely bigger than a favicon — Chromium's is
# 150x83, which is the whole reason the disc looked like an upscale. When the
# page URL is available we can derive the real artwork from the video id;
# Chromium exposes no URL at all, so fall back to resolving the title. Both
# run detached and are cached per track: the poll never waits on the network.
resolve_art_bg() {
    local marker=$1 out=$2 title=$3 vid=$4
    # One lookup at a time, machine-wide: skipping through tracks used to leave
    # a yt-dlp per skip fighting for the network, and none of them finishing.
    mkdir "$HOME/.cache/eww/.artlock" 2>/dev/null || return 0
    (
        : > "$marker"
        local u=""
        if [[ -n $vid ]]; then
            for q in maxresdefault sddefault hqdefault; do
                if curl -sfL --max-time 6 -o "$out.part" "https://i.ytimg.com/vi/$vid/$q.jpg"; then
                    u=done; break
                fi
            done
        else
            # --flat-playlist skips the player fetch: it returns the video id in
            # about half the time of a full extraction, and the id is all we
            # need to ask for the largest thumbnail directly.
            local id
            id=$(timeout 20 yt-dlp --no-warnings --flat-playlist \
                     --print id "ytsearch1:$title" 2>/dev/null | head -1)
            if [[ -n $id ]]; then
                for q in maxresdefault sddefault hqdefault; do
                    if curl -sfL --max-time 8 -o "$out.part" "https://i.ytimg.com/vi/$id/$q.jpg"; then
                        u=done; break
                    fi
                done
            fi
        fi
        if [[ $u == done && -s "$out.part" ]]; then
            mv -f "$out.part" "$out"
        else
            # Let a later poll try again instead of writing this title off.
            rm -f "$marker"
        fi
        rm -f "$out.part"
        rmdir "$HOME/.cache/eww/.artlock" 2>/dev/null
    ) >/dev/null 2>&1 &
}

if [[ -n $title && $title != "Unknown track" ]]; then
    vid=""
    [[ $url =~ (youtube\.com/watch\?v=|youtu\.be/)([A-Za-z0-9_-]{11}) ]] && vid=${BASH_REMATCH[2]}

    tkey=$(printf '%s' "$title" | md5sum | cut -d' ' -f1)
    big="$cache/hq-$tkey.jpg"
    tried="$cache/hq-$tkey.tried"

    small=1
    (( ${pending:-0} )) && small=0     # wait for the player's own artwork
    if [[ -n $art && -s $art ]]; then
        read -r w h < <(identify -format '%w %h' "$art" 2>/dev/null || echo "0 0")
        (( w >= 500 && h >= 500 )) && small=0
    fi

    if (( small )) && [[ -s $big ]]; then
        art="$big"
    elif (( small )); then
        # A stale marker is a lookup that died with a track change; retry it.
        [[ -f $tried ]] && [[ -n $(find "$tried" -mmin +2 2>/dev/null) ]] && rm -f "$tried"
        [[ ! -f $tried ]] && resolve_art_bg "$tried" "$big" "$title" "$vid"

        # Hold the plain disc rather than pressing the browser's 150px
        # thumbnail: showing that and swapping it for the real artwork a few
        # seconds later looked worse than showing nothing for those seconds.
        # If the lookup has clearly failed, fall back to it rather than sit
        # blank forever.
        if [[ ! -f $tried ]] || [[ -z $(find "$tried" -mmin +0.5 2>/dev/null) ]]; then
            art=""
        fi
    fi
fi

# Pre-rendered CD frames for this artwork (cached; a no-op after the first call)
cddir=$("$(dirname "$0")/cd.sh" "$art" 2>/dev/null)
cdready=no
[[ -f "$cddir/.complete" ]] && cdready=yes
# The spin loop needs to know which set is on screen so it can hold still while
# that set is still being rendered.
printf '%s' "$cddir" > "$HOME/.cache/eww/cd-current"
# The Cairo disc reads the artwork straight from here.
printf '%s' "$art" > "$HOME/.cache/eww/art-current"

secs=${length%.*}
total=$(( secs / 1000000 ))
pos=${position%.*}
(( total > 0 )) && progress=$(( pos * 100 / total )) || progress=0
(( progress > 100 )) && progress=100

fmt() { printf '%d:%02d' $(( $1 / 60 )) $(( $1 % 60 )); }

jq -nc \
    --arg status "$status" --arg title "$title" --arg artist "$artist" \
    --arg cddir "$cddir" --arg cdready "$cdready" \
    --arg album "$album" --arg art "$art" --arg player "$playername" \
    --arg elapsed "$(fmt "$pos")" --arg tot "$(fmt "$total")" \
    --argjson position "$pos" --argjson length "$total" --argjson progress "$progress" \
    '{status:$status,title:$title,artist:$artist,album:$album,art:$art,cddir:$cddir,cdready:$cdready,player:$player,
      position:$position,length:$length,progress:$progress,elapsed:$elapsed,total:$tot}'
