import Foundation

public enum EnforcementMode: String, Codable, Sendable, CaseIterable {
    case blocklist
    case allowlist
}

public struct FocusPolicy: Codable, Sendable {
    public var strictMode: Bool
    public var breakDurationSeconds: TimeInterval
    public var enforcementMode: EnforcementMode

    public init(strictMode: Bool = false, breakDurationSeconds: TimeInterval = 120, enforcementMode: EnforcementMode = .blocklist) {
        self.strictMode = strictMode
        self.breakDurationSeconds = breakDurationSeconds
        self.enforcementMode = enforcementMode
    }

    enum CodingKeys: String, CodingKey {
        case strictMode
        case breakDurationSeconds
        case enforcementMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        strictMode = try container.decodeIfPresent(Bool.self, forKey: .strictMode) ?? false
        breakDurationSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .breakDurationSeconds) ?? 120
        enforcementMode = try container.decodeIfPresent(EnforcementMode.self, forKey: .enforcementMode) ?? .blocklist
    }
}

public struct SessionState: Codable, Sendable {
    public var isActive: Bool
    public var startedAt: Date?
    public var endsAt: Date?
    public var lastBreakAt: Date?
    public var lockedUntil: Date?

    public init(isActive: Bool = false, startedAt: Date? = nil, endsAt: Date? = nil, lastBreakAt: Date? = nil, lockedUntil: Date? = nil) {
        self.isActive = isActive
        self.startedAt = startedAt
        self.endsAt = endsAt
        self.lastBreakAt = lastBreakAt
        self.lockedUntil = lockedUntil
    }

    public func isCurrentlyActive(at now: Date = Date()) -> Bool {
        guard isActive else { return false }
        guard let endsAt else { return false }
        return now <= endsAt
    }

    public func isPenaltyLocked(at now: Date = Date()) -> Bool {
        guard let lockedUntil else { return false }
        return now < lockedUntil
    }
}

public struct AppState: Codable, Sendable {
    public var rules: [BlockRule]
    public var policy: FocusPolicy
    public var session: SessionState
    public var updatedAt: Date

    public init(
        rules: [BlockRule] = [],
        policy: FocusPolicy = FocusPolicy(),
        session: SessionState = SessionState(),
        updatedAt: Date = Date()
    ) {
        self.rules = rules
        self.policy = policy
        self.session = session
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case rules
        case policy
        case session
        case updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rules = try container.decodeIfPresent([BlockRule].self, forKey: .rules) ?? []
        policy = try container.decodeIfPresent(FocusPolicy.self, forKey: .policy) ?? FocusPolicy()
        session = try container.decodeIfPresent(SessionState.self, forKey: .session) ?? SessionState()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

public enum BlockReason: String, Sendable {
    case activeSessionRuleMatch
    case activeSessionAllowlistRuleMiss
    case activeSessionAllowlistRuleMatch
    case noActiveSession
    case noRuleMatch
    case invalidInput
    case penaltyLockActive
}

public struct EnforcementDecision: Sendable {
    public let shouldBlock: Bool
    public let reason: BlockReason
    public let matchedRule: BlockRule?
    public let sessionActive: Bool

    public init(shouldBlock: Bool, reason: BlockReason, matchedRule: BlockRule?, sessionActive: Bool) {
        self.shouldBlock = shouldBlock
        self.reason = reason
        self.matchedRule = matchedRule
        self.sessionActive = sessionActive
    }
}
