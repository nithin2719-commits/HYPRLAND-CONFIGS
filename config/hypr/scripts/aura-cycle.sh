#!/bin/bash
statefile="/tmp/aura_effect_index"

effects=(
    "asusctl aura effect static --colour ff0000"
    "asusctl aura effect breathe --colour ff0000 --colour2 0000ff --speed med"
    "asusctl aura effect rainbow-cycle --speed med"
    "asusctl aura effect rainbow-wave --speed med"
    "asusctl aura effect stars --colour ff0000 --colour2 ffffff --speed med"
    "asusctl aura effect rain --colour ff0000 --speed med"
    "asusctl aura effect highlight --colour ff0000 --speed med"
    "asusctl aura effect laser --colour ff0000 --speed med"
    "asusctl aura effect ripple --colour ff0000 --speed med"
    "asusctl aura effect pulse --colour ff0000 --speed med"
    "asusctl aura effect comet --colour ff0000 --speed med"
    "asusctl aura effect flash --colour ff0000 --speed med"
)

[ ! -f "$statefile" ] && echo 0 > "$statefile"
current=$(cat "$statefile")
eval "${effects[$current]}"
echo $(( (current + 1) % ${#effects[@]} )) > "$statefile"
