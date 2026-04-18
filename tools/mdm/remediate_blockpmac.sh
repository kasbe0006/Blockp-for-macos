#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_TOOLS_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_SRC="$ROOT_TOOLS_DIR/../dist/BlockpMac.app"

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root (MDM remediation context)."
  exit 1
fi

if [[ ! -d "$APP_SRC" ]]; then
  echo "Packaged app not found at $APP_SRC"
  echo "Build/package first, or pass source path into deploy script manually."
  exit 1
fi

"$SCRIPT_DIR/deploy_or_repair_blockpmac.sh" "$APP_SRC"
"$SCRIPT_DIR/compliance_check_blockpmac.sh"
