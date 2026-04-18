#!/bin/bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root: sudo ./tools/uninstall_watchdog_root.sh"
  exit 1
fi

PLIST_PATH="/Library/LaunchDaemons/com.blockpmac.watchdog.root.plist"
WATCHDOG_SCRIPT="/Library/PrivilegedHelperTools/BlockpMac/watchdog_root.sh"
DNS_CONFIG_PATH="/Library/PrivilegedHelperTools/BlockpMac/dns_provider.conf"
EVENT_LOG_PATH="/Library/PrivilegedHelperTools/BlockpMac/events.log"
LEGACY_WATCHDOG_SCRIPT="/Library/Application Support/BlockpMac/watchdog_root.sh"

launchctl bootout system/com.blockpmac.watchdog.root >/dev/null 2>&1 || true
launchctl disable system/com.blockpmac.watchdog.root >/dev/null 2>&1 || true

rm -f "$PLIST_PATH"
rm -f "$WATCHDOG_SCRIPT"
rm -f "$DNS_CONFIG_PATH"
rm -f "$EVENT_LOG_PATH"
rm -f "$LEGACY_WATCHDOG_SCRIPT"

echo "Root watchdog removed: com.blockpmac.watchdog.root"
