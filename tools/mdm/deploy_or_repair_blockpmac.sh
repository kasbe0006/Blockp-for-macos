#!/bin/bash
set -euo pipefail

APP_NAME="BlockpMac.app"
APP_DST="/Applications/$APP_NAME"
SRC_APP="${1:-}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root (MDM script context is usually root)."
  exit 1
fi

if [[ -z "$SRC_APP" ]]; then
  if [[ -d "$ROOT_DIR/dist/$APP_NAME" ]]; then
    SRC_APP="$ROOT_DIR/dist/$APP_NAME"
  else
    echo "Usage: $0 /path/to/$APP_NAME"
    echo "Or place app at $ROOT_DIR/dist/$APP_NAME"
    exit 1
  fi
fi

if [[ ! -d "$SRC_APP" ]]; then
  echo "Source app not found: $SRC_APP"
  exit 1
fi

echo "Installing $APP_NAME to /Applications..."
rm -rf "$APP_DST"
cp -R "$SRC_APP" "$APP_DST"

chown -R root:wheel "$APP_DST"
find "$APP_DST" -type d -exec chmod 755 {} \;
find "$APP_DST" -type f -exec chmod 644 {} \;
chmod 755 "$APP_DST/Contents/MacOS/BlockpMacApp"

echo "Installing login autostart (per-user, if script context allows)..."
if [[ -x "$ROOT_DIR/install_autostart.sh" ]]; then
  sudo -u "$(stat -f%Su /dev/console)" "$ROOT_DIR/install_autostart.sh" >/dev/null 2>&1 || true
fi

echo "Installing root watchdog..."
if [[ -x "$ROOT_DIR/install_watchdog_root.sh" ]]; then
  "$ROOT_DIR/install_watchdog_root.sh"
fi

echo "Kicking app launch..."
/usr/bin/open -a "$APP_DST" >/dev/null 2>&1 || true

echo "Deployment complete."
