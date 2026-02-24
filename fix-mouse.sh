#!/bin/bash

# Test different pointer configurations to find what works

CONFIG_FILE="/opt/retro-mac/qemu-config.json"

echo "QEMU Mouse Troubleshooting"
echo "========================="
echo ""

# Get current pointer mode
CURRENT_MODE=$(jq -r '.pointer_mode' "$CONFIG_FILE")
echo "Current pointer mode: $CURRENT_MODE"
echo ""

echo "Testing pointer modes..."
echo "Run QEMU with different modes to find what works."
echo ""
echo "Available modes:"
echo ""
echo "1. usb-tablet (recommended)"
echo "   - Absolute positioning - mouse moves seamlessly"
echo "   - No grab needed"
echo "   - Best for windowed mode"
echo ""
echo "2. usb-mouse"
echo "   - Relative positioning - traditional mouse behavior"
echo "   - Press Ctrl+Alt+G to grab/release mouse"
echo "   - Best for fullscreen mode"
echo ""
echo "3. ps2"
echo "   - Legacy PS/2 mouse"
echo "   - Uses Ctrl+Alt+G to grab/release"
echo "   - Most compatible"
echo ""

read -p "Choose mode [1-3] or press Enter to test all: " choice

test_mode() {
    local mode="$1"
    echo ""
    echo "Testing: $mode"
    echo "Setting config..."

    jq --arg mode "$mode" '.pointer_mode = $mode' "$CONFIG_FILE" > /tmp/qemu-config.json
    mv /tmp/qemu-config.json "$CONFIG_FILE"

    echo ""
    echo "Starting QEMU with $mode..."
    echo ""
    echo "INSTRUCTIONS:"
    case "$mode" in
        usb-tablet)
            echo "  • Mouse should move seamlessly without grabbing"
            echo "  • If mouse doesn't work, try USB mouse mode"
            ;;
        usb-mouse|ps2)
            echo "  • Click in the QEMU window to grab mouse"
            echo "  • Press Ctrl+Alt+G to release mouse"
            echo "  • Use Ctrl+Alt+Q to quit"
            ;;
    esac
    echo ""
    echo "Close this terminal or press Ctrl+C to stop testing"
    echo ""

    /opt/retro-mac/start-mac.sh
}

case "$choice" in
    1)
        test_mode "usb-tablet"
        ;;
    2)
        test_mode "usb-mouse"
        ;;
    3)
        test_mode "ps2"
        ;;
    "")
        echo "Testing all modes..."
        test_mode "usb-tablet"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
