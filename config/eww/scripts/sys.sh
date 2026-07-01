#!/usr/bin/env bash
# Compact system stats for the dashboard's bottom-left tile.
read -r _ u n s idle rest < /proc/stat
busy1=$((u + n + s)); tot1=$((busy1 + idle))
sleep 0.3
read -r _ u n s idle rest < /proc/stat
busy2=$((u + n + s)); tot2=$((busy2 + idle))
d=$((tot2 - tot1)); (( d > 0 )) && cpu=$(( (busy2 - busy1) * 100 / d )) || cpu=0

mem=$(free -m | awk '/^Mem:/ {printf "%d %d", $3, $2}')
used=${mem% *}; total=${mem#* }
mempct=$(( used * 100 / total ))
disk=$(df -h --output=pcent / | tail -1 | tr -dc '0-9')
up=$(uptime -p | sed 's/^up //; s/ hours\?/h/; s/ minutes\?/m/; s/ days\?/d/; s/,//g')

jq -nc --argjson cpu "$cpu" --argjson mem "$mempct" --argjson disk "$disk" \
       --arg up "$up" --argjson used "$used" --argjson total "$total" \
  '{cpu:$cpu, mem:$mem, disk:$disk, up:$up,
    memtext:"\($used/1024 | floor)/\($total/1024 | floor) GB"}'
