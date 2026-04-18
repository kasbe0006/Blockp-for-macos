#!/bin/bash
set -euo pipefail

APP_EXEC="/Applications/BlockpMac.app/Contents/MacOS/BlockpMacApp"
ROOT_WATCHDOG_LABEL="com.blockpmac.watchdog.root"

status_ok=true

check() {
  local label="$1"
  local cmd="$2"
  if eval "$cmd"; then
    echo "PASS: $label"
  else
    echo "FAIL: $label"
    status_ok=false
  fi
}

check "App executable exists" "[[ -x '$APP_EXEC' ]]"
check "App owned by root" "[[ \"$(stat -f %Su /Applications/BlockpMac.app 2>/dev/null || true)\" == 'root' ]]"
check "Root watchdog loaded" "launchctl print system/$ROOT_WATCHDOG_LABEL >/dev/null 2>&1"
check "App process running" "pgrep -f '$APP_EXEC' >/dev/null 2>&1"

if $status_ok; then
  echo "Overall: COMPLIANT"
  exit 0
else
  echo "Overall: NON-COMPLIANT"
  exit 1
fi
