#!/bin/bash

# Mac OS 9 Emulation Setup Script
# This script is idempotent - safe to run multiple times
# Author: Retro Mac Setup
# Date: $(date +%Y-%m-%d)

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored status messages
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Function to check if a package is installed
is_package_installed() {
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"
}

# Function to check if a service is running
is_service_running() {
    systemctl is-active --quiet "$1"
}

# Function to download file if not exists
download_if_needed() {
    local url="$1"
    local dest="$2"
    local desc="$3"
    
    if [ -f "$dest" ]; then
        print_status "$desc already exists, skipping download"
    else
        print_status "Downloading $desc..."
        if wget -q --show-progress -O "$dest" "$url"; then
            print_success "$desc downloaded successfully"
        else
            print_error "Failed to download $desc"
            rm -f "$dest"
            return 1
        fi
    fi
}

# Function to fix existing installation
fix_existing_installation() {
    print_status "Checking for existing installation issues..."
    
    # Fix LightDM if it's using root
    if [ -f "/etc/lightdm/lightdm.conf" ]; then
        if grep -q "autologin-user=root" /etc/lightdm/lightdm.conf; then
            print_warning "Found LightDM configured for root auto-login (this doesn't work)"
            
            # Find appropriate user
            if id retro >/dev/null 2>&1; then
                FIX_USER="retro"
            else
                FIX_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | head -1)
            fi
            
            if [ -n "$FIX_USER" ]; then
                print_status "Fixing auto-login to use $FIX_USER..."
                sed -i "s/autologin-user=root/autologin-user=$FIX_USER/g" /etc/lightdm/lightdm.conf
                
                # Fix openbox autostart
                USER_HOME=$(getent passwd "$FIX_USER" | cut -d: -f6)
                mkdir -p "$USER_HOME/.config/openbox"
                cat > "$USER_HOME/.config/openbox/autostart" << 'EOF'
#!/bin/bash
# Start QEMU Mac emulator after X11 starts
sleep 5
export DISPLAY=:0
sudo systemctl start qemu-mac.service &
EOF
                chmod +x "$USER_HOME/.config/openbox/autostart"
                chown -R "$FIX_USER:$FIX_USER" "$USER_HOME/.config"
                
                # Fix QEMU service
                if [ -f "/etc/systemd/system/qemu-mac.service" ]; then
                    sed -i "s|^User=.*|User=$FIX_USER|" /etc/systemd/system/qemu-mac.service
                    sed -i "s|^Group=.*|Group=$FIX_USER|" /etc/systemd/system/qemu-mac.service
                    sed -i "s|Environment=\"HOME=.*\"|Environment=\"HOME=$USER_HOME\"|" /etc/systemd/system/qemu-mac.service
                    sed -i "s|Environment=\"XAUTHORITY=.*\"|Environment=\"XAUTHORITY=$USER_HOME/.Xauthority\"|" /etc/systemd/system/qemu-mac.service
                fi
                
                # Add sudo permissions
                if ! grep -q "$FIX_USER.*systemctl.*qemu-mac" /etc/sudoers; then
                    echo "" >> /etc/sudoers
                    echo "# Allow $FIX_USER to control QEMU service" >> /etc/sudoers
                    echo "$FIX_USER ALL=(ALL) NOPASSWD: /bin/systemctl start qemu-mac.service" >> /etc/sudoers
                    echo "$FIX_USER ALL=(ALL) NOPASSWD: /bin/systemctl stop qemu-mac.service" >> /etc/sudoers
                    echo "$FIX_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart qemu-mac.service" >> /etc/sudoers
                fi
                
                # Fix ownership
                chown -R "$FIX_USER:$FIX_USER" /opt/retro-mac/ 2>/dev/null || true
                
                # Create/fix log files with proper permissions
                touch /var/log/qemu-mac.log /var/log/qemu-mac-cmd.log
                chown "$FIX_USER:$FIX_USER" /var/log/qemu-mac*.log
                chmod 664 /var/log/qemu-mac*.log
                
                systemctl daemon-reload
                print_success "Fixed configuration to use $FIX_USER"
                
                # Restart LightDM
                print_status "Restarting display manager..."
                systemctl restart lightdm
                return 0
            fi
        fi
    fi
    
    return 1
}

# Function to update existing installation with new features
update_pointer_control() {
    print_status "Checking for pointer control updates..."
    
    # Update QEMU configuration with pointer settings if not present
    if [ -f "/opt/retro-mac/qemu-config.json" ]; then
        # Check if pointer_mode exists in config
        if ! jq -e '.pointer_mode' /opt/retro-mac/qemu-config.json >/dev/null 2>&1; then
            print_status "Adding pointer control settings to configuration..."
            
            # Add pointer settings to config
            jq '. + {"pointer_mode": "usb-tablet", "grab_on_click": true}' /opt/retro-mac/qemu-config.json > /tmp/qemu-config-new.json
            mv /tmp/qemu-config-new.json /opt/retro-mac/qemu-config.json
            chmod 644 /opt/retro-mac/qemu-config.json
            chown www-data:www-data /opt/retro-mac/qemu-config.json 2>/dev/null || true
            
            print_success "Pointer control settings added to configuration"
        fi
    fi
    
    # Update startup script if it exists and is outdated
    if [ -f "/opt/retro-mac/start-mac.sh" ]; then
        if ! grep -q "POINTER_MODE" /opt/retro-mac/start-mac.sh; then
            print_status "Updating QEMU startup script with pointer control..."
            
            # Backup existing script
            cp /opt/retro-mac/start-mac.sh /opt/retro-mac/start-mac.sh.backup-$(date +%Y%m%d)
            
            # Extract the new startup script from this file and update
            awk '/^cat > \/opt\/retro-mac\/start-mac.sh << .EOF.$/{flag=1; next} /^EOF$/ && flag{flag=0} flag' "$0" > /opt/retro-mac/start-mac.sh
            chmod +x /opt/retro-mac/start-mac.sh
            
            # Set proper ownership
            if id retro >/dev/null 2>&1; then
                chown retro:retro /opt/retro-mac/start-mac.sh
            fi
            
            print_success "QEMU startup script updated with pointer control"
        fi
    fi
}

