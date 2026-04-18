import Foundation

public enum SecurityEventSeverity: String, Codable, Sendable {
    case info
    case warning
    case critical
}

public struct SecurityEvent: Codable, Sendable, Hashable {
    public let timestamp: Date
    public let severity: SecurityEventSeverity
    public let source: String
    public let message: String

    public init(timestamp: Date = Date(), severity: SecurityEventSeverity, source: String, message: String) {
        self.timestamp = timestamp
        self.severity = severity
        self.source = source
        self.message = message
    }
}

public struct SecurityEventStore: Sendable {
    public let logFilePath: String

    public init(logFilePath: String) {
        self.logFilePath = logFilePath
    }

    public func append(_ event: SecurityEvent) {
        let line = "\(iso8601.string(from: event.timestamp))|\(event.severity.rawValue)|\(event.source)|\(sanitize(event.message))\n"
        let url = URL(fileURLWithPath: logFilePath)

        let directoryURL = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: logFilePath) {
            try? Data().write(to: url)
        }

        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                return
            }
        }
    }

    public func recent(limit: Int = 30) -> [SecurityEvent] {
        guard limit > 0 else { return [] }

        let url = URL(fileURLWithPath: logFilePath)
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = text.split(separator: "\n").suffix(limit)
        return lines.compactMap { parseLine(String($0)) }.sorted(by: { $0.timestamp > $1.timestamp })
    }

    private func parseLine(_ line: String) -> SecurityEvent? {
        let parts = line.split(separator: "|", maxSplits: 3).map(String.init)
        guard parts.count == 4 else { return nil }

        guard let timestamp = iso8601.date(from: parts[0]),
              let severity = SecurityEventSeverity(rawValue: parts[1]) else {
            return nil
        }

        return SecurityEvent(
            timestamp: timestamp,
            severity: severity,
            source: parts[2],
            message: parts[3]
        )
    }

    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }
}
