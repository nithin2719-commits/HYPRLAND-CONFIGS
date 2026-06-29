#!/usr/bin/env bash
# Network / Bluetooth listings and connect actions for the dashboard's inline
# picker. Everything is JSON so the panel can render rows itself — no rofi.
#
#   nets.sh wifi list                  -> [{ssid,signal,secure,active,known}]
#   nets.sh wifi connect <ssid> [pass]
#   nets.sh wifi disconnect
#   nets.sh bt list                    -> [{mac,name,connected,paired}]
#   nets.sh bt connect <mac> | bt disconnect <mac>
#   nets.sh bt scan                    -> discover for 8s in the background

set -u

wifi_list() {
    # IN-USE marks the current network; a saved profile means one click connects.
    local known
    known=$(timeout 3 nmcli -t -f NAME connection show 2>/dev/null)
    timeout 3 nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null |
    awk -F: -v known="$known" '
        BEGIN { split(known, k, "\n"); print "[" }
        $2 == "" { next }
        {
            if (seen[$2]++) next
            isknown = "false"
            for (i in k) if (k[i] == $2) isknown = "true"
            gsub(/"/, "", $2)
            printf "%s{\"ssid\":\"%s\",\"signal\":%d,\"secure\":%s,\"active\":%s,\"known\":%s}",
                   (n++ ? "," : ""), $2, $3,
                   ($4 == "" ? "false" : "true"),
                   ($1 == "*" ? "true" : "false"), isknown
        }
        END { print "]" }'
}

bt_list() {
    local connected paired
    connected=$(timeout 3 bluetoothctl devices Connected 2>/dev/null | awk '{print $2}')
    paired=$(timeout 3 bluetoothctl devices Paired 2>/dev/null)
    printf '%s\n' "$paired" | awk -F' ' -v conn="$connected" '
        BEGIN { split(conn, c, "\n"); print "[" }
        NF < 3 { next }
        {
            mac = $2
            name = ""
            for (i = 3; i <= NF; i++) name = name (i > 3 ? " " : "") $i
            gsub(/"/, "", name)
            isconn = "false"
            for (i in c) if (c[i] == mac) isconn = "true"
            printf "%s{\"mac\":\"%s\",\"name\":\"%s\",\"connected\":%s}",
                   (n++ ? "," : ""), mac, name, isconn
        }
        END { print "]" }'
}

case "${1:-}" in
  wifi)
    case "${2:-list}" in
      list) wifi_list ;;
      connect)
          ssid=${3:-}; pass=${4:-}
          [[ -z $ssid ]] && exit 1
          if [[ -n $pass ]]; then
              out=$(timeout 3 nmcli device wifi connect "$ssid" password "$pass" 2>&1)
          else
              out=$(timeout 3 nmcli device wifi connect "$ssid" 2>&1)
          fi
          if [[ $out == *"Error"* || $out == *"error"* ]]; then
              # A missing secret is the one failure the panel can act on, so it
              # is reported as its own state rather than a generic error.
              if [[ $out == *"Secrets were required"* || $out == *"secrets"* ]]; then
                  echo needpass
              else
                  notify-send -a Network "Wi-Fi" "$out"
                  echo failed
              fi
          else
              notify-send -a Network "Connected" "$ssid"
              echo ok
          fi
          ;;
      disconnect)
          dev=$(timeout 3 nmcli -t -f DEVICE,TYPE device | awk -F: '$2=="wifi"{print $1; exit}')
          timeout 3 nmcli device disconnect "$dev" >/dev/null 2>&1
          ;;
      rescan) timeout 3 nmcli device wifi rescan >/dev/null 2>&1 & ;;
    esac
    ;;
  bt)
    case "${2:-list}" in
      list) bt_list ;;
      scan) (timeout 10 bluetoothctl --timeout 8 scan on >/dev/null 2>&1 &) ;;
      connect)
          if timeout 3 bluetoothctl connect "${3:-}" >/dev/null 2>&1; then
              notify-send -a Bluetooth "Connected" "${4:-${3:-}}"
          else
              notify-send -a Bluetooth "Could not connect" "${4:-${3:-}}"
          fi
          ;;
      disconnect) timeout 3 bluetoothctl disconnect "${3:-}" >/dev/null 2>&1 ;;
    esac
    ;;
esac
