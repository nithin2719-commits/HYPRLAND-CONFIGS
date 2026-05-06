#!/usr/bin/env bash

case $1 in
  up) pamixer -i 5 ;;
  down) pamixer -d 5 ;;
  mute) pamixer -t ;;
esac

VOL=$(pamixer --get-volume)

eww update volume=$VOL
eww open volume

sleep 1
eww close volume
