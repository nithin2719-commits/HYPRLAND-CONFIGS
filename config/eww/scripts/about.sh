#!/usr/bin/env bash
# Machine identity for the dashboard's logo card.
. /etc/os-release 2>/dev/null

jq -nc \
  --arg distro "${NAME:-Linux}" \
  --arg host   "$(hostnamectl hostname 2>/dev/null || hostname)" \
  --arg kernel "$(uname -r)" \
  --arg pkgs   "$(pacman -Qq 2>/dev/null | wc -l)" \
  --arg wm     "${XDG_CURRENT_DESKTOP:-Hyprland}" \
  '{distro:$distro, host:$host, kernel:$kernel, pkgs:$pkgs, wm:$wm}'
