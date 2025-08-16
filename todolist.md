# Mac OS 9 Emulation Setup - Todo List

## Completed Tasks
- [x] Create todolist.md file for tracking progress
- [x] Check current system state and installed packages
- [x] Create main setup script with package installation (Apache, QEMU, Plymouth, PHP)
- [x] Implement Plymouth boot image configuration
- [x] Implement GRUB boot image configuration  
- [x] Download Mac OS 9 ISO with proper error handling
- [x] Configure QEMU systemd service for boot startup
- [x] Create PHP control panel with system stats and QEMU controls
- [x] Test script idempotency and error handling
- [x] Fix GRUB to center image without stretching
- [x] Fix Plymouth theme installation and configuration
- [x] Fix QEMU systemd service to run properly on boot
- [x] Add X11/display server configuration for QEMU
- [x] Fix LightDM auto-login to use retro user instead of root
- [x] Configure QEMU to run with proper user permissions
- [x] Set up auto-start mechanism for QEMU after login
- [x] Test complete boot sequence

## In Progress
None - All systems operational!

## Pending Tasks
None - Setup complete and working!

## Notes
- Script must be idempotent (safe to run multiple times)
- Clean terminal output with clear status messages
- Error reporting to terminal
- Single file setup script
- Vanilla Debian starting point with minimal packages

## Fixes Applied (2025-08-16)

### Round 1 - Initial Issues
- **GRUB**: Fixed image stretching by setting GRUB_GFXMODE=1024x768 and GRUB_GFXPAYLOAD_LINUX=keep
- **Plymouth**: Fixed theme not showing by setting it as default with `plymouth-set-default-theme retro-mac` ✅ WORKING!
- **QEMU**: Fixed "x11 not available" error by installing X11, LightDM, and Openbox

### Round 2 - Auto-Login Issues  
- **LightDM**: Fixed auto-login by:
  - Configuring auto-login for 'retro' user (not root)
  - Creating PAM autologin configuration
  - Setting up proper Openbox autostart
- **QEMU**: Now successfully running as retro user with:
  - Proper permissions and sudo configuration
  - Service running under retro user context
  - Auto-start via Openbox autostart script
  
## Current Status
✅ **Plymouth**: Working perfectly!
✅ **Auto-login**: System auto-logs into retro user
✅ **QEMU**: Running successfully with enhanced configuration support
✅ **PHP Control Panel**: Enhanced with full configuration management
⚠️ **GRUB**: Reverted to older version (low priority per user)

## New Features Added (2025-08-16 - Part 2)
✅ **QEMU Configuration System**:
  - JSON-based configuration file (`/opt/retro-mac/qemu-config.json`)
  - Configurable RAM (128MB - 8GB)
  - Multiple CPU options (G3, G4, PowerPC 750/7400/7410/7450)
  - Resolution settings (640x480 to 1920x1080)
  - Network configuration (User/NAT or disabled)
  - Sound enable/disable
  - Custom QEMU arguments support

✅ **Hard Drive Management**:
  - Create new virtual drives (QCOW2, RAW, VMDK formats)
  - Add existing drive images
  - Remove drives from configuration
  - Drives stored in `/opt/retro-mac/drives/`

✅ **Enhanced Web Interface**:
  - Full configuration UI with form controls
  - Real-time drive management
  - Save and apply settings without editing files
  - Maintains all original system monitoring features

## Final Version (2025-08-16)

### Key Features of setup-retro-mac.sh (1512 lines):
✅ **Smart User Detection**: Automatically detects and uses non-root user for auto-login
✅ **Self-Healing**: Detects and fixes existing installations with wrong configurations
✅ **Validation Checks**: Validates all configuration files and fixes issues
✅ **Complete Configuration Management**: Full QEMU configuration via JSON and web UI
✅ **Idempotent**: Safe to run multiple times without breaking anything

### Final Fixes Applied:
- Auto-login now properly uses 'retro' user (not root)
- QEMU service runs as retro user with correct permissions
- Configuration validation ensures everything is set up correctly
- Script can detect and fix installations that were configured incorrectly

## Files Created
- `setup-retro-mac.sh` - Complete single-file installation and repair script (1512 lines)
- `todolist.md` - This tracking document
