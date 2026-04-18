#!/bin/bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: sudo ./tools/install_watchdog_root.sh"
  exit 1
fi

APP_PATH="/Applications/BlockpMac.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "BlockpMac.app not found in /Applications"
  exit 1
fi

APP_EXEC="$APP_PATH/Contents/MacOS/BlockpMacApp"
if [[ ! -x "$APP_EXEC" ]]; then
  echo "BlockpMac executable not found at $APP_EXEC"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPPORT_DIR="/Library/PrivilegedHelperTools/BlockpMac"
WATCHDOG_SCRIPT="$SUPPORT_DIR/watchdog_root.sh"
DNS_CONFIG_PATH="$SUPPORT_DIR/dns_provider.conf"
EVENT_LOG_PATH="$SUPPORT_DIR/events.log"
PLIST_PATH="/Library/LaunchDaemons/com.blockpmac.watchdog.root.plist"

mkdir -p "$SUPPORT_DIR"
cp "$SCRIPT_DIR/watchdog_root.sh" "$WATCHDOG_SCRIPT"
chown root:wheel "$WATCHDOG_SCRIPT"
chmod 755 "$WATCHDOG_SCRIPT"

if [[ ! -f "$DNS_CONFIG_PATH" ]]; then
  cat > "$DNS_CONFIG_PATH" <<EOF
# BlockpMac DNS config
# Edit this file as root if you want another family DNS provider.
# Examples:
# Cloudflare Family: DNS_SERVERS_STRING="1.1.1.3 1.0.0.3"
# CleanBrowsing Family: DNS_SERVERS_STRING="185.228.168.168 185.228.169.168"
DNS_SERVERS_STRING="185.228.168.168 185.228.169.168"
EOF
fi
chown root:wheel "$DNS_CONFIG_PATH"
chmod 644 "$DNS_CONFIG_PATH"

touch "$EVENT_LOG_PATH"
chown root:wheel "$EVENT_LOG_PATH"
chmod 644 "$EVENT_LOG_PATH"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.blockpmac.watchdog.root</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$WATCHDOG_SCRIPT</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>2</integer>

  <key>ThrottleInterval</key>
  <integer>2</integer>

  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF

chown root:wheel "$PLIST_PATH"
chmod 644 "$PLIST_PATH"

launchctl bootout system/com.blockpmac.watchdog.root >/dev/null 2>&1 || true

if launchctl bootstrap system "$PLIST_PATH" >/dev/null 2>&1; then
  launchctl enable system/com.blockpmac.watchdog.root >/dev/null 2>&1 || true
  launchctl kickstart -k system/com.blockpmac.watchdog.root >/dev/null 2>&1 || true
else
  launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
  launchctl load -w "$PLIST_PATH"
fi

CONSOLE_USER="$(stat -f%Su /dev/console)"
if [[ -n "$CONSOLE_USER" && "$CONSOLE_USER" != "root" && "$CONSOLE_USER" != "loginwindow" ]]; then
  CONSOLE_UID="$(id -u "$CONSOLE_USER")"
  /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/open -a "$APP_PATH" >/dev/null 2>&1 || true
fi

echo "Root watchdog installed and active: com.blockpmac.watchdog.root"
echo "Daemon: $PLIST_PATH"
echo "Script: $WATCHDOG_SCRIPT"
