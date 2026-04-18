import Foundation
import BlockpMacCore

struct CLIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

@main
struct BlockpMacCLI {
    static func main() {
        do {
            try run()
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            printUsage()
            exit(1)
        }
    }

    static func run() throws {
        var args = Array(CommandLine.arguments.dropFirst())
        if args.isEmpty || args.contains("--help") {
            printUsage()
            return
        }

        let statePath = extractFlagValue("--state-path", in: &args)
        let manager = try makeManager(statePath: statePath)

        let command = args.removeFirst()

        switch command {
        case "self-test", "--self-test":
            try runSelfTest()
        case "status":
            try runStatus(manager: manager)
        case "mode-set":
            try runModeSet(manager: manager, args: args)
        case "events":
            try runEvents(manager: manager, args: args)
        case "session-start":
            try runSessionStart(manager: manager, args: args)
        case "session-stop":
            try runSessionStop(manager: manager)
        case "rule-add":
            try runRuleAdd(manager: manager, args: args)
        case "rule-remove":
            try runRuleRemove(manager: manager, args: args)
        case "rule-list":
            try runRuleList(manager: manager)
        case "import-rules":
            try runImportRules(manager: manager, args: args)
        case "check":
            try runCheck(manager: manager, args: args)
        case "check-legacy":
            try runLegacyCheck(args: args)
        default:
            throw CLIError(message: "Unknown command: \(command)")
        }
    }

    static func makeManager(statePath: String?) throws -> CoreManager {
        let store: StateStore
        if let statePath {
            store = StateStore(stateFilePath: statePath)
        } else {
            store = try StateStore.defaultStore()
        }
        return CoreManager(store: store)
    }

    static func runStatus(manager: CoreManager) throws {
        let state = try manager.getState()
        print("session_active=\(state.session.isCurrentlyActive())")
        print("rules_count=\(state.rules.count)")
        print("enforcement_mode=\(state.policy.enforcementMode.rawValue)")
        if let endsAt = state.session.endsAt {
            print("session_ends_at=\(isoFormatter.string(from: endsAt))")
        }
    }

    static func runModeSet(manager: CoreManager, args: [String]) throws {
        var mutable = args
        guard let modeText = extractFlagValue("--mode", in: &mutable),
              let mode = EnforcementMode(rawValue: modeText) else {
            throw CLIError(message: "Missing/invalid --mode <blocklist|allowlist>")
        }
        let state = try manager.setEnforcementMode(mode)
        print("MODE_SET \(state.policy.enforcementMode.rawValue)")
    }

    static func runEvents(manager: CoreManager, args: [String]) throws {
        var mutable = args
        let limitText = extractFlagValue("--limit", in: &mutable)
        let limit = limitText.flatMap(Int.init) ?? 20
        let events = manager.recentSecurityEvents(limit: max(limit, 1))
        if events.isEmpty {
            print("NO_EVENTS")
            return
        }

        for event in events {
            print("\(isoFormatter.string(from: event.timestamp)) [\(event.severity.rawValue)] \(event.source): \(event.message)")
        }
    }

    static func runSessionStart(manager: CoreManager, args: [String]) throws {
        var mutable = args
        let daysText = extractFlagValue("--days", in: &mutable)
        let secondsText = extractFlagValue("--seconds", in: &mutable)
        let minutesText = extractFlagValue("--minutes", in: &mutable)

        let durationSeconds: TimeInterval
        if let secondsText, let seconds = TimeInterval(secondsText) {
            durationSeconds = seconds
        } else if let daysText, let days = TimeInterval(daysText) {
            durationSeconds = days * 24 * 60 * 60
        } else if let minutesText, let minutes = TimeInterval(minutesText) {
            durationSeconds = minutes * 60
        } else {
            throw CLIError(message: "Provide --days <n>, --seconds <n>, or --minutes <n>")
        }

        let state = try manager.startSession(durationSeconds: durationSeconds)
        if let endsAt = state.session.endsAt {
            print("SESSION_STARTED until \(isoFormatter.string(from: endsAt))")
        } else {
            print("SESSION_STARTED")
        }
    }

    static func runSessionStop(manager: CoreManager) throws {
        _ = try manager.stopSession(now: Date().addingTimeInterval(121))
        print("SESSION_STOPPED")
    }

