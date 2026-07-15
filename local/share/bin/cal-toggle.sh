#!/usr/bin/env bash
set -uo pipefail
if pgrep -f 'graphite-calendar[.]py' >/dev/null 2>&1; then
    for p in $(pgrep -f 'graphite-calendar[.]py'); do kill "$p" 2>/dev/null; done
else
    setsid "$HOME/.local/share/bin/graphite-calendar.py" >/dev/null 2>&1 &
fi
