import Foundation

public enum CoreManagerError: Error, LocalizedError {
    case duplicateRule
    case invalidDuration
    case noActiveSession
    case strictSessionCannotStop(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .duplicateRule:
            return "Rule already exists"
        case .invalidDuration:
            return "Session duration must be greater than zero"
        case .noActiveSession:
            return "No active session to stop"
        case .strictSessionCannotStop(let remainingSeconds):
            let minutes = Int(remainingSeconds / 60)
            let seconds = Int(remainingSeconds.truncatingRemainder(dividingBy: 60))
            return "Focus session is locked until timer ends (\(minutes)m \(seconds)s remaining)."
        }
    }
}

public struct CoreManager: Sendable {
    private let store: StateStore
    private let eventStore: SecurityEventStore

    public init(store: StateStore) {
        self.store = store
        let stateURL = URL(fileURLWithPath: store.stateFilePath)
        let eventPath = stateURL.deletingLastPathComponent().appendingPathComponent("events.log").path
        self.eventStore = SecurityEventStore(logFilePath: eventPath)
    }

    public func getState() throws -> AppState {
        try store.load()
    }

    public func addRule(_ rule: BlockRule) throws -> AppState {
        var state = try store.load()

        guard !state.rules.contains(rule) else {
            throw CoreManagerError.duplicateRule
        }

        state.rules.append(rule)
        state.updatedAt = Date()
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Rule added: \(rule.type.rawValue):\(rule.value)"))
        return state
    }

    public func removeRule(_ rule: BlockRule) throws -> AppState {
        var state = try store.load()
        state.rules.removeAll { $0 == rule }
        state.updatedAt = Date()
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Rule removed: \(rule.type.rawValue):\(rule.value)"))
        return state
    }

    public func replaceRules(_ rules: [BlockRule]) throws -> AppState {
        var state = try store.load()
        state.rules = rules
        state.updatedAt = Date()
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Rules replaced. Total=\(rules.count)"))
        return state
    }

    public func startSession(durationSeconds: TimeInterval, now: Date = Date()) throws -> AppState {
        guard durationSeconds > 0 else {
            throw CoreManagerError.invalidDuration
        }

        var state = try store.load()
        state.session = SessionState(
            isActive: true,
            startedAt: now,
            endsAt: now.addingTimeInterval(durationSeconds),
            lastBreakAt: state.session.lastBreakAt,
            lockedUntil: nil
        )
        state.updatedAt = now
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Session started until \(ISO8601DateFormatter().string(from: state.session.endsAt ?? now))"))
        return state
    }

    public func stopSession(now: Date = Date()) throws -> AppState {
        var state = try store.load()
        let active = state.session.isCurrentlyActive(at: now)
        guard state.session.isActive || active else {
            throw CoreManagerError.noActiveSession
        }

        if let endsAt = state.session.endsAt,
           now < endsAt {
            throw CoreManagerError.strictSessionCannotStop(endsAt.timeIntervalSince(now))
        }

        state.session = SessionState(
            isActive: false,
            startedAt: state.session.startedAt,
            endsAt: now,
            lastBreakAt: state.session.lastBreakAt,
            lockedUntil: nil
        )
        state.updatedAt = now
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Session stopped"))
        return state
    }

    public func setPolicy(_ policy: FocusPolicy) throws -> AppState {
        var state = try store.load()
        state.policy = policy
        state.updatedAt = Date()
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Policy updated: strict=\(policy.strictMode) mode=\(policy.enforcementMode.rawValue)"))
        return state
    }

    public func setStrictMode(_ enabled: Bool) throws -> AppState {
        var state = try store.load()
        state.policy.strictMode = enabled
        state.updatedAt = Date()
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Strict mode set to \(enabled)"))
        return state
    }

    public func setEnforcementMode(_ mode: EnforcementMode) throws -> AppState {
        var state = try store.load()
        state.policy.enforcementMode = mode
        state.updatedAt = Date()
        try store.save(state)
        eventStore.append(SecurityEvent(severity: .warning, source: "core", message: "Enforcement mode changed to \(mode.rawValue)"))
        return state
    }

    public func recentSecurityEvents(limit: Int = 30) -> [SecurityEvent] {
        eventStore.recent(limit: limit)
    }

    public func logSecurityEvent(severity: SecurityEventSeverity, source: String, message: String) {
        eventStore.append(SecurityEvent(severity: severity, source: source, message: message))
    }

    public func evaluate(host: String, now: Date = Date()) throws -> EnforcementDecision {
        var state = try store.load()
        let sessionActive = state.session.isCurrentlyActive(at: now)

        guard sessionActive else {
            return EnforcementDecision(
                shouldBlock: false,
                reason: .noActiveSession,
                matchedRule: nil,
                sessionActive: false
            )
        }

        let engine = BlockingEngine(rules: state.rules)
        let decision = engine.evaluate(host: host)

        let shouldBlock: Bool
        let reason: BlockReason
        let severity: SecurityEventSeverity

        switch state.policy.enforcementMode {
        case .blocklist:
            shouldBlock = decision.isMatch
            reason = decision.isMatch ? .activeSessionRuleMatch : .noRuleMatch
            severity = decision.isMatch ? .warning : .info
        case .allowlist:
            shouldBlock = !decision.isMatch
            reason = decision.isMatch ? .activeSessionAllowlistRuleMatch : .activeSessionAllowlistRuleMiss
            severity = decision.isMatch ? .info : .critical
        }

        if shouldBlock {
            if state.policy.strictMode {
                state.session.lockedUntil = now.addingTimeInterval(60)
                state.updatedAt = now
                try store.save(state)
                eventStore.append(SecurityEvent(severity: .critical, source: "core", message: "Penalty lock triggered for host \(host)"))
                return EnforcementDecision(
                    shouldBlock: true,
                    reason: .penaltyLockActive,
                    matchedRule: decision.matchedRule,
                    sessionActive: true
                )
            }

            eventStore.append(SecurityEvent(severity: severity, source: "core", message: "Blocked host \(host) reason=\(reason.rawValue) mode=\(state.policy.enforcementMode.rawValue)"))

            return EnforcementDecision(
                shouldBlock: true,
                reason: reason,
                matchedRule: decision.matchedRule,
                sessionActive: true
            )
        }

        if state.policy.enforcementMode == .allowlist {
            eventStore.append(SecurityEvent(severity: .info, source: "core", message: "Allowlisted host \(host)"))
        }

        return EnforcementDecision(
            shouldBlock: false,
            reason: reason,
            matchedRule: nil,
            sessionActive: true
        )
    }

    public func evaluate(urlString: String, now: Date = Date()) throws -> EnforcementDecision {
        guard let host = URL(string: urlString)?.host else {
            return EnforcementDecision(
                shouldBlock: false,
                reason: .invalidInput,
                matchedRule: nil,
                sessionActive: false
            )
        }

        return try evaluate(host: host, now: now)
    }
}
