# AGENTS.md

This file provides guidance for agentic coding assistants working on the makeRetro repository.

## Project Overview

makeRetro is a bash-based setup script that configures a Debian Linux system for Mac OS 9 PowerPC emulation using QEMU. The main script (`setup-retro-mac.sh`) handles system configuration, installs dependencies (Apache, PHP, QEMU, Plymouth, X11), and creates a web-based control panel styled after Mac OS 9's Platinum interface.

## Build/Lint/Test Commands

### Running the Main Script
```bash
sudo ./setup-retro-mac.sh
```

### Testing (Manual)
Test idempotency by running multiple times: `sudo ./setup-retro-mac.sh`
Verify QEMU starts: `sudo systemctl start qemu-mac && sudo journalctl -u qemu-mac -f`
Check web interface: `curl http://localhost` or access via browser at `http://[IP]`

### Shell Linting (Optional)
```bash
shellcheck setup-retro-mac.sh
shellcheck push-to-github.sh
```

### System Service Commands
```bash
sudo systemctl start/stop/restart qemu-mac   # Control emulator
sudo systemctl status qemu-mac                # Check status
sudo journalctl -u qemu-mac -f               # View logs
```

## Code Style Guidelines

### Bash Scripts
Start with `#!/bin/bash` and `set -e` for strict error handling. Define color constants (RED, GREEN, YELLOW, BLUE, NC) at top. Use helper functions: `print_status()`, `print_success()`, `print_error()`, `print_warning()`.

**Functions:** Snake_case naming (`check_root()`, `is_package_installed()`, `download_if_needed()`). Define before `main()`. Keep functions focused.

**Variables:** UPPERCASE for constants/exported variables (`AUTO_USER`, `CONFIG_FILE`, `MAX_WAIT`). Always quote variables: `"$AUTO_USER"`. Use defaults: `${VAR:-default}`.

**Comments:** Single-line `#` comments only. No multi-line comments.

**Conditionals:** Use `[ ]` not `[[ ]]`. Check with `-z` (empty), `-n` (non-empty), `[ -f "$file" ]`, `[ -d "$dir" ]`, `[ -x "$file" ]`.

**Command Execution:** Use `2>/dev/null` to suppress expected errors. Use `|| true` for commands that may fail. Capture output with `$(command)`.

**Strings:** Use heredocs for multi-line: `cat > file << 'EOF' ... EOF`. Quote variables in strings.

**Error Handling:** Check return values: `if [ $? -eq 0 ]; then`. Use `return 1` for errors. Use `set -e` at script start.

**Idempotency:** Always check before creating: `if [ ! -f "$dest" ]; then`. Conditional installation: `apt-get install -y $pkg || print_warning "Failed"`

### PHP (Web Control Panel)
Use `<?php` (no closing tag). Functions in snake_case (`load_config()`, `save_config()`). Associative arrays with `'key' => 'value'`.

**Security:** Always escape output with `htmlspecialchars()`. Validate input with regex: `preg_replace('/[^a-zA-Z0-9_-]/', '', $input)`.

**Forms:** Check `$_SERVER['REQUEST_METHOD'] === 'POST'` and `isset($_POST['key'])`. Use null coalescing: `$_POST['value'] ?? 'default'`.

**File Operations:** Check with `file_exists()`. Use `file_get_contents()`/`file_put_contents()`. Set `chmod($file, 0644)`.

**Shell Commands:** Use `exec('systemctl start qemu-mac 2>&1', $output, $return)`. Check `if ($return === 0)`.

### HTML/CSS
HTML5 doctype. Self-closing void tags: `<img />`, `<input />`. 4-space indentation. CSS in `<style>` block. Class names kebab-case: `.window-titlebar`. Pixel measurements. Flexbox for layout. JavaScript in camelCase: `switchTab(tabName)`.

## Important Patterns

**Idempotent Operations:** Always check before creating: `if [ ! -f "$dest" ]; then`

**Service Management:**
```bash
is_service_running() { systemctl is-active --quiet "$1"; }
if is_service_running qemu-mac.service; then systemctl restart qemu-mac.service; fi
```

**JSON Handling (jq):**
```bash
VALUE=$(jq -r '.key' "$CONFIG_FILE")
jq '. + {"new_key": "value"}' config.json > config-new.json && mv config-new.json config.json
```

**User Detection:**
```bash
AUTO_USER=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' | head -1)
if id retro >/dev/null 2>&1; then USER="retro"; fi
```

**Package Management:** `apt-get update -qq`, `apt-get install -y $package`, `dpkg -l "$1" | grep -q "^ii"`

**File Operations:** `mkdir -p $dir`, `chown -R $user:$group $path`, `chmod 644 $file`, `chmod 755 $dir`

**Error Handling:** `if [ $? -eq 0 ]; then ...; else ...; return 1; fi`. Use `|| true` for expected failures.

**Validation:** `if jq . "$config_file" >/dev/null 2>&1; then`. Check command: `if command -v jq >/dev/null 2>&1; then`

## Code Organization

**Main Script Structure:** 1) Shebang and `set -e`, 2) Color constants, 3) Helper functions, 4) Validation functions, 5) Core functions, 6) `main()` function, 7) `main "$@"`

**Main Files:** `setup-retro-mac.sh` (1762 lines), `push-to-github.sh`, `README.md`, `todolist.md`

**Installation Artifacts:** `/opt/retro-mac/qemu-config.json`, `/opt/retro-mac/start-mac.sh`, `/opt/retro-mac/macos_921_ppc.iso`, `/var/www/html/index.php`, `/etc/systemd/system/qemu-mac.service`, `/etc/lightdm/lightdm.conf`

## Testing Notes

- Manual testing on fresh Debian 13 installation
- Test idempotency by running multiple times
- Verify all services running after installation
- Check web interface accessibility
- Test QEMU start/stop via web interface
- Verify Plymouth and GRUB boot screens

## Security Considerations

- Never log passwords or sensitive data
- Use `2>/dev/null` to suppress appropriate errors
- Validate user input in PHP with `htmlspecialchars()`
- Set proper file permissions (644 for files, 755 for directories)
- Use `|| true` after commands that may fail
- Don't expose system internals in web interface