    static func runRuleAdd(manager: CoreManager, args: [String]) throws {
        var mutable = args
        guard let typeText = extractFlagValue("--type", in: &mutable) else {
            throw CLIError(message: "Missing --type <domain|exactHost|keyword>")
        }
        guard let value = extractFlagValue("--value", in: &mutable), !value.isEmpty else {
            throw CLIError(message: "Missing --value <text>")
        }
        guard let type = RuleType(rawValue: typeText) else {
            throw CLIError(message: "Invalid type: \(typeText)")
        }

        let state = try manager.addRule(BlockRule(type: type, value: value))
        print("RULE_ADDED total=\(state.rules.count)")
    }

    static func runRuleRemove(manager: CoreManager, args: [String]) throws {
        var mutable = args
        guard let typeText = extractFlagValue("--type", in: &mutable) else {
            throw CLIError(message: "Missing --type <domain|exactHost|keyword>")
        }
        guard let value = extractFlagValue("--value", in: &mutable), !value.isEmpty else {
            throw CLIError(message: "Missing --value <text>")
        }
        guard let type = RuleType(rawValue: typeText) else {
            throw CLIError(message: "Invalid type: \(typeText)")
        }

        let state = try manager.removeRule(BlockRule(type: type, value: value))
        print("RULE_REMOVED total=\(state.rules.count)")
    }

    static func runRuleList(manager: CoreManager) throws {
        let state = try manager.getState()
        if state.rules.isEmpty {
            print("NO_RULES")
            return
        }
        for rule in state.rules {
            print("\(rule.type.rawValue):\(rule.value)")
        }
    }

    static func runImportRules(manager: CoreManager, args: [String]) throws {
        var mutable = args
        guard let rulesPath = extractFlagValue("--rules", in: &mutable) else {
            throw CLIError(message: "Missing --rules <path>")
        }
        let rules = try RuleStore().loadRules(from: rulesPath)
        let state = try manager.replaceRules(rules)
        print("RULES_IMPORTED total=\(state.rules.count)")
    }

    static func runCheck(manager: CoreManager, args: [String]) throws {
        var mutable = args
        let url = extractFlagValue("--url", in: &mutable)
        let host = extractFlagValue("--host", in: &mutable)

        let decision: EnforcementDecision
        if let url {
            decision = try manager.evaluate(urlString: url)
        } else if let host {
            decision = try manager.evaluate(host: host)
        } else {
            throw CLIError(message: "Provide --url <value> or --host <value>")
        }

        if decision.shouldBlock {
            let matched = decision.matchedRule.map { "\($0.type.rawValue):\($0.value)" } ?? "unknown"
            print("BLOCKED reason=\(decision.reason.rawValue) matched=\(matched)")
            exit(2)
        } else {
            print("ALLOWED reason=\(decision.reason.rawValue)")
            exit(0)
        }
    }

    static func runLegacyCheck(args: [String]) throws {
        var mutable = args
        guard let rulesPath = extractFlagValue("--rules", in: &mutable) else {
            throw CLIError(message: "Missing --rules <path> argument")
        }

        let hostOrURL: String
        let urlMode: Bool
        if let url = extractFlagValue("--url", in: &mutable) {
            hostOrURL = url
            urlMode = true
        } else if let host = extractFlagValue("--host", in: &mutable) {
            hostOrURL = host
            urlMode = false
        } else {
            throw CLIError(message: "Provide either --url <value> or --host <value>")
        }

        let rules = try RuleStore().loadRules(from: rulesPath)
        let engine = BlockingEngine(rules: rules)

        let decision: BlockDecision
        if urlMode {
            decision = engine.evaluate(urlString: hostOrURL)
        } else {
            decision = engine.evaluate(host: hostOrURL)
        }

        if decision.isMatch {
            let matched = decision.matchedRule.map { "\($0.type.rawValue):\($0.value)" } ?? "unknown"
            print("BLOCKED (matched \(matched))")
            exit(2)
        } else {
            print("ALLOWED")
            exit(0)
        }
    }