# Main setup begins here
main() {
    echo "=========================================="
    echo "Mac OS 9 Emulation Setup Script"
    echo "=========================================="
    echo ""
    
    # Check if running as root
    check_root
    
    # Check if this is fixing an existing installation
    if [ -f "/opt/retro-mac/start-mac.sh" ] && [ -f "/etc/systemd/system/qemu-mac.service" ]; then
        print_status "Existing installation detected"
        
        # Try to fix any configuration issues
        FIXED=false
        if fix_existing_installation; then
            FIXED=true
        fi
        
        # Update with new features
        update_pointer_control
        
        if [ "$FIXED" = true ]; then
            echo ""
            echo "=========================================="
            echo "Existing Installation Updated!"
            echo "=========================================="
            echo ""
            echo "The configuration has been corrected and updated."
            echo "New features added:"
            echo "• Pointer control settings (USB Tablet/Mouse/PS2)"
            echo "• Mouse grab configuration"
            echo ""
            echo "Access the web control panel to configure pointer settings."
            echo ""
            exit 0
        fi
    fi
    
    # Update package lists
    print_status "Updating package lists..."
    apt-get update -qq
    print_success "Package lists updated"
    
    # Install required packages
    print_status "Installing required packages..."
    
    # Apache2
    if is_package_installed apache2; then
        print_status "Apache2 already installed"
    else
        print_status "Installing Apache2..."
        apt-get install -y apache2
        print_success "Apache2 installed"
    fi
    
    # PHP and Apache PHP module
    if is_package_installed php; then
        print_status "PHP already installed"
    else
        print_status "Installing PHP and Apache PHP module..."
        apt-get install -y php libapache2-mod-php php-cli
        print_success "PHP installed"
    fi
    
    # QEMU
    if is_package_installed qemu-system-ppc; then
        print_status "QEMU PPC already installed"
    else
        print_status "Installing QEMU for PowerPC emulation..."
        apt-get install -y qemu-system-ppc qemu-utils
        print_success "QEMU PPC installed"
    fi
    
    # Plymouth
    if is_package_installed plymouth; then
        print_status "Plymouth already installed"
    else
        print_status "Installing Plymouth..."
        apt-get install -y plymouth plymouth-themes plymouth-theme-ubuntu-text
        print_success "Plymouth installed"
    fi
    
    # X11 and display manager for QEMU
    print_status "Installing X11 and display components..."
    if is_package_installed xorg; then
        print_status "X11 already installed"
    else
        print_status "Installing X11 and minimal display manager..."
        # Install minimal X11 and lightdm for auto-login
        apt-get install -y xorg xinit lightdm lightdm-gtk-greeter openbox
        print_success "X11 and display manager installed"
    fi
    
    # Additional utilities
    print_status "Installing additional utilities..."
    apt-get install -y wget curl imagemagick jq qemu-utils
    print_success "Additional utilities installed"
    
    # Create directories
    print_status "Creating required directories..."
    mkdir -p /var/www/html
    mkdir -p /opt/retro-mac
    mkdir -p /opt/retro-mac/images
    mkdir -p /usr/share/plymouth/themes/retro-mac
    print_success "Directories created"
    
    # Download boot image
    print_status "Downloading boot image..."
    download_if_needed "https://www.mcchord.net/static/macTest.png" \
                       "/opt/retro-mac/images/macTest.png" \
                       "Mac boot image"
    
    # Configure Plymouth theme
    print_status "Configuring Plymouth theme..."
    
    # Create Plymouth theme script
    cat > /usr/share/plymouth/themes/retro-mac/retro-mac.script << 'EOF'
# Plymouth Theme: Retro Mac
# Shows centered Mac image during boot

Window.SetBackgroundTopColor(0.0, 0.0, 0.0);
Window.SetBackgroundBottomColor(0.0, 0.0, 0.0);

# Load and center the image
logo.image = Image("macTest.png");
logo.sprite = Sprite(logo.image);

# Get screen dimensions
screen.width = Window.GetWidth();
screen.height = Window.GetHeight();

# Center the image
logo.x = screen.width / 2 - logo.image.GetWidth() / 2;
logo.y = screen.height / 2 - logo.image.GetHeight() / 2;
logo.sprite.SetPosition(logo.x, logo.y, 0);

# Progress callback (optional)
fun progress_callback (duration, progress) {
    # Keep image centered
}

Plymouth.SetUpdateStatusFunction(progress_callback);
EOF
    
    # Create Plymouth theme configuration
    cat > /usr/share/plymouth/themes/retro-mac/retro-mac.plymouth << 'EOF'
[Plymouth Theme]
Name=Retro Mac
Description=Mac OS 9 Boot Screen
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/retro-mac
ScriptFile=/usr/share/plymouth/themes/retro-mac/retro-mac.script
EOF
    
    # Copy image to Plymouth theme directory
    if [ -f "/opt/retro-mac/images/macTest.png" ]; then
        cp /opt/retro-mac/images/macTest.png /usr/share/plymouth/themes/retro-mac/
        print_success "Plymouth theme configured"
    else
        print_warning "Boot image not found for Plymouth theme"
    fi
    
    # Install and set Plymouth theme
    if [ -f "/usr/share/plymouth/themes/retro-mac/retro-mac.plymouth" ]; then
        # Install the theme
        update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth \
                          /usr/share/plymouth/themes/retro-mac/retro-mac.plymouth 100
        
        # Set as default theme
        plymouth-set-default-theme retro-mac
        print_status "Plymouth theme set as default"
        
        # Ensure Plymouth is enabled in kernel parameters
        if ! grep -q "splash" /etc/default/grub; then
            sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 quiet splash"/' /etc/default/grub
            print_status "Added splash to kernel parameters"
        fi
        
        # Update initramfs with the new theme
        print_status "Updating initramfs for Plymouth..."
        update-initramfs -u
        print_success "Plymouth theme installed and configured"
    fi
    
    # Configure GRUB
    print_status "Configuring GRUB boot screen..."
    
    # Convert PNG to format suitable for GRUB if image exists
    if [ -f "/opt/retro-mac/images/macTest.png" ]; then
        print_status "Converting image for GRUB (centered, not stretched)..."
        # Create a properly sized image with the original centered (not stretched)
        convert /opt/retro-mac/images/macTest.png -background black -gravity center -extent 1024x768 /boot/grub/retro-mac.png
        
        # Backup original GRUB config
        if [ ! -f "/etc/default/grub.backup" ]; then
            cp /etc/default/grub /etc/default/grub.backup
            print_status "GRUB configuration backed up"
        fi
        
        # Update GRUB configuration
        if ! grep -q "GRUB_BACKGROUND=/boot/grub/retro-mac.png" /etc/default/grub; then
            echo "" >> /etc/default/grub
            echo "# Retro Mac boot image" >> /etc/default/grub
            echo "GRUB_BACKGROUND=/boot/grub/retro-mac.png" >> /etc/default/grub
        fi
        
        # Set GRUB graphics mode to prevent stretching
        if grep -q "^#GRUB_GFXMODE" /etc/default/grub; then
            sed -i 's/^#GRUB_GFXMODE=.*/GRUB_GFXMODE=1024x768/' /etc/default/grub
        elif ! grep -q "^GRUB_GFXMODE" /etc/default/grub; then
            echo "GRUB_GFXMODE=1024x768" >> /etc/default/grub
        fi
        
        # Keep the graphics mode for Linux
        if ! grep -q "GRUB_GFXPAYLOAD_LINUX" /etc/default/grub; then
            echo "GRUB_GFXPAYLOAD_LINUX=keep" >> /etc/default/grub
        fi
        
        # Set GRUB timeout for cleaner boot
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=2/' /etc/default/grub
        
        # Update GRUB
        print_status "Updating GRUB..."
        update-grub 2>/dev/null || print_warning "Could not update GRUB"
        print_success "GRUB configured"
    else
        print_warning "Boot image not found for GRUB configuration"
    fi
    
    # Download Mac OS 9 ISO
    print_status "Downloading Mac OS 9 ISO (this may take a while)..."
    download_if_needed "http://www.mcchord.net/static/macos_921_ppc.iso" \
                       "/opt/retro-mac/macos_921_ppc.iso" \
                       "Mac OS 9.2.1 ISO"
    
    # Create default QEMU configuration
    print_status "Creating default QEMU configuration..."
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
    print_success "Default configuration created"
    
    # Create QEMU startup script
    print_status "Creating QEMU startup script..."
    cat > /opt/retro-mac/start-mac.sh << 'EOF'
#!/bin/bash
# QEMU Mac OS 9 Emulator Script with Configuration Support

CONFIG_FILE="/opt/retro-mac/qemu-config.json"

# Wait for X11 to be available
max_wait=30
wait_count=0
while [ -z "$DISPLAY" ] && [ $wait_count -lt $max_wait ]; do
    export DISPLAY=:0
    if xset q &>/dev/null; then
        break
    fi
    sleep 1
    wait_count=$((wait_count + 1))
done

# Kill any existing QEMU instances
pkill -f qemu-system-ppc || true

# Read configuration
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
    # Defaults if config doesn't exist
    RAM="512"
    CPU="g4"
    MACHINE="mac99,via=pmu"
    RESOLUTION="1024x768x32"
    FULLSCREEN="true"
    BOOT="d"
    CDROM="/opt/retro-mac/macos_921_ppc.iso"
    CUSTOM_ARGS=""
    NETWORK="user"
    SOUND="true"
    POINTER_MODE="usb-tablet"
    GRAB_ON_CLICK="true"
fi

# Build QEMU command
CMD="qemu-system-ppc"
CMD="$CMD -M $MACHINE"
CMD="$CMD -m $RAM"
CMD="$CMD -cpu $CPU"
CMD="$CMD -g $RESOLUTION"
CMD="$CMD -boot $BOOT"

# Configure pointer/mouse based on settings
if [ "$POINTER_MODE" = "usb-tablet" ]; then
    # USB tablet provides absolute positioning (no grab needed)
    CMD="$CMD -device usb-tablet"
    CMD="$CMD -device usb-kbd"
elif [ "$POINTER_MODE" = "usb-mouse" ]; then
    # USB mouse with relative positioning (traditional grab)
    CMD="$CMD -device usb-mouse"
    CMD="$CMD -device usb-kbd"
elif [ "$POINTER_MODE" = "ps2" ]; then
    # PS/2 mouse (legacy)
    # PS/2 devices are included by default in mac99
    CMD="$CMD -device usb-kbd"
else
    # Default to USB tablet
    CMD="$CMD -device usb-tablet"
    CMD="$CMD -device usb-kbd"
fi

# Add CDROM if specified
if [ -n "$CDROM" ] && [ "$CDROM" != "null" ] && [ -f "$CDROM" ]; then
    CMD="$CMD -drive file=$CDROM,format=raw,media=cdrom"
fi

# Add hard drives
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

# Network configuration
if [ "$NETWORK" = "none" ]; then
    CMD="$CMD -netdev none,id=none"
else
    CMD="$CMD -netdev $NETWORK,id=net0 -device rtl8139,netdev=net0"
fi

# Sound configuration
if [ "$SOUND" = "true" ]; then
    CMD="$CMD -device ES1370"
fi

# Fullscreen
if [ "$FULLSCREEN" = "true" ]; then
    CMD="$CMD -full-screen"
fi

# Display and grab settings
if [ "$GRAB_ON_CLICK" = "false" ]; then
    CMD="$CMD -display sdl,grab-mod=rctrl"
else
    CMD="$CMD -display sdl"
fi

# Add custom arguments
if [ -n "$CUSTOM_ARGS" ]; then
    CMD="$CMD $CUSTOM_ARGS"
fi

# Create log files if they don't exist and ensure we can write to them
touch /var/log/qemu-mac-cmd.log /var/log/qemu-mac.log 2>/dev/null || true

# Try to write to system logs, fall back to user directory if that fails
if [ -w /var/log/qemu-mac-cmd.log ]; then
    echo "Starting QEMU with: $CMD" > /var/log/qemu-mac-cmd.log
    exec $CMD 2>/var/log/qemu-mac.log
else
    # Fall back to user directory for logs
    LOG_DIR="$HOME/.local/share/qemu-mac"
    mkdir -p "$LOG_DIR"
    echo "Starting QEMU with: $CMD" > "$LOG_DIR/qemu-mac-cmd.log"
    exec $CMD 2>"$LOG_DIR/qemu-mac.log"
fi
EOF
    chmod +x /opt/retro-mac/start-mac.sh
    print_success "QEMU startup script created"
    
    # Create systemd service for QEMU
    print_status "Creating QEMU systemd service..."
    cat > /etc/systemd/system/qemu-mac.service << 'EOF'
[Unit]
Description=QEMU Mac OS 9 Emulator
After=multi-user.target graphical.target display-manager.service
Wants=display-manager.service

[Service]
Type=simple
# Dynamic user detection - will be updated during installation
User=retro
Group=retro
Environment="HOME=/home/retro"
Environment="USER=retro"
Environment="DISPLAY=:0"
Environment="SDL_VIDEODRIVER=x11"
Environment="XAUTHORITY=/home/retro/.Xauthority"
ExecStartPre=/bin/bash -c 'until xset q &>/dev/null; do sleep 1; done'
ExecStart=/opt/retro-mac/start-mac.sh
Restart=on-failure
RestartSec=10
StartLimitBurst=3
StartLimitInterval=60
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=graphical.target
EOF
    
    # Configure LightDM for auto-login
    print_status "Configuring display manager for auto-login..."
    if [ -f "/etc/lightdm/lightdm.conf" ] || [ -d "/etc/lightdm" ]; then
        # Determine the non-root user to use for auto-login
        # Use the first regular user (UID >= 1000) or 'retro' if it exists
        if id retro >/dev/null 2>&1; then
            AUTO_USER="retro"
        else
            AUTO_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | head -1)
            if [ -z "$AUTO_USER" ]; then
                print_warning "No regular user found for auto-login, skipping auto-login setup"
                AUTO_USER=""
            fi
        fi
        
        if [ -n "$AUTO_USER" ]; then
            print_status "Setting up auto-login for user: $AUTO_USER"
            
            # Create or update LightDM configuration
            cat > /etc/lightdm/lightdm.conf << EOF
