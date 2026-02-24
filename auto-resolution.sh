#!/bin/bash

# Auto-detect screen resolution and set it in QEMU config

CONFIG_FILE="/opt/retro-mac/qemu-config.json"

# Check if X is running
if [ -z "$DISPLAY" ]; then
    echo "Error: DISPLAY not set. Make sure you're running X11."
    exit 1
fi

# Detect resolution using xrandr
if command -v xrandr >/dev/null 2>&1; then
    RES=$(xrandr --query | grep ' connected' | grep -oP '\d+x\d+' | head -1)
    if [ -n "$RES" ]; then
        echo "Detected screen resolution: ${RES}"

        # Convert to QEMU format (add color depth)
        WIDTH=$(echo "$RES" | cut -d'x' -f1)
        HEIGHT=$(echo "$RES" | cut -d'x' -f2)

        # Choose reasonable QEMU resolutions based on detected size
        if [ "$WIDTH" -ge 1920 ]; then
            QEMU_RES="1920x1080x32"
        elif [ "$WIDTH" -ge 1600 ]; then
            QEMU_RES="1600x900x32"
        elif [ "$WIDTH" -ge 1280 ]; then
            QEMU_RES="1280x1024x32"
        elif [ "$WIDTH" -ge 1024 ]; then
            QEMU_RES="1024x768x32"
        elif [ "$WIDTH" -ge 800 ]; then
            QEMU_RES="800x600x32"
        else
            QEMU_RES="640x480x32"
        fi

        echo "Setting QEMU resolution to: $QEMU_RES"

        # Update config
        jq --arg res "$QEMU_RES" '.resolution = $res' "$CONFIG_FILE" > /tmp/qemu-config.json
        mv /tmp/qemu-config.json "$CONFIG_FILE"

        echo "Resolution updated. Restart QEMU to apply."
        echo ""
        echo "Current resolution options:"
        echo "  640x480x32    - VGA"
        echo "  800x600x32    - SVGA"
        echo "  1024x768x32   - XGA"
        echo "  1280x1024x32  - SXGA"
        echo "  1600x900x32   - HD"
        echo "  1920x1080x32  - Full HD"
    else
        echo "Could not detect resolution with xrandr."
        echo "Set resolution manually:"
        echo "  jq --arg res \"1024x768x32\" '.resolution = \$res' /opt/retro-mac/qemu-config.json > /tmp/qemu-config.json && mv /tmp/qemu-config.json /opt/retro-mac/qemu-config.json"
    fi
else
    echo "xrandr not found. Install it with:"
    echo "  sudo apt-get install x11-utils"
fi