    static func printUsage() {
        print("""
        blockpmac - stronger core runner for focus-block workflows

        Usage:
          blockpmac [--state-path <file>] self-test
          blockpmac [--state-path <file>] status
          blockpmac [--state-path <file>] mode-set --mode <blocklist|allowlist>
          blockpmac [--state-path <file>] events [--limit <n>]
          blockpmac [--state-path <file>] session-start --days <n>
          blockpmac [--state-path <file>] session-start --minutes <n>
          blockpmac [--state-path <file>] session-start --seconds <n>
          blockpmac [--state-path <file>] session-stop
          blockpmac [--state-path <file>] rule-add --type <domain|exactHost|keyword> --value <text>
          blockpmac [--state-path <file>] rule-remove --type <domain|exactHost|keyword> --value <text>
          blockpmac [--state-path <file>] rule-list
          blockpmac [--state-path <file>] import-rules --rules <path>
          blockpmac [--state-path <file>] check --url <url>
          blockpmac [--state-path <file>] check --host <host>
          blockpmac check-legacy --rules <path> --url <url>

        Examples:
          blockpmac --state-path ./state.json import-rules --rules ./rules.sample.json
                    blockpmac --state-path ./state.json session-start --days 1
          blockpmac --state-path ./state.json session-start --minutes 30
                    blockpmac --state-path ./state.json mode-set --mode allowlist
                    blockpmac --state-path ./state.json events --limit 10
          blockpmac --state-path ./state.json check --url https://instagram.com/reels
          blockpmac --state-path ./state.json session-stop
        """)
    }

    static func runSelfTest() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("blockpmac-selftest-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let statePath = tempDir.appendingPathComponent("state.json").path
        let manager = CoreManager(store: StateStore(stateFilePath: statePath))

        let rules = [
            BlockRule(type: .domain, value: "instagram.com"),
            BlockRule(type: .exactHost, value: "news.ycombinator.com"),
            BlockRule(type: .keyword, value: "casino")
        ]
        _ = try manager.replaceRules(rules)

        let noSessionDecision = try manager.evaluate(host: "www.instagram.com")
        guard !noSessionDecision.shouldBlock, noSessionDecision.reason == .noActiveSession else {
            throw CLIError(message: "Self-test failed: no-session rule")
        }

        _ = try manager.startSession(durationSeconds: 120)

        guard try manager.evaluate(host: "www.instagram.com").shouldBlock else {
            throw CLIError(message: "Self-test failed: domain rule")
        }
        guard try manager.evaluate(host: "news.ycombinator.com").shouldBlock else {
            throw CLIError(message: "Self-test failed: exactHost rule")
        }
        guard try manager.evaluate(host: "best-casino-deals.example").shouldBlock else {
            throw CLIError(message: "Self-test failed: keyword rule")
        }
        guard !(try manager.evaluate(host: "example.com").shouldBlock) else {
            throw CLIError(message: "Self-test failed: allow rule")
        }

                _ = try manager.setEnforcementMode(.allowlist)
                let allowlistAllowed = try manager.evaluate(host: "instagram.com")
                guard !allowlistAllowed.shouldBlock,
                            allowlistAllowed.reason == .activeSessionAllowlistRuleMatch else {
                        throw CLIError(message: "Self-test failed: allowlist allow match")
                }
                let allowlistBlocked = try manager.evaluate(host: "example.com")
                guard allowlistBlocked.shouldBlock,
                            allowlistBlocked.reason == .activeSessionAllowlistRuleMiss else {
                        throw CLIError(message: "Self-test failed: allowlist block miss")
                }
                _ = try manager.setEnforcementMode(.blocklist)

        _ = try manager.stopSession(now: Date().addingTimeInterval(121))

        let stoppedDecision = try manager.evaluate(host: "www.instagram.com")
        guard !stoppedDecision.shouldBlock, stoppedDecision.reason == .noActiveSession else {
            throw CLIError(message: "Self-test failed: session stop")
        }

        let reloadedState = try StateStore(stateFilePath: statePath).load()
        guard reloadedState.rules.count == 3 else {
            throw CLIError(message: "Self-test failed: persistence")
        }

        _ = try manager.setStrictMode(true)
        _ = try manager.startSession(durationSeconds: 120)

        do {
            _ = try manager.stopSession()
            throw CLIError(message: "Self-test failed: strict-mode early stop should be blocked")
        } catch let error as CoreManagerError {
            guard case .strictSessionCannotStop = error else {
                throw CLIError(message: "Self-test failed: expected strict stop error")
            }
        }

        let strictDecision = try manager.evaluate(host: "instagram.com")
        guard strictDecision.shouldBlock, strictDecision.reason == .penaltyLockActive else {
            throw CLIError(message: "Self-test failed: penalty lock reason")
        }

        let strictState = try manager.getState()
        guard strictState.session.isPenaltyLocked() else {
            throw CLIError(message: "Self-test failed: penalty lock state not set")
        }

        print("SELF-TEST PASSED")
    }

    static func extractFlagValue(_ flag: String, in args: inout [String]) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else {
            return nil
        }
        let value = args[index + 1]
        args.remove(at: index + 1)
        args.remove(at: index)
        return value
    }

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
