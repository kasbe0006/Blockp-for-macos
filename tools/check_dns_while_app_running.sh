#!/bin/bash
set -euo pipefail

APP_EXEC="/Applications/BlockpMac.app/Contents/MacOS/BlockpMacApp"

if ! pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
  echo "BlockpMac app is not running"
  exit 1
fi

echo "App is running. DNS per network service:"
while IFS= read -r service; do
  [[ -z "$service" ]] && continue
  [[ "$service" == \** ]] && continue
  echo "--- $service"
  /usr/sbin/networksetup -getdnsservers "$service" || true
done < <(/usr/sbin/networksetup -listallnetworkservices | tail -n +2)
