import Foundation

public struct BlockDecision: Sendable {
    public let isMatch: Bool
    public let matchedRule: BlockRule?

    public init(isMatch: Bool, matchedRule: BlockRule?) {
        self.isMatch = isMatch
        self.matchedRule = matchedRule
    }
}

public struct BlockingEngine: Sendable {
    private let rules: [BlockRule]

    public init(rules: [BlockRule]) {
        self.rules = rules
    }

    public func evaluate(urlString: String) -> BlockDecision {
        guard let url = URL(string: urlString), let host = url.host else {
            return BlockDecision(isMatch: false, matchedRule: nil)
        }
        return evaluate(host: host)
    }

    public func evaluate(host rawHost: String) -> BlockDecision {
        let host = normalizeHost(rawHost)

        for rule in rules {
            switch rule.type {
            case .domain:
                let blockedDomain = normalizeHost(rule.value)
                if host == blockedDomain || host.hasSuffix("." + blockedDomain) {
                    return BlockDecision(isMatch: true, matchedRule: rule)
                }

            case .exactHost:
                if host == normalizeHost(rule.value) {
                    return BlockDecision(isMatch: true, matchedRule: rule)
                }

            case .keyword:
                if host.localizedCaseInsensitiveContains(rule.value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    return BlockDecision(isMatch: true, matchedRule: rule)
                }
            }
        }

        return BlockDecision(isMatch: false, matchedRule: nil)
    }

    private func normalizeHost(_ host: String) -> String {
        host
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }
}
