# Minimal Mac OS 9 Emulation Setup

A stripped-down version of makeRetro that installs only what's needed for Mac OS 9 PowerPC emulation.

## What's Removed

Compared to the full version, this removes:
- **PHP/Apache web interface** - No web-based control panel
- **systemd service** - No auto-start on boot
- **Custom boot screens** - No Plymouth/GRUB customization (purely aesthetic)
- **LightDM/auto-login** - Login normally
- **Openbox window manager** - Use any WM you prefer

## What's Included

- **QEMU (PowerPC)** - Emulates PowerPC G3/G4 hardware
- **X11** - Display server for QEMU's SDL output
- **Mac OS 9 ISO** - Downloads installer automatically
- **Configuration file** - JSON-based config at `/opt/retro-mac/qemu-config.json`
- **Startup script** - Simple script to launch QEMU
- **Helper scripts** - Quick commands for RAM, resolution, drives, and mouse troubleshooting

## Quick Start

```bash
sudo ./setup-minimal.sh
```

All helper scripts are installed automatically during setup.

## Usage

### Start the emulator
```bash
/opt/retro-mac/start-mac.sh
```

### Set RAM size
```bash
/opt/retro-mac/set-ram.sh 1024  # Set to 1GB
```

### Set display resolution
```bash
/opt/retro-mac/set-resolution.sh 1024x768x32  # Set specific resolution
/opt/retro-mac/set-resolution.sh auto           # Auto-detect screen size
/opt/retro-mac/set-resolution.sh                # Interactive menu
```

### Create a virtual hard drive
```bash
/opt/retro-mac/create-drive.sh mydisk 2G qcow2  # 2GB drive in QCOW2 format
```

### List configured drives
```bash
/opt/retro-mac/list-drives.sh
```

### Fix mouse/pointer issues
```bash
/opt/retro-mac/fix-mouse.sh  # Interactive mouse troubleshooting
```

### Edit configuration directly
```bash
nano /opt/retro-mac/qemu-config.json
```

## Helper Scripts

All scripts are located in `/opt/retro-mac/`:

