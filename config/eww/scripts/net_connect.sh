#!/usr/bin/env bash
# Connect from the inline picker, and drive the panel's state as it goes.
#   net_connect.sh wifi <ssid> [password]
#   net_connect.sh bt   <mac> <name>
dir="$(dirname "$0")"

case "${1:-}" in
  wifi)
      ssid=${2:-}; pass=${3:-}
      res=$("$dir/nets.sh" wifi connect "$ssid" "$pass")
      case "$res" in
          needpass)
              # Ask for the key in the panel itself rather than a popup.
              eww update netask="$ssid" netpass="" ;;
          ok)
              eww update netask="" netpass="" netpanel="" ;;
          *)
              eww update netask="" ;;
      esac
      eww update netlist="$("$dir/nets.sh" wifi list)"
      ;;
  bt)
      mac=${2:-}; name=${3:-}
      if [[ $("$dir/nets.sh" bt list | jq -r --arg m "$mac" '.[]|select(.mac==$m)|.connected') == true ]]; then
          "$dir/nets.sh" bt disconnect "$mac"
      else
          "$dir/nets.sh" bt connect "$mac" "$name"
      fi
      eww update netlist="$("$dir/nets.sh" bt list)"
      ;;
esac
