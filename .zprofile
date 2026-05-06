export PATH="$PATH:/home/nithin/.local/bin"
if [ -z "$WAYLAND_DISPLAY" ] && [ "$XDG_VTNR" -eq 1 ]; then
    clear
    tput civis
    exec start-hyprland --no-nixgl > /dev/null 2>&1
fi
