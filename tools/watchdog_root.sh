#!/bin/bash
set -euo pipefail

APP_PATH="/Applications/BlockpMac.app"
APP_EXEC="$APP_PATH/Contents/MacOS/BlockpMacApp"
CONFIG_PATH="/Library/PrivilegedHelperTools/BlockpMac/dns_provider.conf"
BACKUP_DIR="/Library/PrivilegedHelperTools/BlockpMac/dns-backups"
EVENT_LOG="/Library/PrivilegedHelperTools/BlockpMac/events.log"
DEFAULT_DNS_SERVERS=("185.228.168.168" "185.228.169.168")
DNS_SERVERS=("${DEFAULT_DNS_SERVERS[@]}")

if [[ -f "$CONFIG_PATH" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_PATH"
  if [[ -n "${DNS_SERVERS_STRING:-}" ]]; then
    read -r -a DNS_SERVERS <<< "$DNS_SERVERS_STRING"
  fi
fi

if [[ ! -x "$APP_EXEC" ]]; then
  exit 0
fi

app_is_running() {
  pgrep -f "$APP_EXEC" >/dev/null 2>&1
}

log_event() {
  local severity="$1"
  local source="$2"
  local message="$3"
  mkdir -p "$(dirname "$EVENT_LOG")"
  printf '%s|%s|%s|%s\n' "$(/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")" "$severity" "$source" "$message" >> "$EVENT_LOG"
}

CONSOLE_USER="$(stat -f%Su /dev/console)"
if [[ -z "$CONSOLE_USER" || "$CONSOLE_USER" == "root" || "$CONSOLE_USER" == "loginwindow" ]]; then
  exit 0
fi

USER_HOME="$(dscl . -read "/Users/$CONSOLE_USER" NFSHomeDirectory 2>/dev/null | awk '{print $2}')"
STATE_FILE="$USER_HOME/Library/Application Support/BlockpMac/state.json"

session_is_active() {
  [[ -f "$STATE_FILE" ]] || return 1

  /usr/bin/python3 - "$STATE_FILE" <<'PY'
import json, sys, datetime
from pathlib import Path

state_path = Path(sys.argv[1])
try:
  data = json.loads(state_path.read_text())
except Exception:
  raise SystemExit(1)

session = data.get("session", {})
if not session.get("isActive"):
  raise SystemExit(1)

ends_at = session.get("endsAt")
if not ends_at:
  raise SystemExit(1)

if ends_at.endswith("Z"):
  ends_at = ends_at[:-1] + "+00:00"

try:
  end_dt = datetime.datetime.fromisoformat(ends_at)
except Exception:
  raise SystemExit(1)

now = datetime.datetime.now(datetime.timezone.utc)
if end_dt.tzinfo is None:
  end_dt = end_dt.replace(tzinfo=datetime.timezone.utc)

raise SystemExit(0 if now < end_dt else 1)
PY
}

service_key() {
  printf '%s' "$1" | tr '/ ' '__' | tr -cd 'A-Za-z0-9._-'
}

backup_dns() {
  local service="$1"
  local key file current
  key="$(service_key "$service")"
  file="$BACKUP_DIR/$key.dns"
  [[ -f "$file" ]] && return 0

  mkdir -p "$BACKUP_DIR"
  current="$(${NETWORKSETUP:-/usr/sbin/networksetup} -getdnsservers "$service" 2>/dev/null || true)"
  if [[ -z "$current" || "$current" == *"There aren't any DNS Servers set on"* ]]; then
    printf 'Empty\n' > "$file"
  else
    printf '%s\n' "$current" > "$file"
  fi
}

apply_family_dns() {
  local service="$1"
  backup_dns "$service"
  /usr/sbin/networksetup -setdnsservers "$service" "${DNS_SERVERS[@]}" >/dev/null 2>&1 || true
}

is_dns_tampered() {
  local service="$1"
  local output dns_line
  local current_dns=()
  output="$(/usr/sbin/networksetup -getdnsservers "$service" 2>/dev/null || true)"

  if [[ -z "$output" || "$output" == *"There aren't any DNS Servers set on"* ]]; then
    return 0
  fi

  while IFS= read -r dns_line; do
    [[ -z "$dns_line" ]] && continue
    current_dns+=("$dns_line")
  done <<< "$output"

  if [[ "${#current_dns[@]}" -ne "${#DNS_SERVERS[@]}" ]]; then
    return 0
  fi

  for i in "${!DNS_SERVERS[@]}"; do
    if [[ "${current_dns[$i]}" != "${DNS_SERVERS[$i]}" ]]; then
      return 0
    fi
  done

  return 1
}

restore_dns() {
  local service="$1"
  local key file
  key="$(service_key "$service")"
  file="$BACKUP_DIR/$key.dns"
  [[ -f "$file" ]] || return 0

  if [[ "$(head -n 1 "$file")" == "Empty" ]]; then
    /usr/sbin/networksetup -setdnsservers "$service" Empty >/dev/null 2>&1 || true
  else
    dns_servers=()
    while IFS= read -r dns_line; do
      [[ -z "$dns_line" ]] && continue
      dns_servers+=("$dns_line")
    done < "$file"
    if [[ "${#dns_servers[@]}" -gt 0 ]]; then
      /usr/sbin/networksetup -setdnsservers "$service" "${dns_servers[@]}" >/dev/null 2>&1 || true
    fi
  fi
}

SESSION_ACTIVE=false
if session_is_active; then
  SESSION_ACTIVE=true
fi

APP_RUNNING=false
if app_is_running; then
  APP_RUNNING=true
fi

while IFS= read -r service; do
  [[ -z "$service" ]] && continue
  [[ "$service" == \** ]] && continue

  if $SESSION_ACTIVE; then
    if is_dns_tampered "$service"; then
      log_event "warning" "watchdog-root" "DNS tamper detected on service '$service'. Reapplying family DNS."
    fi
    apply_family_dns "$service"
  else
    restore_dns "$service"
  fi
done < <(/usr/sbin/networksetup -listallnetworkservices 2>/dev/null | tail -n +2)

if ! $APP_RUNNING; then
  CONSOLE_UID="$(id -u "$CONSOLE_USER")"
  log_event "critical" "watchdog-root" "App process not running. Relaunch requested."
  /bin/launchctl asuser "$CONSOLE_UID" /usr/bin/open -g -a "$APP_PATH" >/dev/null 2>&1 || true
fi
