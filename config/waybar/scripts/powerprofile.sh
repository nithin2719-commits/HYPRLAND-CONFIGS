#!/bin/bash
profile=$(powerprofilesctl get)
case $1 in
  performance) [ "$profile" = "performance" ] && echo "[⚡Perf]" || echo "⚡Perf" ;;
  balanced)    [ "$profile" = "balanced" ]    && echo "[⚖️Bal]"  || echo "⚖️Bal"  ;;
  power-saver) [ "$profile" = "power-saver" ] && echo "[🍃Eco]"  || echo "🍃Eco"  ;;
esac
