#!/bin/bash

# Minimal Mac OS 9 Emulation Setup Script
# No web interface, no auto-start, just QEMU basics

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

main() {
    echo "=========================================="
    echo "Minimal Mac OS 9 Emulation Setup"
    echo "=========================================="
    echo ""

    check_root

    print_status "Updating package lists..."
    apt-get update -qq
    print_success "Package lists updated"

    print_status "Installing required packages..."

    if is_package_installed qemu-system-ppc; then
        print_status "QEMU PPC already installed"
    else
        print_status "Installing QEMU..."
        apt-get install -y qemu-system-ppc qemu-utils
        print_success "QEMU installed"
    fi

    if is_package_installed xorg; then
        print_status "X11 already installed"
    else
        print_status "Installing X11..."
        apt-get install -y xorg
        print_success "X11 installed"
    fi

    print_status "Installing utilities (jq, wget, curl, imagemagick)..."
    apt-get install -y jq wget curl imagemagick
    print_success "Utilities installed"

    mkdir -p /opt/retro-mac
    mkdir -p /opt/retro-mac/images
    mkdir -p /opt/retro-mac/drives
    print_success "Directories created"

    print_status "Downloading Mac OS 9 ISO..."
    if [ -f "/opt/retro-mac/macos_921_ppc.iso" ]; then
        print_status "ISO already exists"
    else
        if wget -q --show-progress -O /opt/retro-mac/macos_921_ppc.iso "http://www.mcchord.net/static/macos_921_ppc.iso"; then
            print_success "ISO downloaded successfully"
        else
            print_error "Failed to download ISO"
            rm -f /opt/retro-mac/macos_921_ppc.iso
            return 1
        fi
    fi

    print_status "Creating default configuration..."
    cat > /opt/retro-mac/qemu-config.json << 'EOF'
{
    "ram": "512",
    "cpu": "g4",
    "machine": "mac99,via=pmu",
    "resolution": "1024x768x32",
    "fullscreen": true,
    "boot_device": "d",
    "cdrom": "/opt/retro-mac/macos_921_ppc.iso",
    "hard_drives": [],
    "custom_args": "",
    "network": "user",
    "sound": true,
    "pointer_mode": "usb-tablet",
    "grab_on_click": true
}
EOF
    chmod 644 /opt/retro-mac/qemu-config.json
    print_success "Configuration created"

    print_status "Creating startup script..."
    cat > /opt/retro-mac/start-mac.sh << 'EOF'
#!/bin/bash
CONFIG_FILE="/opt/retro-mac/qemu-config.json"

if [ -f "$CONFIG_FILE" ]; then
    RAM=$(jq -r '.ram' "$CONFIG_FILE")
    CPU=$(jq -r '.cpu' "$CONFIG_FILE")
    MACHINE=$(jq -r '.machine' "$CONFIG_FILE")
    RESOLUTION=$(jq -r '.resolution' "$CONFIG_FILE")
    FULLSCREEN=$(jq -r '.fullscreen' "$CONFIG_FILE")
    BOOT=$(jq -r '.boot_device' "$CONFIG_FILE")
    CDROM=$(jq -r '.cdrom' "$CONFIG_FILE")
    CUSTOM_ARGS=$(jq -r '.custom_args // ""' "$CONFIG_FILE")
    NETWORK=$(jq -r '.network // "user"' "$CONFIG_FILE")
    SOUND=$(jq -r '.sound // true' "$CONFIG_FILE")
    POINTER_MODE=$(jq -r '.pointer_mode // "usb-tablet"' "$CONFIG_FILE")
    GRAB_ON_CLICK=$(jq -r '.grab_on_click // true' "$CONFIG_FILE")
else
    RAM="512"; CPU="g4"; MACHINE="mac99,via=pmu"
    RESOLUTION="1024x768x32"; FULLSCREEN="true"; BOOT="d"
    CDROM="/opt/retro-mac/macos_921_ppc.iso"
    CUSTOM_ARGS=""; NETWORK="user"; SOUND="true"
    POINTER_MODE="usb-tablet"; GRAB_ON_CLICK="true"
fi

CMD="qemu-system-ppc -M $MACHINE -m $RAM -cpu $CPU -g $RESOLUTION -boot $BOOT"

if [ "$POINTER_MODE" = "usb-tablet" ]; then
    CMD="$CMD -device usb-tablet -device usb-kbd"
elif [ "$POINTER_MODE" = "usb-mouse" ]; then
    CMD="$CMD -device usb-mouse -device usb-kbd"
else
    CMD="$CMD -device usb-kbd"
fi

if [ -n "$CDROM" ] && [ "$CDROM" != "null" ] && [ -f "$CDROM" ]; then
    CMD="$CMD -drive file=$CDROM,format=raw,media=cdrom"
fi

if [ -f "$CONFIG_FILE" ]; then
    DRIVES=$(jq -r '.hard_drives[]? | @base64' "$CONFIG_FILE")
    for drive in $DRIVES; do
        DRIVE_PATH=$(echo "$drive" | base64 -d | jq -r '.path')
        DRIVE_FORMAT=$(echo "$drive" | base64 -d | jq -r '.format // "qcow2"')
        if [ -f "$DRIVE_PATH" ]; then
            CMD="$CMD -drive file=$DRIVE_PATH,format=$DRIVE_FORMAT"
        fi
    done
fi

if [ "$NETWORK" = "none" ]; then
    CMD="$CMD -netdev none,id=none"
else
    CMD="$CMD -netdev $NETWORK,id=net0 -device rtl8139,netdev=net0"
fi

if [ "$SOUND" = "true" ]; then
    CMD="$CMD -device ES1370"
fi

if [ "$FULLSCREEN" = "true" ]; then
    CMD="$CMD -full-screen"
fi

if [ "$GRAB_ON_CLICK" = "false" ]; then
    CMD="$CMD -display sdl,grab-mod=rctrl"
fi

if [ -n "$CUSTOM_ARGS" ]; then
    CMD="$CMD $CUSTOM_ARGS"
fi

echo "Starting QEMU: $CMD"
exec $CMD
EOF
    chmod +x /opt/retro-mac/start-mac.sh
    print_success "Startup script created"

    print_status "Creating basic helper scripts..."

    cat > /opt/retro-mac/set-ram.sh << 'EOF'
#!/bin/bash
if [ $# -eq 0 ]; then
    cat /opt/retro-mac/qemu-config.json | jq -r '.ram'
else
    jq --arg ram "$1" '.ram = $ram' /opt/retro-mac/qemu-config.json > /tmp/qemu-config.json && mv /tmp/qemu-config.json /opt/retro-mac/qemu-config.json
    echo "RAM set to $1 MB"
fi
EOF
    chmod +x /opt/retro-mac/set-ram.sh

    cat > /opt/retro-mac/create-drive.sh << 'EOF'
#!/bin/bash
if [ $# -lt 2 ]; then
    echo "Usage: $0 <name> <size> [format]"
    echo "Example: $0 mydisk 2G qcow2"
    exit 1
fi

NAME="$1"
SIZE="$2"
FORMAT="${3:-qcow2}"
DRIVE_PATH="/opt/retro-mac/drives/$NAME.$FORMAT"

if [ -f "$DRIVE_PATH" ]; then
    echo "Error: Drive already exists"
    exit 1
fi

mkdir -p /opt/retro-mac/drives
qemu-img create -f "$FORMAT" "$DRIVE_PATH" "$SIZE"
echo "Adding to config..."
jq --arg path "$DRIVE_PATH" --arg format "$FORMAT" '.hard_drives += [{"path": $path, "format": $format}]' /opt/retro-mac/qemu-config.json > /tmp/qemu-config.json && mv /tmp/qemu-config.json /opt/retro-mac/qemu-config.json
echo "Drive created: $DRIVE_PATH"
EOF
    chmod +x /opt/retro-mac/create-drive.sh

    cat > /opt/retro-mac/list-drives.sh << 'EOF'
#!/bin/bash
jq -r '.hard_drives[]? | "\(.path) (\(.format))"' /opt/retro-mac/qemu-config.json 2>/dev/null || echo "No drives configured"
EOF
    chmod +x /opt/retro-mac/list-drives.sh

    print_success "Basic helper scripts created"

    print_status "Copying additional helper scripts..."

    if [ -f "set-resolution.sh" ]; then
        cp set-resolution.sh /opt/retro-mac/
        chmod +x /opt/retro-mac/set-resolution.sh
        print_success "Copied set-resolution.sh"
    else
        print_warning "set-resolution.sh not found in current directory"
    fi

    if [ -f "auto-resolution.sh" ]; then
        cp auto-resolution.sh /opt/retro-mac/
        chmod +x /opt/retro-mac/auto-resolution.sh
        print_success "Copied auto-resolution.sh"
    else
        print_warning "auto-resolution.sh not found in current directory"
    fi

    if [ -f "fix-mouse.sh" ]; then
        cp fix-mouse.sh /opt/retro-mac/
        chmod +x /opt/retro-mac/fix-mouse.sh
        print_success "Copied fix-mouse.sh"
    else
        print_warning "fix-mouse.sh not found in current directory"
    fi

    if [ -f "fix-grab.sh" ]; then
        cp fix-grab.sh /opt/retro-mac/
        chmod +x /opt/retro-mac/fix-grab.sh
        print_success "Copied fix-grab.sh"
    else
        print_warning "fix-grab.sh not found in current directory"
    fi

    if [ -f "toggle-fullscreen.sh" ]; then
        cp toggle-fullscreen.sh /opt/retro-mac/
        chmod +x /opt/retro-mac/toggle-fullscreen.sh
        print_success "Copied toggle-fullscreen.sh"
    else
        print_warning "toggle-fullscreen.sh not found in current directory"
    fi

    print_success "All helper scripts installed"

    chown -R $SUDO_USER:$SUDO_USER /opt/retro-mac 2>/dev/null || true

    echo ""
    echo "=========================================="
    echo "Setup Complete!"
    echo "=========================================="
    echo ""
    echo "To start the emulator:"
    echo "  /opt/retro-mac/start-mac.sh"
    echo ""
    echo "Configuration file:"
    echo "  /opt/retro-mac/qemu-config.json"
    echo ""
    echo "Helper scripts:"
    echo "  /opt/retro-mac/set-ram.sh <MB>       - Set RAM size"
    echo "  /opt/retro-mac/set-resolution.sh         - Set resolution (interactive menu)"
    echo "  /opt/retro-mac/auto-resolution.sh         - Auto-detect resolution"
    echo "  /opt/retro-mac/create-drive.sh <name> <size> [format] - Create virtual drive"
    echo "  /opt/retro-mac/list-drives.sh        - List configured drives"
    echo "  /opt/retro-mac/fix-mouse.sh         - Interactive mouse troubleshooting"
    echo "  /opt/retro-mac/fix-grab.sh          - Test grab modifiers"
    echo "  /opt/retro-mac/toggle-fullscreen.sh   - Toggle fullscreen/windowed mode"
    echo ""
    echo "Edit config directly for other options:"
    echo "  nano /opt/retro-mac/qemu-config.json"
}

main "$@"
