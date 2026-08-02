#!/usr/bin/env bash
case "${2:-}" in
    i) exec ~/.local/share/bin/vol-osd.sh up ;;
    d) exec ~/.local/share/bin/vol-osd.sh down ;;
    m) exec ~/.local/share/bin/vol-osd.sh mute ;;
    *) exec ~/.local/share/bin/vol-osd.sh up ;;
esac
