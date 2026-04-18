#!/bin/bash
set -euo pipefail

APP_EXEC="/Applications/BlockpMac.app/Contents/MacOS/BlockpMacApp"

if [[ ! -x "$APP_EXEC" ]]; then
  echo "App executable missing: $APP_EXEC"
  exit 1
fi

echo "Killing app process (if running)..."
pkill -f "$APP_EXEC" >/dev/null 2>&1 || true

echo "Waiting for watchdog relaunch..."
for i in $(seq 1 20); do
  if pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
    PID="$(pgrep -f "$APP_EXEC" | head -n 1)"
    echo "Relaunch OK: pid=$PID (after ${i}s)"
    exit 0
  fi
  sleep 1
done

echo "Relaunch FAILED after 20s"
exit 1
