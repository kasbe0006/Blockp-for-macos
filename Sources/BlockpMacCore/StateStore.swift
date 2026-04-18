import Foundation

public enum StateStoreError: Error, LocalizedError {
    case stateDirectoryCreationFailed(String)
    case stateWriteFailed(String)
    case stateReadFailed(String)
    case stateDecodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .stateDirectoryCreationFailed(let path):
            return "Failed to create app state directory at: \(path)"
        case .stateWriteFailed(let path):
            return "Failed to write app state file at: \(path)"
        case .stateReadFailed(let path):
            return "Failed to read app state file at: \(path)"
        case .stateDecodeFailed(let path):
            return "Failed to decode app state file at: \(path)"
        }
    }
}

public struct StateStore: Sendable {
    public let stateFilePath: String

    public init(stateFilePath: String) {
        self.stateFilePath = stateFilePath
    }

    public static func defaultStore(appName: String = "BlockpMac") throws -> StateStore {
        let fileManager = FileManager.default
        let base = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
            .appendingPathComponent(appName, isDirectory: true)

        do {
            try fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        } catch {
            throw StateStoreError.stateDirectoryCreationFailed(base.path)
        }

        let file = base.appendingPathComponent("state.json")
        return StateStore(stateFilePath: file.path)
    }

    public func load() throws -> AppState {
        let url = URL(fileURLWithPath: stateFilePath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return AppState()
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw StateStoreError.stateReadFailed(url.path)
        }

        do {
            return try JSONDecoder.appDecoder.decode(AppState.self, from: data)
        } catch {
            let backupURL = URL(fileURLWithPath: stateFilePath + ".bak")
            if FileManager.default.fileExists(atPath: backupURL.path),
               let backupData = try? Data(contentsOf: backupURL),
               let recoveredState = try? JSONDecoder.appDecoder.decode(AppState.self, from: backupData) {
                return recoveredState
            }
            throw StateStoreError.stateDecodeFailed(url.path)
        }
    }

    public func save(_ state: AppState) throws {
        let url = URL(fileURLWithPath: stateFilePath)
        let backupURL = URL(fileURLWithPath: stateFilePath + ".bak")

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                let currentData = try Data(contentsOf: url)
                try currentData.write(to: backupURL, options: .atomic)
            }
            let data = try JSONEncoder.prettyEncoder.encode(state)
            try data.write(to: url, options: .atomic)
        } catch {
            throw StateStoreError.stateWriteFailed(url.path)
        }
    }
}

extension JSONEncoder {
    static var prettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var appDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
