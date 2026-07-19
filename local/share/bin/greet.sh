#!/usr/bin/env bash
# Two-line shell greeting, monochrome.
#
# The fastfetch card this replaces was still a block of eight labelled rows and
# an ASCII logo -- information you do not read twice a day, printed every time
# you open a terminal. This is a rule, a name, and the three numbers that ever
# change. It ends where the prompt begins, so the terminal opens looking calm.

set -uo pipefail

W=$(( ${COLUMNS:-80} > 64 ? 64 : ${COLUMNS:-80} ))

D='\033[38;5;245m'   # dim  -- labels and rule
B='\033[38;5;255m'   # bone -- the values worth reading
R='\033[0m'

up="$(uptime -p 2>/dev/null | sed 's/^up //; s/ hours\?/h/; s/ minutes\?/m/; s/,//')"
mem="$(free -g 2>/dev/null | awk '/^Mem:/{print $3"/"$2"G"}')"
bat="$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null)"

# printf-repeat, NOT `printf %*s | tr ' ' '─'`: tr substitutes single BYTES, so
# a multi-byte ─ comes out as three garbage characters per column.
rule="$(printf '─%.0s' $(seq 1 "$W"))"
printf "${D}%s${R}\n" "$rule"
printf "  ${B}%s${R}${D}@%s${R}   ${D}up${R} %s   ${D}mem${R} %s${D}%s${R}\n\n" \
    "${USER:-user}" "${HOST:-$(hostnamectl --static 2>/dev/null || echo arch)}" \
    "${up:-?}" "${mem:-?}" "${bat:+   bat ${bat}%}"
