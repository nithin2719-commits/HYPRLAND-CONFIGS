#!/bin/bash
profile=$(powerprofilesctl get)
case $profile in
  performance) 
    powerprofilesctl set balanced
    nvidia-smi -pl 80 > /dev/null 2>&1
    notify-send -e -t 1500 -u normal -h string:x-canonical-private-synchronous:powerprofile "⚖️  Balanced Mode" "Optimized for everyday use" ;;
  balanced)    
    powerprofilesctl set power-saver
    nvidia-smi -pl 50 > /dev/null 2>&1
    notify-send -e -t 1500 -u low -h string:x-canonical-private-synchronous:powerprofile "🍃  Eco Mode" "Maximum battery saving" ;;
  power-saver) 
    powerprofilesctl set performance
    nvidia-smi -pl 125 > /dev/null 2>&1
    notify-send -e -t 1500 -u critical -h string:x-canonical-private-synchronous:powerprofile "󱐋  Performance Mode" "Maximum CPU performance" ;;
esac
