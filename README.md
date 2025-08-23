# Mac OS 9 Retro Emulation System

A complete, single-script solution for setting up a Mac OS 9.2.1 PowerPC emulation environment on Debian Linux with a beautiful web-based control panel.

![Mac OS 9](https://img.shields.io/badge/Mac%20OS-9.2.1-purple?style=for-the-badge)
![PowerPC](https://img.shields.io/badge/PowerPC-G3%2FG4-blue?style=for-the-badge)
![Debian](https://img.shields.io/badge/Debian-13%20Trixie-red?style=for-the-badge)
![QEMU](https://img.shields.io/badge/QEMU-PPC-orange?style=for-the-badge)

## 🎯 Features

### Complete Mac OS 9 Emulation
- **Mac OS 9.2.1** PowerPC emulation via QEMU
- **Multiple CPU options**: G3, G4, PowerPC 750/7400/7410/7450
- **Configurable RAM**: 128MB to 8GB
- **Multiple display resolutions**: 640×480 to 1920×1080
- **Sound support**: ES1370 emulation
- **Network support**: User mode NAT or disabled

### Web Control Panel
- **Authentic Mac OS 9 Interface**: Platinum-style UI with classic window styling
- **Real-time system monitoring**: CPU, memory, disk usage
- **QEMU control**: Start, stop, restart emulator
- **Configuration management**: All settings via web interface
- **Hard drive management**: Create, add, remove virtual drives
- **Pointer control**: USB Tablet, USB Mouse, or PS/2 modes

### Boot Experience
- **Custom Plymouth theme**: Mac boot image during startup
- **GRUB customization**: Mac boot screen
- **Auto-login**: Automatic login and QEMU startup
- **Full-screen emulation**: Boots directly into Mac OS 9

### Advanced Features
- **JSON configuration**: `/opt/retro-mac/qemu-config.json`
- **Idempotent installation**: Safe to run multiple times
- **Self-healing**: Detects and fixes configuration issues
- **Auto-updates**: Updates existing installations with new features

## 📋 Requirements

- **OS**: Debian 13 (Trixie) or compatible
- **Architecture**: x86_64
- **RAM**: Minimum 2GB recommended
- **Disk Space**: 2GB + space for Mac OS 9 ISO (650MB)
- **Network**: Internet connection for initial setup

## 🚀 Quick Start

### One-Command Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/makeRetro.git
cd makeRetro

# Run the setup script as root
sudo ./setup-retro-mac.sh
```

The script will:
1. Install all required packages (Apache, PHP, QEMU, Plymouth, X11, LightDM)
2. Download Mac OS 9.2.1 ISO
3. Configure boot screens and auto-login
4. Set up the web control panel
5. Create systemd service for auto-start

### Post-Installation

After installation completes:
1. **Reboot** to see the custom boot screens
2. System will auto-login and start Mac OS 9
3. Access web control panel at `http://[your-ip-address]`

## 🎮 Usage

### Web Control Panel
Navigate to `http://[your-ip-address]` to access the control panel.

**Features:**
- **Control Tab**: Start/stop QEMU, view system status
- **Configuration Tab**: Adjust RAM, CPU, display settings
- **Drives Tab**: Manage virtual hard drives
- **Advanced Tab**: Network, pointer control, custom arguments

### Command Line Control

```bash
# Start the emulator
sudo systemctl start qemu-mac

# Stop the emulator
sudo systemctl stop qemu-mac

# Check status
sudo systemctl status qemu-mac

# View logs
sudo journalctl -u qemu-mac -f

# Edit configuration
nano /opt/retro-mac/qemu-config.json
```

## ⚙️ Configuration

### Default Configuration
Configuration stored in `/opt/retro-mac/qemu-config.json`:

```json
{
    "ram": "512",
    "cpu": "g4",
    "machine": "mac99,via=pmu",
    "resolution": "1024x768x32",
    "fullscreen": true,
    "boot_device": "d",
    "cdrom": "/opt/retro-mac/macos_921_ppc.iso",
    "hard_drives": [],
    "network": "user",
    "sound": true,
    "pointer_mode": "usb-tablet",
    "grab_on_click": true,
    "custom_args": ""
}
```

### Pointer Modes
- **usb-tablet**: Seamless mouse integration (default)
- **usb-mouse**: Traditional grab/ungrab mode
- **ps2**: Legacy PS/2 mouse

### Creating Hard Drives

Via web interface or command line:
```bash
sudo qemu-img create -f qcow2 /opt/retro-mac/drives/macos_hd.qcow2 2G
```

## 📁 File Locations

- **Setup Script**: `/home/retro/makeRetro/setup-retro-mac.sh`
- **Configuration**: `/opt/retro-mac/qemu-config.json`
- **Mac OS 9 ISO**: `/opt/retro-mac/macos_921_ppc.iso`
- **Virtual Drives**: `/opt/retro-mac/drives/`
- **Startup Script**: `/opt/retro-mac/start-mac.sh`
- **Web Interface**: `/var/www/html/index.php`
- **Service File**: `/etc/systemd/system/qemu-mac.service`

## 🔧 Troubleshooting

### Auto-login not working
```bash
sudo ./setup-retro-mac.sh  # Script will detect and fix issues
# Or manually restart LightDM
sudo systemctl restart lightdm
```

### QEMU won't start
```bash
# Check logs
sudo journalctl -u qemu-mac -n 50

# Check configuration
cat /opt/retro-mac/qemu-config.json

# Test manually
DISPLAY=:0 sudo -u retro /opt/retro-mac/start-mac.sh
```

### Web interface not accessible
```bash
# Check Apache status
sudo systemctl status apache2

# Restart Apache
sudo systemctl restart apache2
```

### Plymouth theme not showing
```bash
# Rebuild initramfs
sudo update-initramfs -u

# Check theme is set
sudo plymouth-set-default-theme
```

## 🎨 Customization

### Change Boot Image
Replace `/opt/retro-mac/images/macTest.png` and re-run setup script.

### Modify Web Interface Style
Edit `/var/www/html/index.php` - uses inline CSS with Mac OS 9 Platinum styling.

### Add Custom QEMU Arguments
Use the web interface Advanced tab or edit `custom_args` in the JSON config.

## 📚 Technical Details

### Components Used
- **QEMU**: PowerPC system emulation
- **Apache2 + PHP**: Web control panel
- **Plymouth**: Boot splash screen
- **GRUB**: Boot loader customization
- **LightDM + Openbox**: Minimal X11 environment
- **systemd**: Service management

### Script Features
- **1762 lines** of robust, self-healing bash code
- **Idempotent**: Can be run multiple times safely
- **Smart detection**: Identifies and fixes existing installations
- **User detection**: Automatically uses non-root user for security
- **Validation**: Checks all configurations and fixes issues

## 🤝 Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

### Development Setup
```bash
git clone https://github.com/yourusername/makeRetro.git
cd makeRetro
# Make your changes to setup-retro-mac.sh
sudo ./setup-retro-mac.sh  # Test your changes
```

## 📝 License

This project is open source and available under the [MIT License](LICENSE).

## 🙏 Acknowledgments

- QEMU team for PowerPC emulation
- Classic Mac OS community
- Debian project

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check the [troubleshooting section](#-troubleshooting)
- Review the [todolist.md](todolist.md) for development history

---

**Made with ❤️ for the Retro Computing Community**

*Experience the nostalgia of Mac OS 9 on modern hardware!*