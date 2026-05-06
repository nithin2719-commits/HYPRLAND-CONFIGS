#!/bin/bash
current=$(asusctl profile get | grep "Active profile" | awk '{print $NF}')
case $current in
  Quiet)      asusctl profile set Balanced && notify-send "Profile" "Balanced" ;;
  Balanced)   asusctl profile set Performance && notify-send "Profile" "Performance" ;;
  Performance) asusctl profile set Quiet && notify-send "Profile" "Quiet" ;;
esac