[Seat:*]
autologin-user=$AUTO_USER
autologin-user-timeout=0
user-session=openbox
greeter-show-manual-login=true
greeter-hide-users=false

[SeatDefaults]
autologin-user=$AUTO_USER
autologin-user-timeout=0
EOF
            print_success "LightDM configured for auto-login with user $AUTO_USER"
            
            # Create PAM autologin configuration
            cat > /etc/pam.d/lightdm-autologin << 'EOF'
# PAM configuration for LightDM autologin
auth      requisite pam_nologin.so
auth      required  pam_succeed_if.so user != root quiet_success
auth      required  pam_permit.so
@include common-account
session   optional  pam_keyinit.so force revoke
session   required  pam_limits.so
@include common-session
@include common-password
EOF
            print_success "PAM autologin configured"
            
            # Create openbox autostart for QEMU
            USER_HOME=$(getent passwd "$AUTO_USER" | cut -d: -f6)
            mkdir -p "$USER_HOME/.config/openbox"
            cat > "$USER_HOME/.config/openbox/autostart" << 'EOF'
#!/bin/bash
# Start QEMU Mac emulator after X11 starts
sleep 5
export DISPLAY=:0
sudo systemctl start qemu-mac.service &
EOF
            chmod +x "$USER_HOME/.config/openbox/autostart"
            chown -R "$AUTO_USER:$AUTO_USER" "$USER_HOME/.config"
            print_success "Openbox autostart configured for $AUTO_USER"
            
            # Add sudo permissions for the auto-login user
            if ! grep -q "$AUTO_USER.*systemctl.*qemu-mac" /etc/sudoers; then
                echo "" >> /etc/sudoers
                echo "# Allow $AUTO_USER to control QEMU service" >> /etc/sudoers
                echo "$AUTO_USER ALL=(ALL) NOPASSWD: /bin/systemctl start qemu-mac.service" >> /etc/sudoers
                echo "$AUTO_USER ALL=(ALL) NOPASSWD: /bin/systemctl stop qemu-mac.service" >> /etc/sudoers
                echo "$AUTO_USER ALL=(ALL) NOPASSWD: /bin/systemctl restart qemu-mac.service" >> /etc/sudoers
                echo "$AUTO_USER ALL=(ALL) NOPASSWD: /bin/systemctl status qemu-mac.service" >> /etc/sudoers
                print_success "Sudo permissions configured for $AUTO_USER"
            fi
        fi
    fi
    
    # Update QEMU service with correct user
    if [ -n "$AUTO_USER" ] && [ -f "/etc/systemd/system/qemu-mac.service" ]; then
        print_status "Updating QEMU service to run as $AUTO_USER..."
        USER_HOME=$(getent passwd "$AUTO_USER" | cut -d: -f6)
        
        # Update the service file with the correct user
        sed -i "s|^User=.*|User=$AUTO_USER|" /etc/systemd/system/qemu-mac.service
        sed -i "s|^Group=.*|Group=$AUTO_USER|" /etc/systemd/system/qemu-mac.service
        sed -i "s|Environment=\"HOME=.*\"|Environment=\"HOME=$USER_HOME\"|" /etc/systemd/system/qemu-mac.service
        sed -i "s|Environment=\"USER=.*\"|Environment=\"USER=$AUTO_USER\"|" /etc/systemd/system/qemu-mac.service
        sed -i "s|Environment=\"XAUTHORITY=.*\"|Environment=\"XAUTHORITY=$USER_HOME/.Xauthority\"|" /etc/systemd/system/qemu-mac.service
        
        # Ensure user has necessary permissions
        usermod -a -G video,audio,input "$AUTO_USER" 2>/dev/null || true
        
        # Set ownership of retro-mac directory
        chown -R "$AUTO_USER:$AUTO_USER" /opt/retro-mac/
        chmod 755 /opt/retro-mac
        
        # Create log files with proper permissions
        touch /var/log/qemu-mac.log /var/log/qemu-mac-cmd.log
        chown "$AUTO_USER:$AUTO_USER" /var/log/qemu-mac*.log
        chmod 664 /var/log/qemu-mac*.log
        
        print_success "QEMU service configured for user $AUTO_USER"
    fi
    
    # Reload systemd and enable service
    systemctl daemon-reload
    
    if ! systemctl is-enabled qemu-mac.service >/dev/null 2>&1; then
        systemctl enable qemu-mac.service
        print_success "QEMU service enabled for boot startup"
    else
        print_status "QEMU service already enabled"
    fi
    
    # Enable LightDM
    if systemctl list-unit-files | grep -q lightdm; then
        systemctl enable lightdm 2>/dev/null || true
        print_status "LightDM display manager enabled"
    fi
    
    # Create PHP control panel
    print_status "Creating PHP control panel..."
    cat > /var/www/html/index.php << 'EOF'
