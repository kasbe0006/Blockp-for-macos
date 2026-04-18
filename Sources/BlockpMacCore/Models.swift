import Foundation

public enum RuleType: String, Codable, CaseIterable, Sendable {
    case domain
    case exactHost
    case keyword
}

public struct BlockRule: Codable, Hashable, Sendable {
    public var type: RuleType
    public var value: String

    public init(type: RuleType, value: String) {
        self.type = type
        self.value = value
    }
}

public struct BlockList: Codable, Sendable {
    public var rules: [BlockRule]

    public init(rules: [BlockRule]) {
        self.rules = rules
    }
}

public struct FocusSession: Sendable {
    public let startDate: Date
    public let duration: TimeInterval

    public init(startDate: Date = Date(), duration: TimeInterval) {
        self.startDate = startDate
        self.duration = duration
    }

    public var endDate: Date {
        startDate.addingTimeInterval(duration)
    }

    public func isActive(at now: Date = Date()) -> Bool {
        now >= startDate && now <= endDate
    }
}