- **start-mac.sh** - Start QEMU emulator
- **set-ram.sh <MB>** - Set RAM size (e.g., `set-ram.sh 1024`)
- **set-resolution.sh [resolution|auto]** - Set display resolution interactively (menu), or pass resolution directly
- **create-drive.sh <name> <size> [format]** - Create virtual hard drive (e.g., `create-drive.sh mydisk 2G qcow2`)
- **list-drives.sh** - List configured virtual drives
- **fix-mouse.sh** - Interactive mouse/pointer troubleshooting
- **auto-resolution.sh** - Auto-detect and set screen resolution
- **fix-grab.sh** - Test different grab modifiers (if Ctrl+Alt+G doesn't work)
- **toggle-fullscreen.sh** - Toggle between fullscreen and windowed mode

## Configuration

The default configuration (`/opt/retro-mac/qemu-config.json`):

```json
{
    "ram": "512",                    // Memory in MB
    "cpu": "g4",                    // CPU type: g3, g4, 750
    "machine": "mac99,via=pmu",     // Machine type
    "resolution": "1024x768x32",     // Display resolution
    "fullscreen": true,               // Fullscreen mode
    "boot_device": "d",              // 'c' = hard drive, 'd' = CD-ROM
    "cdrom": "/opt/retro-mac/macos_921_ppc.iso",
    "hard_drives": [],               // Array of virtual drives
    "custom_args": "",               // Additional QEMU arguments
    "network": "user",              // Network: 'user' (NAT) or 'none'
    "sound": true,                 // Enable ES1370 sound
    "pointer_mode": "usb-tablet",   // Pointer: usb-tablet, usb-mouse, ps2
    "grab_on_click": true           // Mouse grab behavior
}
```

## Keyboard Shortcuts in QEMU

- `Ctrl+Alt+F` - Toggle fullscreen
- `Ctrl+Alt+G` - Release mouse grab (for USB mouse/PS2 modes)
- `Right Ctrl` - Alternative release (if grab-mod=rctrl is set)
- `Ctrl+Alt+Q` - Quit QEMU

**Note:** USB Tablet mode (default) doesn't require mouse grab - the mouse moves seamlessly between host and guest.

### Can't release mouse grab?

If `Ctrl+Alt+G` doesn't work, run:
```bash
/opt/retro-mac/fix-grab.sh
```

This will test different grab modifiers to find what works on your system.

**Quick alternatives:**
- Use windowed mode: `/opt/retro-mac/toggle-fullscreen.sh`
- Quit QEMU with `Ctrl+Alt+Q` and restart
- Try different key combinations: `Ctrl+G`, `Alt+G`, `Ctrl+Alt`

## Requirements

- Debian 13 (Trixie) or compatible
- x86_64 architecture
- 2GB+ RAM recommended
- 2GB+ disk space for ISO and virtual drives

## Adding to PATH (Optional)

Add to your `~/.bashrc`:
```bash
export PATH="$PATH:/opt/retro-mac"
```

Then you can run:
```bash
start-mac.sh
set-ram.sh 512
set-resolution.sh            # Interactive menu
set-resolution.sh 1280x1024x32  # Direct setting
create-drive.sh disk 4G
list-drives.sh
fix-mouse.sh
fix-grab.sh               # If Ctrl+Alt+G doesn't work
toggle-fullscreen.sh        # Quick toggle fullscreen/windowed
```

## Troubleshooting

### QEMU doesn't start
```bash
# Check X11 is running
echo $DISPLAY  # Should show :0

# Start QEMU manually to see errors
bash -x /opt/retro-mac/start-mac.sh
```

### Mac OS desktop is too large or small for screen

**Interactive menu (easiest):**
```bash
/opt/retro-mac/set-resolution.sh
```
This will show a menu with all available resolutions.

**Auto-detect your screen resolution:**
```bash
/opt/retro-mac/set-resolution.sh auto
```

**Set resolution manually:**
```bash
/opt/retro-mac/set-resolution.sh 800x600x32    # Smaller
/opt/retro-mac/set-resolution.sh 1024x768x32  # Default
/opt/retro-mac/set-resolution.sh 1280x1024x32 # Larger
/opt/retro-mac/set-resolution.sh 1920x1080x32 # Full HD
```

**Available resolutions:**
- `640x480x32` - VGA (256 colors: use x8 instead)
- `800x600x32` - SVGA
- `1024x768x32` - XGA
- `1280x1024x32` - SXGA
- `1600x900x32` - HD
- `1920x1080x32` - Full HD

**Edit config directly:**
```bash
nano /opt/retro-mac/qemu-config.json
# Change "resolution": "1024x768x32" to your preferred size
```

### Mouse doesn't work or can't move pointer

**Run the interactive troubleshooting script:**
```bash
/opt/retro-mac/fix-mouse.sh
```

This will test all pointer modes so you can find what works on your system.

**Manual fixes - try these pointer modes in `/opt/retro-mac/qemu-config.json`:**

1. **usb-tablet** (recommended, default):
   ```json
   "pointer_mode": "usb-tablet"
   ```
   - Absolute positioning - mouse moves seamlessly
   - No grab needed
   - Best for windowed mode
   - If this doesn't work, try USB mouse

2. **usb-mouse**:
   ```json
   "pointer_mode": "usb-mouse"
   ```
   - Relative positioning - traditional mouse behavior
   - Click in QEMU window to grab mouse
   - Press `Ctrl+Alt+G` to release mouse
   - Best for fullscreen mode

3. **ps2** (most compatible):
   ```json
   "pointer_mode": "ps2"
   ```
   - Legacy PS/2 mouse
   - Uses `Ctrl+Alt+G` to grab/release
   - Most compatible but may have lag

**To quickly test a mode:**
```bash
# Set pointer mode directly
jq --arg mode "usb-mouse" '.pointer_mode = $mode' /opt/retro-mac/qemu-config.json > /tmp/qemu-config.json && mv /tmp/qemu-config.json /opt/retro-mac/qemu-config.json

# Restart QEMU
/opt/retro-mac/start-mac.sh
```

**Try windowed mode first:**
If mouse issues persist in fullscreen, try windowed mode:
```bash
nano /opt/retro-mac/qemu-config.json
# Change "fullscreen": true to "fullscreen": false
```

### Sound not working
Ensure system audio is working:
```bash
aplay -l  # List audio devices
aplay /usr/share/sounds/alsa/Front_Center.wav  # Test sound
```

## Disk Formats

Supported formats for virtual drives:
- `qcow2` - Copy-on-write, supports snapshots (recommended)
- `raw` - Raw disk image, best performance
- `vmdk` - VMware compatible
- `vdi` - VirtualBox compatible

## CPU Options

- `g3` - PowerPC G3 (most compatible)
- `g4` - PowerPC G4 with AltiVec (faster, less compatible)
- `750` - PowerPC 750 (G3 class)
- `7400` - PowerPC 7400 (G4 class, early AltiVec)
- `7410` - PowerPC 7410 (G4 class)
- `7450` - PowerPC 7450 (G4 class)
