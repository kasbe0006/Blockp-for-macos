import Foundation
import BlockpMacCore

@MainActor
class AppStateModel: ObservableObject {
    @Published var appState: AppState
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var sessionTimeRemaining: String?
    @Published var penaltyTimeRemaining: String?
    @Published var recentEvents: [SecurityEvent] = []

    private let manager: CoreManager
    private let systemEventStore = SecurityEventStore(logFilePath: "/Library/PrivilegedHelperTools/BlockpMac/events.log")
    private var timerTask: Task<Void, Never>?

    init(manager: CoreManager) {
        self.manager = manager
        do {
            self.appState = try manager.getState()
            if !appState.session.isCurrentlyActive(),
               appState.session.isActive,
               let endsAt = appState.session.endsAt,
               endsAt <= Date() {
                appState.session = SessionState(isActive: false, startedAt: appState.session.startedAt, endsAt: endsAt, lastBreakAt: appState.session.lastBreakAt, lockedUntil: nil)
            }
        } catch {
            self.appState = AppState()
            self.errorMessage = error.localizedDescription
        }
        startTimer()
        updateSessionTimeRemaining()
        updatePenaltyTimeRemaining()
        refreshEvents()
    }

    func refreshState() {
        do {
            appState = try manager.getState()
            if !appState.session.isCurrentlyActive(),
               appState.session.isActive,
               let endsAt = appState.session.endsAt,
               endsAt <= Date() {
                appState.session = SessionState(isActive: false, startedAt: appState.session.startedAt, endsAt: endsAt, lastBreakAt: appState.session.lastBreakAt, lockedUntil: nil)
            }
            errorMessage = nil
            updateSessionTimeRemaining()
            updatePenaltyTimeRemaining()
            refreshEvents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startSession(minutes: TimeInterval) {
        isLoading = true
        do {
            appState = try manager.startSession(durationSeconds: minutes * 60)
            startTimer()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func startSession(days: TimeInterval, minutes: TimeInterval) {
        isLoading = true
        do {
            let totalSeconds = (days * 24 * 60 * 60) + (minutes * 60)
            appState = try manager.startSession(durationSeconds: totalSeconds)
            startTimer()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func stopSession() {
        isLoading = true
        do {
            appState = try manager.stopSession()
            updateSessionTimeRemaining()
            updatePenaltyTimeRemaining()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func setStrictMode(_ enabled: Bool) {
        isLoading = true
        do {
            appState = try manager.setStrictMode(enabled)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func setEnforcementMode(_ mode: EnforcementMode) {
        isLoading = true
        do {
            appState = try manager.setEnforcementMode(mode)
            refreshEvents()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func addRule(type: RuleType, value: String) {
        isLoading = true
        do {
            appState = try manager.addRule(BlockRule(type: type, value: value))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func removeRule(type: RuleType, value: String) {
        isLoading = true
        do {
            appState = try manager.removeRule(BlockRule(type: type, value: value))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func importRules(from path: String) {
        isLoading = true
        do {
            let rules = try RuleStore().loadRules(from: path)
            appState = try manager.replaceRules(rules)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func checkHost(_ host: String) -> EnforcementDecision? {
        do {
            let decision = try manager.evaluate(host: host)
            appState = try manager.getState()
            updatePenaltyTimeRemaining()

            if decision.reason == .penaltyLockActive {
                lockMacScreenBestEffort()
            }

            refreshEvents()

            return decision
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                updateSessionTimeRemaining()
                updatePenaltyTimeRemaining()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func updateSessionTimeRemaining() {
        guard appState.session.isCurrentlyActive() else {
            sessionTimeRemaining = nil
            return
        }

        if let endsAt = appState.session.endsAt {
            let remaining = endsAt.timeIntervalSince(Date())
            if remaining > 0 {
                let minutes = Int(remaining / 60)
                let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
                sessionTimeRemaining = String(format: "%d:%02d", minutes, seconds)
            } else {
                refreshState()
            }
        }
    }

    private func updatePenaltyTimeRemaining() {
        guard let lockedUntil = appState.session.lockedUntil else {
            penaltyTimeRemaining = nil
            return
        }

        let remaining = lockedUntil.timeIntervalSince(Date())
        if remaining <= 0 {
            penaltyTimeRemaining = nil
            return
        }

        let minutes = Int(remaining / 60)
        let seconds = Int(remaining.truncatingRemainder(dividingBy: 60))
        penaltyTimeRemaining = String(format: "%d:%02d", minutes, seconds)
    }

    func refreshEvents(limit: Int = 30) {
        let appEvents = manager.recentSecurityEvents(limit: limit)
        let systemEvents = systemEventStore.recent(limit: limit)
        recentEvents = Array((appEvents + systemEvents).sorted(by: { $0.timestamp > $1.timestamp }).prefix(limit))
    }

    var isPenaltyActive: Bool {
        appState.session.isPenaltyLocked()
    }

    var canStopSession: Bool {
        guard appState.session.isCurrentlyActive() else { return false }
        guard let endsAt = appState.session.endsAt else { return false }
        return Date() >= endsAt
    }

    var canTerminateApplication: Bool {
        if isPenaltyActive {
            return false
        }

        if appState.session.isCurrentlyActive() {
            return false
        }

        return true
    }

    var terminationBlockedMessage: String {
        if isPenaltyActive, let penaltyTimeRemaining {
            return "Penalty lock is active for \(penaltyTimeRemaining). You cannot quit the app now."
        }

        if appState.session.isCurrentlyActive(),
           let sessionTimeRemaining {
            return "Focus session is running (\(sessionTimeRemaining) left). You cannot quit until it ends."
        }

        return "App can be closed."
    }

    private func lockMacScreenBestEffort() {
        let cgSessionPath = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        guard FileManager.default.fileExists(atPath: cgSessionPath) else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cgSessionPath)
        process.arguments = ["-suspend"]
        do {
            try process.run()
        } catch {
            errorMessage = "Blocked attempt detected. Could not auto-lock macOS screen."
        }
    }
}
