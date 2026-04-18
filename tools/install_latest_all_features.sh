#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_APP="$ROOT_DIR/dist/BlockpMac.app"
APP_EXEC_NAME="BlockpMacApp"
INSTALLED_APP="/Applications/BlockpMac.app"

echo "[1/5] Building latest binaries..."
cd "$ROOT_DIR"
swift build -c debug

echo "[2/5] Running core self-test..."
swift run blockpmac self-test

echo "[3/5] Refreshing dist app bundle..."
mkdir -p "$DIST_APP/Contents/MacOS" "$DIST_APP/Contents/Resources"
cp "$ROOT_DIR/.build/debug/$APP_EXEC_NAME" "$DIST_APP/Contents/MacOS/$APP_EXEC_NAME"
chmod 755 "$DIST_APP/Contents/MacOS/$APP_EXEC_NAME"

if [[ ! -f "$DIST_APP/Contents/Info.plist" ]]; then
  cat > "$DIST_APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>BlockpMacApp</string>
  <key>CFBundleIdentifier</key><string>com.blockpmac.app</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>BlockpMac</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
fi

DIST_SIZE="$(stat -f%z "$DIST_APP/Contents/MacOS/$APP_EXEC_NAME")"
echo "Dist binary size: $DIST_SIZE bytes"

echo "[4/5] Deploying to /Applications + watchdog + MDM checks..."
if sudo -n true >/dev/null 2>&1; then
  sudo "$ROOT_DIR/tools/mdm/deploy_or_repair_blockpmac.sh" "$DIST_APP"
  sudo "$ROOT_DIR/tools/mdm/compliance_check_blockpmac.sh"
else
  echo "Sudo password is required for deployment. Running interactive sudo now..."
  sudo "$ROOT_DIR/tools/mdm/deploy_or_repair_blockpmac.sh" "$DIST_APP"
  sudo "$ROOT_DIR/tools/mdm/compliance_check_blockpmac.sh"
fi

echo "[5/5] Final runtime checks..."
INSTALLED_SIZE="$(stat -f%z "$INSTALLED_APP/Contents/MacOS/$APP_EXEC_NAME")"
echo "Installed binary size: $INSTALLED_SIZE bytes"
pgrep -fl "$APP_EXEC_NAME" || true

echo "Done. Latest BlockpMac is installed with configured enforcement services."
