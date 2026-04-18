# BlockpMac

A macOS-focused foundation inspired by BlockP, with a strong local core + menu bar UI.

**Complete solution**: core engine, CLI, and SwiftUI menu bar app.

## Features

- ✅ Rule management (domain, exactHost, keyword)
- ✅ Session lifecycle (start/stop with duration)
- ✅ Persistent state (JSON in `~/Library/Application Support/BlockpMac/`)
- ✅ Session-aware enforcement (blocks only when session active)
- ✅ Allowlist mode (only approved hosts allowed during session)
- ✅ SwiftUI menu bar app with real-time UI
- ✅ CLI for automation/scripting
- ✅ Security/tamper event log (core + root watchdog)
- ⏳ System-level enforcement (next phase)

## Requirements

- macOS 13+
- Xcode Command Line Tools
- Swift 5.9+

## Quick start

### 1) Test the core

```bash
cd /Users/prathameshkasbe/blockp
swift run blockpmac self-test
```

Expected: `SELF-TEST PASSED`

### 2) Launch the menu bar app

```bash
swift run BlockpMacApp
```

Look for the **BlockpMac** icon in the menu bar (green circle when session active, gray when idle).

## Menu bar app usage

Click the menu bar icon to open the popup:

### Session Tab
- Start a focus session (1–60 minutes)
- Real-time countdown timer
- Stop session button

### Rules Tab
- View all loaded rules
- Add new rules by type (domain, exactHost, keyword)
- Delete rules
- Import from JSON file (via CLI)

### Status Tab
- Session active status
- Number of rules
- Strict mode toggle
- Last updated timestamp
- Error messages

## CLI for automation

The `blockpmac` command-line tool supports:

```bash
# Test core
swift run blockpmac self-test

# Import rules from JSON
swift run blockpmac --state-path ./state.json import-rules --rules ./rules.sample.json

# Session control
swift run blockpmac --state-path ./state.json session-start --minutes 30
swift run blockpmac --state-path ./state.json session-stop

# Enforcement mode
swift run blockpmac --state-path ./state.json mode-set --mode blocklist
swift run blockpmac --state-path ./state.json mode-set --mode allowlist

# Check if URL/host is blocked (when session active)
swift run blockpmac --state-path ./state.json check --url https://instagram.com
swift run blockpmac --state-path ./state.json check --host example.com

# Security/tamper events
swift run blockpmac --state-path ./state.json events --limit 20

# Rule management
swift run blockpmac --state-path ./state.json rule-add --type domain --value reddit.com
swift run blockpmac --state-path ./state.json rule-list
swift run blockpmac --state-path ./state.json rule-remove --type domain --value reddit.com

# Status
swift run blockpmac --state-path ./state.json status
```

Exit codes:
- `0`: allowed
- `2`: blocked

## Rules format

### JSON (for import)

```json
{
  "rules": [
    { "type": "domain", "value": "instagram.com" },
    { "type": "exactHost", "value": "news.ycombinator.com" },
    { "type": "keyword", "value": "casino" }
  ]
}
```

### Rule types

- **domain**: blocks domain and all subdomains (e.g., `instagram.com` blocks `www.instagram.com`)
- **exactHost**: blocks only exact host match
- **keyword**: blocks if host contains keyword (case-insensitive substring)

## Architecture

### BlockpMacCore (library)

- `Models.swift`: rule types, block rules, focus sessions
- `BlockingEngine.swift`: pure matching logic
- `CoreState.swift`: app state, enforcement decisions
- `StateStore.swift`: JSON persistence
- `RuleStore.swift`: JSON rule loading
- `CoreManager.swift`: high-level orchestration API

### blockpmac (CLI executable)

- Command-line interface for all core operations
- Self-test harness with comprehensive assertions
- Legacy mode for backward compatibility

### BlockpMacApp (macOS app)

- `BlockpMacApp.swift`: menu bar app entry point
- `AppStateModel.swift`: SwiftUI state management with reactive updates
- `ContentView.swift`: tab-based UI (Session, Rules, Status)

## Demo walkthrough

```bash
cd /Users/prathameshkasbe/blockp

# Clean up and start fresh
rm -f ./demo-state.json

# Import sample rules
swift run blockpmac --state-path ./demo-state.json import-rules --rules ./rules.sample.json

# Start a 1-minute session
swift run blockpmac --state-path ./demo-state.json session-start --minutes 1

# Check that instagram.com is blocked (session active)
swift run blockpmac --state-path ./demo-state.json check --url https://instagram.com/reels
# Output: BLOCKED reason=activeSessionRuleMatch matched=domain:instagram.com
# Exit code: 2

# Check that example.com is allowed (no rule match)
swift run blockpmac --state-path ./demo-state.json check --host example.com
# Output: ALLOWED reason=noRuleMatch
# Exit code: 0

# Stop session
swift run blockpmac --state-path ./demo-state.json session-stop

# Verify session-aware behavior (now no blocking)
swift run blockpmac --state-path ./demo-state.json check --host instagram.com
# Output: ALLOWED reason=noActiveSession
# Exit code: 0

# Check status
swift run blockpmac --state-path ./demo-state.json status
# Output:
#   session_active=false
#   rules_count=4
#   enforcement_mode=blocklist
```

## Build and run

```bash
cd /Users/prathameshkasbe/blockp

# Build everything
swift build -c debug

# Run CLI tests
swift run blockpmac self-test

# Launch menu bar app
swift run BlockpMacApp

# Run CLI commands
swift run blockpmac --help
```

## Known limitations

- **No system-level enforcement yet**: App doesn't hook into DNS/network or Safari to actually block traffic. Currently validates decisions for use in your own integrations.
- **macOS only**: Not iOS/iPadOS compatible.
- **No passcode**: Strict mode exists in state model but UI doesn't enforce it yet.
- **No cloud sync**: State is local to macOS.

## Next steps

1. **System enforcement**: Integrate with Safari Content Blocker, DNS proxy, or parental controls.
2. **Passcode protection**: Lock strict mode changes behind password.
3. **Keyboard shortcuts**: Global hotkey to quick-toggle session.
4. **Custom appearance**: Menu bar icon customization, dark/light theme.
5. **Cloud sync**: iCloud sync of rules and sessions.
6. **Browser extension**: Deep integration with Safari extension API.

## Contributing

Build on top of `CoreManager` API for new features. Core state model is fully tested via `blockpmac self-test`.

---

**Made with SwiftUI + SwiftPM.** Inspired by BlockP.
# Blockp-for-macos
# Blockp-for-Mac
