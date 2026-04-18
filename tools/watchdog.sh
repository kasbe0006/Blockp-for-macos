#!/bin/bash
set -euo pipefail

APP_PATH="/Applications/BlockpMac.app"
APP_EXEC="$APP_PATH/Contents/MacOS/BlockpMacApp"

if [[ ! -x "$APP_EXEC" ]]; then
  exit 0
fi

if pgrep -f "$APP_EXEC" >/dev/null 2>&1; then
  exit 0
fi

open -a "$APP_PATH"
