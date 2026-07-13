#!/usr/bin/env bash
case "${1:-}" in
    i|-i) exec ~/.local/share/bin/bright-osd.sh up ;;
    d|-d) exec ~/.local/share/bin/bright-osd.sh down ;;
    *)    exec ~/.local/share/bin/bright-osd.sh up ;;
esac