<?php
// Mac OS 9 Emulator Control Panel with Classic Mac OS 9 Interface Design

$config_file = '/opt/retro-mac/qemu-config.json';
$drives_dir = '/opt/retro-mac/drives';

// Create drives directory if it doesn't exist
if (!file_exists($drives_dir)) {
    mkdir($drives_dir, 0755, true);
}

// Load configuration
function load_config() {
    global $config_file;
    if (file_exists($config_file)) {
        return json_decode(file_get_contents($config_file), true);
    }
    return [
        'ram' => '512',
        'cpu' => 'g4',
        'machine' => 'mac99,via=pmu',
        'resolution' => '1024x768x32',
        'fullscreen' => true,
        'boot_device' => 'd',
        'cdrom' => '/opt/retro-mac/macos_921_ppc.iso',
        'hard_drives' => [],
        'custom_args' => '',
        'network' => 'user',
        'sound' => true,
        'pointer_mode' => 'usb-tablet',
        'grab_on_click' => true
    ];
}

// Save configuration
function save_config($config) {
    global $config_file;
    file_put_contents($config_file, json_encode($config, JSON_PRETTY_PRINT));
    chmod($config_file, 0644);
}

$config = load_config();
$message = '';
$message_type = '';

// Handle form submissions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        switch ($_POST['action']) {
            case 'start':
                exec('sudo systemctl start qemu-mac.service 2>&1', $output, $return);
                $message = $return === 0 ? 'QEMU started successfully' : 'Failed to start QEMU';
                $message_type = $return === 0 ? 'success' : 'error';
                break;
                
            case 'stop':
                exec('sudo systemctl stop qemu-mac.service 2>&1', $output, $return);
                $message = $return === 0 ? 'QEMU stopped successfully' : 'Failed to stop QEMU';
                $message_type = $return === 0 ? 'success' : 'error';
                break;
                
            case 'restart':
                exec('sudo systemctl restart qemu-mac.service 2>&1', $output, $return);
                $message = $return === 0 ? 'QEMU restarted successfully' : 'Failed to restart QEMU';
                $message_type = $return === 0 ? 'success' : 'error';
                break;
                
            case 'save_config':
                // Update configuration from form
                $config['ram'] = $_POST['ram'] ?? '512';
                $config['cpu'] = $_POST['cpu'] ?? 'g4';
                $config['resolution'] = $_POST['resolution'] ?? '1024x768x32';
                $config['fullscreen'] = isset($_POST['fullscreen']);
                $config['boot_device'] = $_POST['boot_device'] ?? 'd';
                $config['custom_args'] = $_POST['custom_args'] ?? '';
                $config['network'] = $_POST['network'] ?? 'user';
                $config['sound'] = isset($_POST['sound']);
                $config['pointer_mode'] = $_POST['pointer_mode'] ?? 'usb-tablet';
                $config['grab_on_click'] = isset($_POST['grab_on_click']);
                save_config($config);
                $message = 'Configuration saved successfully';
                $message_type = 'success';
                break;
                
            case 'create_drive':
                $size = $_POST['drive_size'] ?? '2G';
                $name = preg_replace('/[^a-zA-Z0-9_-]/', '', $_POST['drive_name'] ?? 'disk');
                $format = $_POST['drive_format'] ?? 'qcow2';
                if ($name) {
                    $drive_path = "$drives_dir/$name.$format";
                    if (!file_exists($drive_path)) {
                        exec("sudo qemu-img create -f $format $drive_path $size 2>&1", $output, $return);
                        if ($return === 0) {
                            $config['hard_drives'][] = ['path' => $drive_path, 'format' => $format];
                            save_config($config);
                            $message = "Drive '$name' created successfully";
                            $message_type = 'success';
                        } else {
                            $message = 'Failed to create drive: ' . implode(' ', $output);
                            $message_type = 'error';
                        }
                    } else {
                        $message = 'Drive already exists';
                        $message_type = 'error';
                    }
                }
                break;
                
            case 'remove_drive':
                $index = intval($_POST['drive_index'] ?? -1);
                if ($index >= 0 && isset($config['hard_drives'][$index])) {
                    array_splice($config['hard_drives'], $index, 1);
                    save_config($config);
                    $message = 'Drive removed from configuration';
                    $message_type = 'success';
                }
                break;
        }
    }
}

