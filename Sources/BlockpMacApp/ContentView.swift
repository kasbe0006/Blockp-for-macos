import SwiftUI
import BlockpMacCore

struct ContentView: View {
    @ObservedObject var stateModel: AppStateModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "circle.fill")
                    .foregroundColor(stateModel.appState.session.isCurrentlyActive() ? .green : .gray)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("BlockpMac")
                        .font(.headline)
                    Text(stateModel.appState.session.isCurrentlyActive() ? "Active" : "Idle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let timeRemaining = stateModel.sessionTimeRemaining {
                    Text(timeRemaining)
                        .font(.caption2)
                        .monospacedDigit()
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))

            if stateModel.isPenaltyActive, let penaltyRemaining = stateModel.penaltyTimeRemaining {
                HStack {
                    Image(systemName: "lock.fill")
                    Text("Penalty lock active: \(penaltyRemaining)")
                        .font(.caption)
                        .bold()
                    Spacer()
                }
                .padding(10)
                .background(Color.red.opacity(0.18))
            }

            Divider()

            HStack(spacing: 8) {
                tabButton(title: "Session", icon: "play.fill", tag: 0)
                tabButton(title: "Rules", icon: "list.bullet", tag: 1)
                tabButton(title: "Status", icon: "info.circle", tag: 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            Group {
                switch selectedTab {
                case 0:
                    SessionTab(stateModel: stateModel)
                case 1:
                    RulesTab(stateModel: stateModel)
                default:
                    StatusTab(stateModel: stateModel)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .background(Color(.controlBackgroundColor))
    }

    @ViewBuilder
    private func tabButton(title: String, icon: String, tag: Int) -> some View {
        Button(action: { selectedTab = tag }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(selectedTab == tag ? .accentColor : .gray.opacity(0.45))
    }
}

struct SessionTab: View {
    @ObservedObject var stateModel: AppStateModel
    @State private var sessionDays: String = "0"
    @State private var sessionMinutes: String = "30"

    var body: some View {
        VStack(spacing: 16) {
            Text("Session Control")
                .font(.headline)
                .padding()

            Toggle(
                "Strict mode (can't stop until timer ends)",
                isOn: Binding(
                    get: { stateModel.appState.policy.strictMode },
                    set: { stateModel.setStrictMode($0) }
                )
            )
            .toggleStyle(.switch)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                Text("Enforcement mode")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker(
                    "Enforcement mode",
                    selection: Binding(
                        get: { stateModel.appState.policy.enforcementMode },
                        set: { stateModel.setEnforcementMode($0) }
                    )
                ) {
                    Text("Blocklist").tag(EnforcementMode.blocklist)
                    Text("Allowlist").tag(EnforcementMode.allowlist)
                }
                .pickerStyle(.segmented)

                Text(stateModel.appState.policy.enforcementMode == .allowlist
                     ? "Allowlist mode ON: only rule-matching hosts are allowed during session."
                     : "Blocklist mode ON: rule-matching hosts are blocked during session.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            if stateModel.appState.session.isCurrentlyActive() {
                VStack(spacing: 12) {
                    Text("Session Active")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    if let timeRemaining = stateModel.sessionTimeRemaining {
                        Text("Ends in \(timeRemaining)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)

                Button("Stop Session") {
                    stateModel.stopSession()
                }
                .buttonStyle(.automatic)
                .frame(maxWidth: .infinity)
                .disabled(!stateModel.canStopSession)

                if !stateModel.canStopSession, stateModel.appState.policy.strictMode {
                    Text("Strict mode active: stop is disabled until timer ends.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Start new session")
                        .font(.caption)
                    
                    HStack {
                        TextField("Days", text: $sessionDays)
                            .textFieldStyle(.roundedBorder)
                        Text("day(s)")
                    }

                    HStack {
                        TextField("Minutes", text: $sessionMinutes)
                            .textFieldStyle(.roundedBorder)
                        Text("min")
                    }

                    Button("Start Focus Session") {
                        if let days = TimeInterval(sessionDays), let minutes = TimeInterval(sessionMinutes) {
                            stateModel.startSession(days: days, minutes: minutes)
                        }
                    }
                    .buttonStyle(.automatic)
                    .frame(maxWidth: .infinity)
                }
                .padding(12)
            }

            Spacer()
        }
        .padding()
    }
}

struct RulesTab: View {
    @ObservedObject var stateModel: AppStateModel
    @State private var ruleType: RuleType = .domain
    @State private var ruleValue: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Rules (\(stateModel.appState.rules.count))")
                .font(.headline)
                .padding()

            List {
                ForEach(stateModel.appState.rules, id: \.self) { rule in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(rule.value)
                                .font(.body)
                        }
                        Spacer()
                        Button(action: {
                            stateModel.removeRule(type: rule.type, value: rule.value)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 250)

            Divider()

            VStack(spacing: 8) {
                Picker("Type", selection: $ruleType) {
                    ForEach([RuleType.domain, RuleType.exactHost, RuleType.keyword], id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.menu)

                TextField("Value", text: $ruleValue)
                    .textFieldStyle(.roundedBorder)

                Button("Add Rule") {
                    if !ruleValue.isEmpty {
                        stateModel.addRule(type: ruleType, value: ruleValue)
                        ruleValue = ""
                    }
                }
                .buttonStyle(.automatic)
                .frame(maxWidth: .infinity)
            }
            .padding(12)

            Spacer()
        }
        .padding()
    }
}

struct StatusTab: View {
    @ObservedObject var stateModel: AppStateModel
    @State private var testHost: String = "instagram.com"
    @State private var testResult: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Status")
                .font(.headline)
                .padding()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Session Active")
                    Spacer()
                    Text(stateModel.appState.session.isCurrentlyActive() ? "Yes" : "No")
                        .foregroundColor(stateModel.appState.session.isCurrentlyActive() ? .green : .red)
                }

                HStack {
                    Text("Rules Loaded")
                    Spacer()
                    Text("\(stateModel.appState.rules.count)")
                }

                HStack {
                    Text("Strict Mode")
                    Spacer()
                    Text(stateModel.appState.policy.strictMode ? "On" : "Off")
                }

                HStack {
                    Text("Enforcement Mode")
                    Spacer()
                    Text(stateModel.appState.policy.enforcementMode.rawValue.capitalized)
                }

                HStack {
                    Text("Penalty Lock")
                    Spacer()
                    Text(stateModel.isPenaltyActive ? "On" : "Off")
                        .foregroundColor(stateModel.isPenaltyActive ? .red : .green)
                }

                HStack {
                    Text("Last Updated")
                    Spacer()
                    Text(formatDate(stateModel.appState.updatedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Blocked-attempt test")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Host to test", text: $testHost)
                    .textFieldStyle(.roundedBorder)

                Button("Try Open Host") {
                    guard !testHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        testResult = "Enter a host first"
                        return
                    }

                    if let decision = stateModel.checkHost(testHost) {
                        if decision.shouldBlock {
                            testResult = "Blocked (\(decision.reason.rawValue))"
                        } else {
                            testResult = "Allowed (\(decision.reason.rawValue))"
                        }
                    }
                }
                .buttonStyle(.borderedProminent)

                if let testResult {
                    Text(testResult)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            if let error = stateModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Security & Tamper Events")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Reload") {
                        stateModel.refreshEvents()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                }

                if stateModel.recentEvents.isEmpty {
                    Text("No events yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(stateModel.recentEvents.prefix(20)), id: \.self) { event in
                                Text("[\(event.severity.rawValue.uppercased())] \(formatDate(event.timestamp)) • \(event.source): \(event.message)")
                                    .font(.caption2)
                                    .foregroundColor(color(for: event.severity))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(maxHeight: 130)
                }
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)

            Spacer()

            Button("Refresh") {
                stateModel.refreshState()
            }
            .buttonStyle(.automatic)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }

    private func color(for severity: SecurityEventSeverity) -> Color {
        switch severity {
        case .info:
            return .secondary
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }
}

