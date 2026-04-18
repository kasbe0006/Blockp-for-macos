#!/bin/bash
set -euo pipefail

APP_PATH="/Applications/BlockpMac.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "BlockpMac.app not found in /Applications"
  exit 1
fi

LABEL="com.blockpmac.autostart"
AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$AGENTS_DIR/$LABEL.plist"
mkdir -p "$AGENTS_DIR"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>$APP_PATH</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>

  <key>KeepAlive</key>
  <false/>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "Autostart installed: $LABEL"
echo "Plist: $PLIST_PATH"
