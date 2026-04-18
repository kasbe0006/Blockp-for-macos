#!/bin/bash
set -euo pipefail

APP_PATH="/Applications/BlockpMac.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "BlockpMac.app not found in /Applications"
  exit 1
fi

SUPPORT_DIR="$HOME/Library/Application Support/BlockpMac"
WATCHDOG_SCRIPT="$SUPPORT_DIR/watchdog.sh"
LAUNCH_AGENT_PATH="$HOME/Library/LaunchAgents/com.blockpmac.watchdog.plist"

mkdir -p "$SUPPORT_DIR"
mkdir -p "$HOME/Library/LaunchAgents"

cp "$(cd "$(dirname "$0")" && pwd)/watchdog.sh" "$WATCHDOG_SCRIPT"
chmod +x "$WATCHDOG_SCRIPT"

cat > "$LAUNCH_AGENT_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.blockpmac.watchdog</string>

  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$WATCHDOG_SCRIPT</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>StartInterval</key>
  <integer>5</integer>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>$SUPPORT_DIR/watchdog.out.log</string>

  <key>StandardErrorPath</key>
  <string>$SUPPORT_DIR/watchdog.err.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.blockpmac.watchdog" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT_PATH"
launchctl enable "gui/$(id -u)/com.blockpmac.watchdog"
launchctl kickstart -k "gui/$(id -u)/com.blockpmac.watchdog"

echo "Watchdog installed and active: com.blockpmac.watchdog"
echo "Agent: $LAUNCH_AGENT_PATH"
echo "Script: $WATCHDOG_SCRIPT"
