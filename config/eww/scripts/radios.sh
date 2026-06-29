#!/usr/bin/env bash
# Wi-Fi / Bluetooth state and toggles for the dashboard.
#   radios.sh state        -> {"wifi":true,"wifiname":"…","bt":true,"btname":"…"}
#   radios.sh wifi | bt    -> flip that radio

case "${1:-state}" in
  wifi)
      if [[ $(timeout 3 nmcli -t radio wifi) == enabled ]]; then
          timeout 3 nmcli radio wifi off
      else
          timeout 3 nmcli radio wifi on
      fi
      ;;
  bt)
      if timeout 3 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
          timeout 3 bluetoothctl power off
      else
          rfkill unblock bluetooth 2>/dev/null
          timeout 3 bluetoothctl power on
      fi
      ;;
  state)
      wifi=false; name="off"
      if [[ $(timeout 3 nmcli -t radio wifi 2>/dev/null) == enabled ]]; then
          wifi=true
          # The connected SSID, or "on" when the radio is up but unassociated.
          name=$(timeout 3 nmcli -t -f active,ssid dev wifi 2>/dev/null |
                 awk -F: '$1=="yes"{print $2; exit}')
          [[ -z $name ]] && name="on"
      fi

      bt=false; btname="off"
      if timeout 3 bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
          bt=true
          btname=$(timeout 3 bluetoothctl devices Connected 2>/dev/null |
                   head -1 | cut -d' ' -f3-)
          [[ -z $btname ]] && btname="on"
      fi

      jq -nc --argjson wifi "$wifi" --arg wifiname "$name" \
             --argjson bt "$bt" --arg btname "$btname" \
        '{wifi:$wifi, wifiname:$wifiname, bt:$bt, btname:$btname}'
      ;;
esac