// Reload config after changes
$config = load_config();

// Get system information
$hostname = gethostname();
$uptime = shell_exec('uptime -p');
$load = sys_getloadavg();
$memory = shell_exec("free -h | grep Mem | awk '{print $3 \" / \" $2}'");
$disk = shell_exec("df -h / | tail -1 | awk '{print $3 \" / \" $2 \" (\" $5 \" used)\"}'");

// Check QEMU status
$qemu_status = trim(shell_exec('systemctl is-active qemu-mac.service'));
$qemu_running = ($qemu_status === 'active');

// Get CPU info
$cpu_info = shell_exec("lscpu | grep 'Model name' | cut -d: -f2 | xargs");
$cpu_cores = shell_exec("nproc");

?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Mac OS 9 Control Panel</title>
    <style>
        @font-face {
            font-family: 'Chicago';
            src: local('Chicago'), local('Geneva'), local('Helvetica'), sans-serif;
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Chicago', 'Geneva', 'Helvetica', sans-serif;
            font-size: 12px;
            background: #DDDDDD;
            background-image: 
                repeating-linear-gradient(
                    0deg,
                    transparent,
                    transparent 1px,
                    #CCCCCC 1px,
                    #CCCCCC 2px
                );
            color: #000000;
            padding: 0;
            margin: 0;
            min-height: 100vh;
        }
        
        /* Mac OS 9 Desktop Menu Bar */
        .menu-bar {
            background: linear-gradient(to bottom, #FFFFFF 0%, #DDDDDD 50%, #BBBBBB 100%);
            border-bottom: 1px solid #000000;
            height: 20px;
            display: flex;
            align-items: center;
            padding: 0 10px;
            font-weight: bold;
            font-size: 12px;
        }
        
        .menu-bar .apple-menu {
            margin-right: 20px;
            font-size: 14px;
        }
        
        .menu-bar .menu-item {
            margin-right: 15px;
            cursor: default;
        }
        
        .menu-bar .right-menu {
            margin-left: auto;
            display: flex;
            align-items: center;
        }
        
        /* Container */
        .desktop {
            padding: 20px;
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            justify-content: center;
        }
        
        /* Classic Mac OS 9 Window */
        .window {
            background: #DDDDDD;
            border: 1px solid #000000;
            box-shadow: 2px 2px 0px #000000;
            min-width: 400px;
            max-width: 600px;
        }
        
        /* Window Title Bar */
        .window-titlebar {
            background: linear-gradient(
                to bottom,
                #FFFFFF 0%,
                #DDDDDD 45%,
                #BBBBBB 50%,
                #999999 100%
            );
            background-size: 100% 4px;
            border-bottom: 1px solid #000000;
            height: 20px;
            display: flex;
            align-items: center;
            padding: 0 8px;
            position: relative;
            cursor: default;
        }
        
        .window-titlebar.active {
            background: repeating-linear-gradient(
                to bottom,
                #FFFFFF 0px,
                #FFFFFF 1px,
                #000000 1px,
                #000000 2px,
                #FFFFFF 2px,
                #FFFFFF 3px,
                #BBBBBB 3px,
                #BBBBBB 4px
            );
        }
        
        /* Window Controls */
        .window-controls {
            display: flex;
            gap: 8px;
            margin-right: 8px;
        }
        
        .window-control {
            width: 12px;
            height: 12px;
            border: 1px solid #000000;
            background: #DDDDDD;
            box-shadow: inset 1px 1px 0px #FFFFFF, inset -1px -1px 0px #999999;
        }
        
        .window-control.close {
            background: #DDDDDD;
        }
        
        .window-title {
            flex: 1;
            text-align: center;
            font-weight: bold;
            font-size: 12px;
        }
        
        /* Window Content */
        .window-content {
            padding: 10px;
            background: #DDDDDD;
        }
        
        /* Classic Mac Buttons */
        .btn {
            background: #DDDDDD;
            border: 2px solid #000000;
            border-radius: 5px;
            padding: 4px 16px;
            font-family: 'Chicago', 'Geneva', sans-serif;
            font-size: 12px;
            font-weight: bold;
            cursor: pointer;
            box-shadow: 
                inset 1px 1px 0px #FFFFFF,
                inset -1px -1px 0px #999999,
                1px 1px 0px #000000;
            min-width: 80px;
            height: 24px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
        }
        
        .btn:active {
            box-shadow: 
                inset -1px -1px 0px #FFFFFF,
                inset 1px 1px 0px #999999;
        }
        
        .btn:focus {
            outline: 2px solid #000000;
            outline-offset: 2px;
        }
        
        .btn.default {
            border: 3px solid #000000;
        }
        
        .btn-start {
            background: #CCFFCC;
        }
        
        .btn-stop {
            background: #FFCCCC;
        }
        
        .btn-restart {
            background: #FFFFCC;
        }
        
        /* Classic Mac Input Fields */
        input[type="text"],
        input[type="number"],
        select,
        textarea {
            background: #FFFFFF;
            border: 1px solid #000000;
            box-shadow: inset 1px 1px 0px #999999;
            padding: 2px 4px;
            font-family: 'Geneva', 'Monaco', monospace;
            font-size: 12px;
            width: 100%;
        }
        
        select {
            appearance: none;
            background-image: url('data:image/svg+xml;utf8,<svg fill="black" height="8" viewBox="0 0 8 8" width="8" xmlns="http://www.w3.org/2000/svg"><path d="M0 2l4 4 4-4z"/></svg>');
            background-repeat: no-repeat;
            background-position: right 4px center;
            padding-right: 20px;
        }
        
        /* Classic Mac Checkbox */
        input[type="checkbox"] {
            appearance: none;
            width: 12px;
            height: 12px;
            border: 1px solid #000000;
            background: #FFFFFF;
            box-shadow: inset 1px 1px 0px #999999;
            vertical-align: middle;
            margin-right: 4px;
            cursor: pointer;
        }
        
        input[type="checkbox"]:checked {
            background: #FFFFFF;
            position: relative;
        }
        
        input[type="checkbox"]:checked::after {
            content: "✓";
            position: absolute;
            top: -2px;
            left: 1px;
            font-size: 10px;
            font-weight: bold;
        }
        
        /* Form Groups */
        .form-group {
            margin-bottom: 10px;
        }
        
        .form-group label {
            display: block;
            margin-bottom: 2px;
            font-weight: bold;
        }
        
        /* Info Box */
        .info-box {
            background: #FFFFFF;
            border: 1px solid #000000;
            box-shadow: inset 1px 1px 0px #999999;
            padding: 8px;
            margin-bottom: 10px;
        }
        
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 2px 0;
        }
        
        .info-label {
            font-weight: bold;
        }
        
        /* Status Indicator */
        .status-indicator {
            display: inline-block;
            width: 10px;
            height: 10px;
            border: 1px solid #000000;
            border-radius: 50%;
            margin-left: 4px;
        }
        
        .status-indicator.running {
            background: #00FF00;
        }
        
        .status-indicator.stopped {
            background: #FF0000;
        }
        
        /* Alert Box */
        .alert {
            background: #FFFFCC;
            border: 2px solid #000000;
            padding: 8px;
            margin-bottom: 10px;
            font-weight: bold;
            box-shadow: 2px 2px 0px #000000;
        }
        
        .alert.success {
            background: #CCFFCC;
        }
        
        .alert.error {
            background: #FFCCCC;
        }
        
        /* Drive List */
        .drive-list {
            background: #FFFFFF;
            border: 1px solid #000000;
            box-shadow: inset 1px 1px 0px #999999;
            padding: 4px;
            min-height: 60px;
            max-height: 120px;
            overflow-y: auto;
            margin-bottom: 10px;
        }
        
        .drive-item {
            padding: 2px;
            border-bottom: 1px dotted #999999;
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        
        .drive-item:last-child {
            border-bottom: none;
        }
        
        /* Button Groups */
        .button-group {
            display: flex;
            gap: 8px;
            margin-top: 10px;
            justify-content: center;
        }
        
        /* Tabs */
        .tab-container {
            margin-top: 10px;
        }
        
        .tab-buttons {
            display: flex;
            border-bottom: 1px solid #000000;
        }
        
        .tab-button {
            background: #CCCCCC;
            border: 1px solid #000000;
            border-bottom: none;
            padding: 4px 16px;
            margin-right: 2px;
            cursor: pointer;
            font-weight: bold;
            position: relative;
            top: 1px;
        }
        
        .tab-button.active {
            background: #DDDDDD;
            border-bottom: 1px solid #DDDDDD;
        }
        
        .tab-content {
            background: #DDDDDD;
            border: 1px solid #000000;
            border-top: none;
            padding: 10px;
        }
        
        .tab-pane {
            display: none;
        }
        
        .tab-pane.active {
            display: block;
        }
        
        /* Classic Mac Scrollbar */
        ::-webkit-scrollbar {
            width: 16px;
            height: 16px;
        }
        
        ::-webkit-scrollbar-track {
            background: #CCCCCC;
            border: 1px solid #000000;
        }
        
        ::-webkit-scrollbar-thumb {
            background: #999999;
            border: 1px solid #000000;
            box-shadow: inset 1px 1px 0px #FFFFFF, inset -1px -1px 0px #666666;
        }
        
        /* Desktop Icon */
        .desktop-icon {
            width: 64px;
            text-align: center;
            margin: 20px;
            cursor: pointer;
        }
        
        .desktop-icon img {
            width: 32px;
            height: 32px;
            image-rendering: pixelated;
            margin-bottom: 4px;
        }
        
        .desktop-icon-label {
            font-size: 10px;
            background: white;
            padding: 1px 3px;
            border: 1px dotted transparent;
        }
        
        .desktop-icon:hover .desktop-icon-label {
            border: 1px dotted black;
        }
    </style>
</head>
<body>
    <!-- Mac OS 9 Menu Bar -->
    <div class="menu-bar">
        <span class="apple-menu">🍎</span>
        <span class="menu-item">File</span>
        <span class="menu-item">Edit</span>
        <span class="menu-item">View</span>
        <span class="menu-item">Special</span>
        <span class="menu-item">Help</span>
        <div class="right-menu">
            <span><?php echo date('g:i A'); ?></span>
        </div>
    </div>
    
    <div class="desktop">
        <?php if ($message): ?>
        <div class="alert <?php echo $message_type; ?>">
            <?php echo htmlspecialchars($message); ?>
        </div>
        <?php endif; ?>
        
        <!-- QEMU Control Window -->
        <div class="window">
            <div class="window-titlebar active">
                <div class="window-controls">
                    <div class="window-control close"></div>
                </div>
                <div class="window-title">Mac OS 9 Emulator Control</div>
            </div>
            <div class="window-content">
                <div class="info-box">
                    <div class="info-row">
                        <span class="info-label">Status:</span>
                        <span>
                            <?php echo $qemu_running ? 'Running' : 'Stopped'; ?>
                            <span class="status-indicator <?php echo $qemu_running ? 'running' : 'stopped'; ?>"></span>
                        </span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Host:</span>
                        <span><?php echo htmlspecialchars($hostname); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Uptime:</span>
                        <span><?php echo htmlspecialchars(trim($uptime)); ?></span>
                    </div>
                </div>
                
                <form method="post" action="">
                    <div class="button-group">
                        <button type="submit" name="action" value="start" class="btn btn-start" 
                                <?php echo $qemu_running ? 'disabled' : ''; ?>>
                            Start
                        </button>
                        <button type="submit" name="action" value="stop" class="btn btn-stop"
                                <?php echo !$qemu_running ? 'disabled' : ''; ?>>
                            Stop
                        </button>
                        <button type="submit" name="action" value="restart" class="btn btn-restart">
                            Restart
                        </button>
                    </div>
                </form>
            </div>
        </div>
        
        <!-- Configuration Window -->
        <div class="window">
            <div class="window-titlebar active">
                <div class="window-controls">
                    <div class="window-control close"></div>
                </div>
                <div class="window-title">Configuration</div>
            </div>
            <div class="window-content">
                <div class="tab-container">
                    <div class="tab-buttons">
                        <div class="tab-button active" onclick="switchTab('general')">General</div>
                        <div class="tab-button" onclick="switchTab('drives')">Drives</div>
                        <div class="tab-button" onclick="switchTab('advanced')">Advanced</div>
                    </div>
                    
                    <div class="tab-content">
                        <!-- General Tab -->
                        <div class="tab-pane active" id="general-tab">
                            <form method="post" action="">
                                <div class="form-group">
                                    <label>Memory (MB):</label>
                                    <input type="number" name="ram" value="<?php echo htmlspecialchars($config['ram']); ?>" min="128" max="8192">
                                </div>
                                
                                <div class="form-group">
                                    <label>Processor:</label>
                                    <select name="cpu">
                                        <option value="g3" <?php echo $config['cpu'] === 'g3' ? 'selected' : ''; ?>>PowerPC G3</option>
                                        <option value="g4" <?php echo $config['cpu'] === 'g4' ? 'selected' : ''; ?>>PowerPC G4</option>
                                        <option value="750" <?php echo $config['cpu'] === '750' ? 'selected' : ''; ?>>PowerPC 750</option>
                                    </select>
                                </div>
                                
                                <div class="form-group">
                                    <label>Display:</label>
                                    <select name="resolution">
                                        <option value="640x480x8" <?php echo $config['resolution'] === '640x480x8' ? 'selected' : ''; ?>>640×480 (256 colors)</option>
                                        <option value="800x600x16" <?php echo $config['resolution'] === '800x600x16' ? 'selected' : ''; ?>>800×600 (Thousands)</option>
                                        <option value="1024x768x32" <?php echo $config['resolution'] === '1024x768x32' ? 'selected' : ''; ?>>1024×768 (Millions)</option>
                                    </select>
                                </div>
                                
                                <div class="form-group">
                                    <label>
                                        <input type="checkbox" name="fullscreen" <?php echo $config['fullscreen'] ? 'checked' : ''; ?>>
                                        Full Screen
                                    </label>
                                </div>
                                
                                <div class="form-group">
                                    <label>
                                        <input type="checkbox" name="sound" <?php echo $config['sound'] ? 'checked' : ''; ?>>
                                        Enable Sound
                                    </label>
                                </div>
                                
                                <div class="button-group">
                                    <button type="submit" name="action" value="save_config" class="btn default">Save</button>
                                </div>
                            </form>
                        </div>
                        
                        <!-- Drives Tab -->
                        <div class="tab-pane" id="drives-tab">
                            <div class="form-group">
                                <label>Mounted Drives:</label>
                                <div class="drive-list">
                                    <?php if (empty($config['hard_drives'])): ?>
                                        <div style="color: #999; text-align: center; padding: 20px;">No drives mounted</div>
                                    <?php else: ?>
                                        <?php foreach ($config['hard_drives'] as $index => $drive): ?>
                                            <div class="drive-item">
                                                <span>📁 <?php echo htmlspecialchars(basename($drive['path'])); ?></span>
                                                <form method="post" action="" style="display: inline;">
                                                    <input type="hidden" name="drive_index" value="<?php echo $index; ?>">
                                                    <button type="submit" name="action" value="remove_drive" class="btn" style="padding: 2px 8px; min-width: 50px; height: 20px;">Eject</button>
                                                </form>
                                            </div>
                                        <?php endforeach; ?>
                                    <?php endif; ?>
                                </div>
                            </div>
                            
                            <form method="post" action="">
                                <div class="form-group">
                                    <label>Create New Drive:</label>
                                    <input type="text" name="drive_name" placeholder="Drive name" required>
                                </div>
                                <div class="form-group">
                                    <label>Size:</label>
                                    <select name="drive_size">
                                        <option value="500M">500 MB</option>
                                        <option value="1G">1 GB</option>
                                        <option value="2G" selected>2 GB</option>
                                        <option value="4G">4 GB</option>
                                    </select>
                                </div>
                                <div class="button-group">
                                    <button type="submit" name="action" value="create_drive" class="btn">Create</button>
                                </div>
                            </form>
                        </div>
                        
                        <!-- Advanced Tab -->
                        <div class="tab-pane" id="advanced-tab">
                            <form method="post" action="">
                                <div class="form-group">
                                    <label>Boot Device:</label>
                                    <select name="boot_device">
                                        <option value="d" <?php echo $config['boot_device'] === 'd' ? 'selected' : ''; ?>>CD-ROM</option>
                                        <option value="c" <?php echo $config['boot_device'] === 'c' ? 'selected' : ''; ?>>Hard Drive</option>
                                    </select>
                                </div>
                                
                                <div class="form-group">
                                    <label>Network:</label>
                                    <select name="network">
                                        <option value="user" <?php echo $config['network'] === 'user' ? 'selected' : ''; ?>>User Mode (NAT)</option>
                                        <option value="none" <?php echo $config['network'] === 'none' ? 'selected' : ''; ?>>Disabled</option>
                                    </select>
                                </div>
                                
                                <div class="form-group">
                                    <label>Pointer Control:</label>
                                    <select name="pointer_mode">
                                        <option value="usb-tablet" <?php echo ($config['pointer_mode'] ?? 'usb-tablet') === 'usb-tablet' ? 'selected' : ''; ?>>USB Tablet (Seamless)</option>
                                        <option value="usb-mouse" <?php echo ($config['pointer_mode'] ?? '') === 'usb-mouse' ? 'selected' : ''; ?>>USB Mouse (Grab Required)</option>
                                        <option value="ps2" <?php echo ($config['pointer_mode'] ?? '') === 'ps2' ? 'selected' : ''; ?>>PS/2 Mouse (Legacy)</option>
                                    </select>
                                    <div style="font-size: 10px; color: #666; margin-top: 2px;">
                                        USB Tablet: Best for windowed mode, no grab needed<br>
                                        USB Mouse: Traditional mode, click to grab/ungrab<br>
                                        PS/2: Legacy support for older systems
                                    </div>
                                </div>
                                
                                <div class="form-group">
                                    <label>
                                        <input type="checkbox" name="grab_on_click" <?php echo ($config['grab_on_click'] ?? true) ? 'checked' : ''; ?>>
                                        Grab mouse on click (USB Mouse mode)
                                    </label>
                                    <div style="font-size: 10px; color: #666; margin-top: 2px;">
                                        When unchecked, use right-Ctrl to grab/ungrab mouse
                                    </div>
                                </div>
                                
                                <div class="form-group">
                                    <label>Custom Arguments:</label>
                                    <textarea name="custom_args" rows="3"><?php echo htmlspecialchars($config['custom_args']); ?></textarea>
                                </div>
                                
                                <div class="button-group">
                                    <button type="submit" name="action" value="save_config" class="btn default">Save</button>
                                </div>
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        
        <!-- System Info Window -->
        <div class="window">
            <div class="window-titlebar active">
                <div class="window-controls">
                    <div class="window-control close"></div>
                </div>
                <div class="window-title">System Information</div>
            </div>
            <div class="window-content">
                <div class="info-box">
                    <div class="info-row">
                        <span class="info-label">CPU:</span>
                        <span><?php echo htmlspecialchars(trim($cpu_info)); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Cores:</span>
                        <span><?php echo htmlspecialchars(trim($cpu_cores)); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Memory:</span>
                        <span><?php echo htmlspecialchars(trim($memory)); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Disk:</span>
                        <span><?php echo htmlspecialchars(trim($disk)); ?></span>
                    </div>
                    <div class="info-row">
                        <span class="info-label">Load:</span>
                        <span><?php echo number_format($load[0], 2); ?></span>
                    </div>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        function switchTab(tabName) {
            // Hide all tabs
            document.querySelectorAll('.tab-pane').forEach(function(pane) {
                pane.classList.remove('active');
            });
            document.querySelectorAll('.tab-button').forEach(function(button) {
                button.classList.remove('active');
            });
            
            // Show selected tab
            document.getElementById(tabName + '-tab').classList.add('active');
            event.target.classList.add('active');
        }
        
        // Auto-refresh every 30 seconds
        setTimeout(function() {
            location.reload();
        }, 30000);
    </script>
</body>
</html>
EOF
    
    # Remove default Apache index.html if it exists
    rm -f /var/www/html/index.html
    
    # Set proper permissions
    chown -R www-data:www-data /var/www/html
    chmod 644 /var/www/html/index.php
    
    print_success "PHP control panel created"
    
    # Configure sudoers for www-data to control QEMU service and manage drives
    print_status "Configuring sudo permissions for web interface..."
    if ! grep -q "www-data.*systemctl.*qemu-mac" /etc/sudoers; then
        echo "" >> /etc/sudoers
        echo "# Allow www-data to control QEMU service" >> /etc/sudoers
        echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl start qemu-mac.service" >> /etc/sudoers
        echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl stop qemu-mac.service" >> /etc/sudoers
        echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl restart qemu-mac.service" >> /etc/sudoers
        echo "www-data ALL=(ALL) NOPASSWD: /bin/systemctl status qemu-mac.service" >> /etc/sudoers
        echo "# Allow www-data to manage QEMU disk images" >> /etc/sudoers
        echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/qemu-img create *" >> /etc/sudoers
        echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/qemu-img info *" >> /etc/sudoers
        echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/qemu-img check *" >> /etc/sudoers
        print_success "Sudo permissions configured"
    else
        print_status "Sudo permissions already configured"
    fi
    
    # Create drives directory
    mkdir -p /opt/retro-mac/drives
    chown www-data:www-data /opt/retro-mac/drives
    chmod 755 /opt/retro-mac/drives
    
    # Set permissions on config file and drives directory
    if [ -f "/opt/retro-mac/qemu-config.json" ]; then
        chown www-data:www-data /opt/retro-mac/qemu-config.json
        chmod 664 /opt/retro-mac/qemu-config.json
    fi
    
    # Validate configuration files
    print_status "Validating configuration files..."
    CONFIG_OK=true
    
    # Check LightDM configuration
    if [ -f "/etc/lightdm/lightdm.conf" ]; then
        if grep -q "autologin-user=root" /etc/lightdm/lightdm.conf; then
            print_warning "LightDM is configured to auto-login as root (this usually doesn't work)"
            print_status "Fixing LightDM configuration..."
            if [ -n "$AUTO_USER" ]; then
                sed -i "s/autologin-user=root/autologin-user=$AUTO_USER/g" /etc/lightdm/lightdm.conf
                print_success "Fixed LightDM to use $AUTO_USER instead of root"
            fi
        fi
    fi
    
    # Check QEMU service configuration
    if [ -f "/etc/systemd/system/qemu-mac.service" ]; then
        SERVICE_USER=$(grep "^User=" /etc/systemd/system/qemu-mac.service | cut -d= -f2)
        if [ "$SERVICE_USER" = "root" ]; then
            print_warning "QEMU service is configured to run as root"
            if [ -n "$AUTO_USER" ]; then
                print_status "Updating QEMU service to run as $AUTO_USER..."
                sed -i "s/^User=root/User=$AUTO_USER/" /etc/systemd/system/qemu-mac.service
                systemctl daemon-reload
                print_success "Fixed QEMU service to run as $AUTO_USER"
            fi
        fi
    fi
    
    # Check QEMU configuration file
    if [ -f "/opt/retro-mac/qemu-config.json" ]; then
        if jq . /opt/retro-mac/qemu-config.json >/dev/null 2>&1; then
            print_success "QEMU configuration JSON is valid"
        else
            print_error "QEMU configuration JSON is invalid!"
            CONFIG_OK=false
        fi
    fi
    
    if [ "$CONFIG_OK" = true ]; then
        print_success "All configuration files validated"
    else
        print_warning "Some configuration issues were found - please review the messages above"
    fi
    
    # Enable Apache modules
    print_status "Enabling Apache PHP module..."
    a2enmod php8.2 2>/dev/null || a2enmod php 2>/dev/null || true
    
    # Restart Apache
    print_status "Restarting Apache..."
    systemctl restart apache2
    
    if is_service_running apache2; then
        print_success "Apache is running"
    else
        print_error "Apache failed to start"
    fi
    
    # Create a desktop file for manual QEMU launch (optional)
    if [ -d "/usr/share/applications" ]; then
        print_status "Creating desktop launcher..."
        cat > /usr/share/applications/retro-mac.desktop << 'EOF'
[Desktop Entry]
Version=1.0
Type=Application
Name=Retro Mac OS 9
Comment=Launch Mac OS 9 Emulator
Exec=/opt/retro-mac/start-mac.sh
Icon=/opt/retro-mac/images/macTest.png
Terminal=false
Categories=System;Emulator;
EOF
        chmod 644 /usr/share/applications/retro-mac.desktop
        print_success "Desktop launcher created"
    fi
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Setup Complete!"
    echo "=========================================="
    echo ""
    print_success "All components have been installed and configured"
    echo ""
    echo "Important Information:"
    echo "----------------------"
    echo "• Web Control Panel: http://$(hostname -I | awk '{print $1}')"
    echo "• ISO Location: /opt/retro-mac/macos_921_ppc.iso"
    echo "• QEMU Service: qemu-mac.service"
    echo "• Plymouth Theme: retro-mac"
    echo ""
    echo "Next Steps:"
    echo "-----------"
    echo "1. Access the web control panel to start/stop the emulator"
    echo "2. The emulator will start automatically on boot"
    echo "3. Reboot to see the new Plymouth and GRUB boot screens"
    echo ""
    echo "Commands:"
    echo "---------"
    echo "• Start QEMU: sudo systemctl start qemu-mac"
    echo "• Stop QEMU: sudo systemctl stop qemu-mac"
    echo "• Check status: sudo systemctl status qemu-mac"
    echo "• View logs: sudo journalctl -u qemu-mac -f"
    echo "• Edit config: nano /opt/retro-mac/qemu-config.json"
    
    # Final validation message
    if [ -n "$AUTO_USER" ]; then
        echo ""
        echo "Auto-login configured for user: $AUTO_USER"
        echo "If auto-login doesn't work after reboot, run:"
        echo "  sudo systemctl restart lightdm"
    fi
    echo ""
    
    # Check if all critical components are present
    if [ -f "/opt/retro-mac/macos_921_ppc.iso" ] && \
       [ -f "/opt/retro-mac/start-mac.sh" ] && \
       [ -f "/var/www/html/index.php" ]; then
        print_success "All critical files are in place"
    else
        print_warning "Some files may be missing - please check the setup"
    fi
}

# Run main function
main "$@"
