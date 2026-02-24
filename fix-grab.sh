#!/bin/bash

CONFIG_FILE="/opt/retro-mac/qemu-config.json"

echo "=========================================="
echo "QEMU Grab Modifier Troubleshooting"
echo "=========================================="
echo ""
echo "If you can't release mouse/keyboard grab,"
echo "try different grab modifiers."
echo ""

CURRENT_MODE=$(jq -r '.grab_on_click' "$CONFIG_FILE")
CURRENT_POINTER=$(jq -r '.pointer_mode' "$CONFIG_FILE")

echo "Current settings:"
echo "  Pointer mode: $CURRENT_POINTER"
echo "  Grab on click: $CURRENT_MODE"
echo ""

echo "Testing grab modifiers..."
echo ""
echo "Try each option and see which one works:"
echo ""

echo "1. Testing default grab modifier (Ctrl+Alt+G)..."
jq '.grab_on_click = false' "$CONFIG_FILE" > /tmp/qemu-config.json
mv /tmp/qemu-config.json "$CONFIG_FILE"
sed -i 's/-display sdl,grab-mod=rctrl/-display sdl/' /opt/retro-mac/start-mac.sh
echo "   Press Ctrl+Alt+G to release"
echo "   Press Ctrl+Alt+Q to quit QEMU"
echo ""

read -p "Press Enter to test (or 's' to skip)... " choice
if [ "$choice" != "s" ]; then
    /opt/retro-mac/start-mac.sh
fi

echo ""
echo "2. Testing Right Ctrl as grab modifier..."
jq '.grab_on_click = false' "$CONFIG_FILE" > /tmp/qemu-config.json
mv /tmp/qemu-config.json "$CONFIG_FILE"
sed -i 's/-display sdl[^ ]*/-display sdl,grab-mod=rctrl/' /opt/retro-mac/start-mac.sh
echo "   Press Right Ctrl to release"
echo "   Press Ctrl+Alt+Q to quit QEMU"
echo ""

read -p "Press Enter to test (or 's' to skip)... " choice
if [ "$choice" != "s" ]; then
    /opt/retro-mac/start-mac.sh
fi

echo ""
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""
echo "If none of the above worked, try these alternatives:"
echo ""
echo "Option A: Use windowed mode instead of fullscreen"
echo "  Edit config and set 'fullscreen': false"
echo "  In windowed mode, click outside window to release"
echo ""
echo "Option B: Quit QEMU and restart"
echo "  Press Ctrl+Alt+Q to quit"
echo "  Then run: /opt/retro-mac/start-mac.sh"
echo ""
echo "Option C: Use toggle-fullscreen.sh"
echo "  /opt/retro-mac/toggle-fullscreen.sh"
