#!/bin/bash
profile=$(powerprofilesctl get)

case $profile in
  performance) options="⚖️ Balanced\n🍃 Eco" ;;
  balanced)    options="⚡ Performance\n🍃 Eco" ;;
  power-saver) options="⚡ Performance\n⚖️ Balanced" ;;
esac

chosen=$(echo -e "$options" | wofi --dmenu --prompt "Power Profile")

case $chosen in
  *Performance*) powerprofilesctl set performance ;;
  *Balanced*)    powerprofilesctl set balanced ;;
  *Eco*)         powerprofilesctl set power-saver ;;
esac
