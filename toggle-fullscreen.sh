#!/bin/bash

CONFIG_FILE="/opt/retro-mac/qemu-config.json"

CURRENT=$(jq -r '.fullscreen' "$CONFIG_FILE")

if [ "$CURRENT" = "true" ]; then
    echo "Switching to windowed mode..."
    jq '.fullscreen = false' "$CONFIG_FILE" > /tmp/qemu-config.json
    mv /tmp/qemu-config.json "$CONFIG_FILE"
    echo "Fullscreen disabled."
    echo "Now you can click outside of QEMU window to release mouse."
else
    echo "Switching to fullscreen mode..."
    jq '.fullscreen = true' "$CONFIG_FILE" > /tmp/qemu-config.json
    mv /tmp/qemu-config.json "$CONFIG_FILE"
    echo "Fullscreen enabled."
fi

echo ""
echo "Restart QEMU to apply changes:"
echo "  /opt/retro-mac/start-mac.sh"
