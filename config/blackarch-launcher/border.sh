#!/bin/bash
# Kill any existing border overlay
pkill -f "blackarch-border" 2>/dev/null

# Launch rofi centered with our theme
bash ~/.config/blackarch-launcher/launch.sh
