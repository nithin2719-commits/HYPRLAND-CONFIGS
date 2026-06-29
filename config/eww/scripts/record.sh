#!/usr/bin/env bash
# Screen recording for the dashboard's action row.
#   record.sh toggle [area]   start/stop; "area" records a selected region
#   record.sh state           -> "on" | "off"
# Clips land in ~/Videos with a timestamped name.

out_dir="$HOME/Videos"
pidfile="$HOME/.cache/eww/wf-recorder.pid"
mkdir -p "$out_dir" "$(dirname "$pidfile")"

running() {
    [[ -s $pidfile ]] && kill -0 "$(cat "$pidfile")" 2>/dev/null
}

case "${1:-state}" in
  state)
      running && echo on || echo off ;;
  toggle)
      if running; then
          # SIGINT, not SIGKILL: wf-recorder needs to finalise the container or
          # the file is left unplayable.
          kill -INT "$(cat "$pidfile")"
          rm -f "$pidfile"
          notify-send -a Recorder "Recording saved" "$(ls -t "$out_dir"/screen-*.mp4 2>/dev/null | head -1)"
          exit 0
      fi

      file="$out_dir/screen-$(date +%Y%m%d-%H%M%S).mp4"
      if [[ ${2:-} == area ]]; then
          geom=$(slurp) || exit 0
          setsid wf-recorder -g "$geom" -f "$file" </dev/null >/dev/null 2>&1 &
      else
          setsid wf-recorder -f "$file" </dev/null >/dev/null 2>&1 &
      fi
      echo $! > "$pidfile"
      sleep 0.4
      notify-send -a Recorder "Recording started" "$(basename "$file")"
      ;;
esac
