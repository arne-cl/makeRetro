#!/bin/bash

# Set QEMU resolution interactively

CONFIG_FILE="/opt/retro-mac/qemu-config.json"

if [ $# -gt 0 ]; then
    if [ "$1" = "auto" ]; then
        echo "Running auto-detection..."
        /opt/retro-mac/auto-resolution.sh
    else
        RES="$1"
        if [[ "$RES" =~ ^[0-9]+x[0-9]+x[0-9]+$ ]]; then
            jq --arg res "$RES" '.resolution = $res' "$CONFIG_FILE" > /tmp/qemu-config.json
            mv /tmp/qemu-config.json "$CONFIG_FILE"
            echo "Resolution set to $RES"
            echo "Restart QEMU to apply changes."
        else
            echo "Invalid resolution format. Use format: WIDTHxHEIGHTxDEPTH"
            echo "Example: 1024x768x32"
        fi
    fi
    exit 0
fi

echo "=========================================="
echo "QEMU Resolution Settings"
echo "=========================================="
echo ""

CURRENT=$(jq -r '.resolution' "$CONFIG_FILE")
echo "Current resolution: $CURRENT"
echo ""

echo "Choose a resolution:"
echo ""
echo "  1) 640x480x8     - VGA (256 colors)"
echo "  2) 800x600x16    - SVGA (Thousands of colors)"
echo "  3) 1024x768x32   - XGA (Millions of colors) [recommended]"
echo "  4) 1280x1024x32  - SXGA (Millions of colors)"
echo "  5) 1600x900x32   - HD (Millions of colors)"
echo "  6) 1920x1080x32  - Full HD (Millions of colors)"
echo "  7) 800x600x32    - SVGA (Millions of colors, better colors)"
echo "  8) 640x480x32    - VGA (Millions of colors, better colors)"
echo "  a) Auto-detect screen resolution"
echo "  c) Custom resolution"
echo "  q) Quit"
echo ""

while true; do
    read -p "Select option [1-8,a,c,q]: " choice
    case "$choice" in
        1)
            RES="640x480x8"
            break
            ;;
        2)
            RES="800x600x16"
            break
            ;;
        3)
            RES="1024x768x32"
            break
            ;;
        4)
            RES="1280x1024x32"
            break
            ;;
        5)
            RES="1600x900x32"
            break
            ;;
        6)
            RES="1920x1080x32"
            break
            ;;
        7)
            RES="800x600x32"
            break
            ;;
        8)
            RES="640x480x32"
            break
            ;;
        [Aa])
            echo ""
            echo "Running auto-detection..."
            /opt/retro-mac/auto-resolution.sh
            exit 0
            ;;
        [Cc])
            echo ""
            read -p "Enter custom resolution (format: WIDTHxHEIGHTxDEPTH, e.g., 1280x720x32): " custom_res
            if [[ "$custom_res" =~ ^[0-9]+x[0-9]+x[0-9]+$ ]]; then
                RES="$custom_res"
                break
            else
                echo "Invalid format. Please use WIDTHxHEIGHTxDEPTH"
            fi
            ;;
        [Qq])
            echo "Cancelled."
            exit 0
            ;;
        *)
            echo "Invalid option. Please select 1-8, a, c, or q."
            ;;
    esac
done

echo ""
echo "Setting resolution to: $RES"
jq --arg res "$RES" '.resolution = $res' "$CONFIG_FILE" > /tmp/qemu-config.json
mv /tmp/qemu-config.json "$CONFIG_FILE"
echo "Resolution updated successfully!"
echo ""
echo "Restart QEMU to apply changes:"
echo "  /opt/retro-mac/start-mac.sh"
