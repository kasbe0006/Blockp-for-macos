import Foundation

public enum RuleStoreError: Error, LocalizedError {
    case fileNotFound(String)
    case decodeFailed

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Rules file not found at path: \(path)"
        case .decodeFailed:
            return "Could not decode rules JSON"
        }
    }
}

public struct RuleStore: Sendable {
    public init() {}

    public func loadRules(from path: String) throws -> [BlockRule] {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RuleStoreError.fileNotFound(url.path)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        if let blockList = try? decoder.decode(BlockList.self, from: data) {
            return blockList.rules
        }

        if let flatRules = try? decoder.decode([BlockRule].self, from: data) {
            return flatRules
        }

        throw RuleStoreError.decodeFailed
    }
}
