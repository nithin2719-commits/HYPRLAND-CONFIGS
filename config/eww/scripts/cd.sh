#!/usr/bin/env bash
# Turn album art into a CD: a circular disc with a spindle hole, pre-rendered
# at FRAMES rotations so the player can spin it smoothly. Prints the directory
# holding the frames.
#   cd.sh [artwork-path]
#
# Two things keep it from looking chopped up:
#   * the artwork is rotated and the round mask applied AFTER, so the disc
#     outline is a perfect circle in every frame instead of a re-rotated one
#     that jitters at the edge;
#   * frames are rendered from a supersampled source and scaled down, so the rim
#     and the hole are antialiased rather than stair-stepped.
#
# Rendering happens in the background: the music poll runs once a second and
# must never block on ImageMagick. Until a set is ready, the caller gets the
# blank disc.

size=264       # bigger disc = more device pixels for the artwork, which is the
               # only sharpness lever left on a fractionally-scaled screen
super=3         # render scale numerator …
subdiv=2        # … over this: 1.5x is enough supersampling at this size and
                # renders in roughly half the time of 2x
hole=30         # spindle radius
frames=60      # 6° apart — exactly the step the player uses at its 10fps
               # repaint ceiling (60 deg/s). Rendering 120 and stepping two
               # meant half the frames were never displayed at all.

root="$HOME/.cache/eww/cd"
mkdir -p "$root"

art=${1:-}
if [[ -n $art && -s $art ]]; then
    key=$(md5sum "$art" | cut -d' ' -f1)
else
    key="blank"
fi
dir="$root/$key"
blank="$root/blank"

render() {
    local src=$1 out=$2
    local S=$((size * super / subdiv)) R=$((size * super / subdiv / 2)) H=$((hole * super / subdiv))
    # The source is oversized by sqrt(2): a square rotated 45 degrees only
    # covers its inscribed circle if it is that much bigger, otherwise the
    # corners swing away and the disc looks like it stops turning.
    local B=$(( (size * super * 146) / (subdiv * 100) ))
    local tmp; tmp=$(mktemp -d) || return 1

    if [[ -z $src ]]; then
        magick -size ${B}x${B} radial-gradient:'#2b2b31'-'#131316' "$tmp/base.png"
    else
        magick "$src" -resize ${B}x${B}^ -gravity center -extent ${B}x${B} "$tmp/base.png"
    fi

    # A soft sheen baked into the artwork BEFORE rotation. Album art is often
    # dark and near-symmetric, so the disc could be turning and still look
    # frozen; this gives the eye something that unmistakably travels around.
    magick "$tmp/base.png" \
        \( -size $((B * 3 / 2))x$((B * 3 / 2)) gradient:'#ffffff-#00000000' -rotate 25 \
           -gravity center -extent ${B}x${B} \
           -alpha set -channel A -evaluate multiply 0.13 +channel \) \
        -compose Over -composite \
        "$tmp/base2.png" && mv "$tmp/base2.png" "$tmp/base.png"

    # Masks are built once and reused for every frame.
    magick -size ${S}x${S} xc:none -fill white -draw "circle $R,$R $R,0" "$tmp/disc.png"
    magick -size ${S}x${S} xc:none -fill white -draw "circle $R,$R $R,$((R - H))" "$tmp/hole.png"

    local stage="$tmp/frames"
    mkdir -p "$stage"

    # Render frame 0 on its own first and stand the whole set up from copies of
    # it. The disc is then on screen within a moment of the artwork arriving —
    # still, but correct — and each copy is replaced by its real rotation as the
    # parallel pass below finishes. Waiting for the whole set first meant
    # several seconds of blank disc after every track change.
    magick "$tmp/base.png" -background none -virtual-pixel none \
            -gravity center -extent ${S}x${S} \
        "$tmp/disc.png" -alpha set -compose CopyOpacity -composite \
        "$tmp/hole.png" -compose DstOut -composite \
        \( -size ${S}x${S} xc:none -stroke '#ffffff30' -strokewidth $((2 * super / subdiv)) \
           -fill none -draw "circle $R,$R $R,$((R - H - 22 * super / subdiv))" \) \
            -compose Over -composite \
        -filter Lanczos -resize ${size}x${size} -unsharp 0x0.7+0.7+0.02 \
        -depth 8 -strip -define png:compression-level=3 \
        "$stage/f0.png"

    local n
    for ((n = 1; n < frames; n++)); do cp -f "$stage/f0.png" "$stage/f$n.png"; done
    rm -rf "$out"
    cp -a "$stage" "$out"

    # Frames are independent, so render them across every core instead of one
    # at a time: rendering the set sequentially took long enough that the disc
    # sat blank for ten seconds after a track change.
    local jobs; jobs=$(nproc 2>/dev/null || echo 4)
    seq 0 $((frames - 1)) | xargs -P "$jobs" -I{} sh -c '
        i=$1
        angle=$(echo "scale=3; $i * 360 / '"$frames"'" | bc)
        magick "'"$tmp"'/base.png" -background none -virtual-pixel none \
                -filter Lanczos -distort SRT "$angle" \
                -gravity center -extent '"${S}x${S}"' \
            "'"$tmp"'/disc.png" -alpha set -compose CopyOpacity -composite \
            "'"$tmp"'/hole.png" -compose DstOut -composite \
            \( -size '"${S}x${S}"' xc:none -stroke "#ffffff30" -strokewidth '"$((2 * super / subdiv))"' \
               -fill none -draw "circle '"$R,$R $R,$((R - H - 22 * super / subdiv))"'" \) \
                -compose Over -composite \
            -filter Lanczos -resize '"${size}x${size}"' -unsharp 0x0.7+0.7+0.02 \
            -depth 8 -strip -define png:compression-level=3 \
            "'"$stage"'/f$i.png" &&
        mv -f "'"$stage"'/f$i.png" "'"$out"'/f$i.png"
    ' _ {}

    # Only now is every frame a real rotation rather than a copy of frame 0.
    # Until this marker exists the player holds the disc still: spinning through
    # a half-replaced set makes it lurch, which reads as a stutter.
    : > "$out/.complete"

    rm -rf "$tmp"
}

ready() { [[ -f "$1/.complete" ]]; }

# The blank disc is the fallback for everything, so make sure it exists first —
# under a lock, because several polls can reach this line at the same moment.
if ! ready "$blank"; then
    if mkdir "$root/.blank.lock" 2>/dev/null; then
        render "" "$blank"
        rmdir "$root/.blank.lock"
    else
        # Someone else is building it; wait briefly rather than racing them.
        for _ in $(seq 1 40); do ready "$blank" && break; sleep 0.25; done
    fi
fi

# Prune on every call, not only on a miss: a cache hit is the common case, and
# the sets are big enough that only pruning on misses let it reach ~100MB.
( ls -1dt "$root"/*/ 2>/dev/null | grep -v "/blank/$" | tail -n +5 |
  while read -r old; do rm -rf "$old"; done ) >/dev/null 2>&1 &

if ready "$dir"; then
    echo "$dir"
    exit 0
fi

# Kick off this artwork's frames once, in the background, and fall back to blank.
lock="$root/.$key.lock"
if mkdir "$lock" 2>/dev/null; then
    ( render "$art" "$dir"; rmdir "$lock" ) >/dev/null 2>&1 &
fi
echo "$blank"
