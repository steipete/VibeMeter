import SwiftUI

/// Displays multi-account session information for Claude
struct MultiAccountSessionsView: View {
    let accountSessions: [AccountSession]
    let currentSessionId: String?
    let multiAccountDetector: MultiAccountDetector
    
    @State private var expandedSessionId: String?
    @State private var editingSessionId: String?
    @State private var editingName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Account Sessions", systemImage: "person.2.circle")
                    .font(.headline)
                
                Spacer()
                
                if accountSessions.count > 1 {
                    Text("\(accountSessions.count) detected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if accountSessions.count == 1,
                          let session = accountSessions.first,
                          multiAccountDetector.getAccountName(for: session.id) == nil {
                    Button(action: {
                        editingSessionId = session.id
                        editingName = ""
                    }) {
                        Label("Name Account", systemImage: "pencil")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            
            // Session list
            VStack(spacing: 8) {
                ForEach(accountSessions) { session in
                    AccountSessionRow(
                        session: session,
                        isExpanded: expandedSessionId == session.id,
                        isCurrent: currentSessionId == session.id,
                        accountName: multiAccountDetector.getAccountName(for: session.id),
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedSessionId = expandedSessionId == session.id ? nil : session.id
                            }
                        },
                        onEditName: { newName in
                            multiAccountDetector.setAccountName(for: session.id, name: newName.isEmpty ? nil : newName)
                        }
                    )
                }
            }
            
            // Additional info based on session count
            VStack(alignment: .leading, spacing: 8) {
                if accountSessions.count > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Multiple sessions detected. This may indicate different Claude accounts.")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                } else if let session = accountSessions.first {
                    // Show more details for single session
                    VStack(alignment: .leading, spacing: 6) {
                        Divider()
                            .padding(.horizontal, 8)
                        
                        // Usage breakdown
                        HStack {
                            Label("Usage Pattern", systemImage: "chart.pie")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(getUsagePattern(session))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        
                        // Recent activity
                        if let recentActivity = getRecentActivity(session) {
                            HStack {
                                Label("Recent Activity", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(recentActivity)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                        }
                        
                        // Model preference
                        if let modelPref = getModelPreference(session) {
                            HStack {
                                Label("Model Preference", systemImage: "cpu")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(modelPref)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Helper Methods
    
    private func getUsagePattern(_ session: AccountSession) -> String {
        let avgTokensPerEntry = session.totalTokens / max(1, session.entries.count)
        
        if avgTokensPerEntry < 1000 {
            return "Light usage"
        } else if avgTokensPerEntry < 5000 {
            return "Moderate usage"
        } else if avgTokensPerEntry < 20000 {
            return "Heavy usage"
        } else {
            return "Intensive usage"
        }
    }
    
    private func getRecentActivity(_ session: AccountSession) -> String? {
        let now = Date()
        let timeSinceLastActivity = now.timeIntervalSince(session.lastSeen)
        
        if timeSinceLastActivity < 60 {
            return "Just now"
        } else if timeSinceLastActivity < 300 {
            return "\(Int(timeSinceLastActivity / 60)) min ago"
        } else if timeSinceLastActivity < 3600 {
            return "\(Int(timeSinceLastActivity / 60)) min ago"
        } else if timeSinceLastActivity < 86400 {
            let hours = Int(timeSinceLastActivity / 3600)
            return "\(hours)h ago"
        }
        
        return nil
    }
    
    private func getModelPreference(_ session: AccountSession) -> String? {
        // Parse the fingerprint to get model preference
        let components = session.sessionFingerprint.split(separator: "_")
        if let modelComponent = components.first {
            switch modelComponent {
            case "opus":
                return "Claude 3 Opus"
            case "sonnet":
                return "Claude 3.5 Sonnet"
            case "haiku":
                return "Claude 3 Haiku"
            default:
                return String(modelComponent).capitalized
            }
        }
        return nil
    }
}

// MARK: - Account Session Row

private struct AccountSessionRow: View {
    let session: AccountSession
    let isExpanded: Bool
    let isCurrent: Bool
    let accountName: String?
    let onTap: () -> Void
    let onEditName: (String) -> Void
    
    @State private var isEditingName = false
    @State private var editedName = ""
    
    private var sessionLabel: String {
        if let accountName = accountName, !accountName.isEmpty {
            return accountName
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let timeRange = "\(formatter.string(from: session.firstSeen)) - \(formatter.string(from: session.lastSeen))"
        
        if isCurrent {
            return "Current Session (\(timeRange))"
        } else if session.isActive {
            return "Active Session (\(timeRange))"
        } else {
            return "Session (\(timeRange))"
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Session info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(sessionLabel)
                            .font(.system(size: 13, weight: isCurrent ? .medium : .regular))
                        
                        if session.isActive && !isCurrent {
                            Text("ACTIVE")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text(formatTokenCount(session.totalTokens))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if session.entries.count > 0 {
                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            Text("\(session.entries.count) requests")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Chevron for expansion
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            
            // Expanded details
            if isExpanded {
                Divider()
                    .padding(.leading, 20)
                
                VStack(alignment: .leading, spacing: 6) {
                    DetailRow(label: "Duration", value: formatDuration(session.duration))
                    
                    HStack {
                        DetailRow(label: "Fingerprint", value: formatFingerprint(session.sessionFingerprint))
                        
                        Image(systemName: "questionmark.circle")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .help("A unique pattern based on model preference, usage intensity, project count, and conversation style")
                    }
                    
                    DetailRow(label: "Entries", value: "\(session.entries.count) log entries")
                    
                    if let projects = getUniqueProjects(from: session) {
                        DetailRow(label: "Projects", value: projects)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .font(.caption)
            }
        }
        .background(isCurrent ? Color.accentColor.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private var statusColor: Color {
        if isCurrent {
            return Color.accentColor
        } else if session.isActive {
            return .green
        } else {
            return .gray
        }
    }
    
    private func formatTokenCount(_ tokens: Int) -> String {
        if tokens > 1_000_000 {
            return String(format: "%.1fM tokens", Double(tokens) / 1_000_000)
        } else if tokens > 1000 {
            return "\(tokens / 1000)K tokens"
        } else {
            return "\(tokens) tokens"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatFingerprint(_ fingerprint: String) -> String {
        // Simplify the fingerprint for display
        let components = fingerprint.split(separator: "_")
        if components.count >= 2 {
            return "\(components[0]) / \(components[1])"
        }
        return fingerprint
    }
    
    private func getUniqueProjects(from session: AccountSession) -> String? {
        let projects = session.entries.compactMap(\.projectName)
        let uniqueProjects = Set(projects)
        
        guard !uniqueProjects.isEmpty else { return nil }
        
        if uniqueProjects.count == 1 {
            return uniqueProjects.first
        } else if uniqueProjects.count <= 3 {
            return uniqueProjects.sorted().joined(separator: ", ")
        } else {
            return "\(uniqueProjects.count) projects"
        }
    }
}

// MARK: - Detail Row

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.medium)
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview("Single Account") {
    MultiAccountSessionsView(
        accountSessions: [
            AccountSession(
                id: "session_1",
                entries: [],
                firstSeen: Date().addingTimeInterval(-7200),
                lastSeen: Date(),
                totalTokens: 45_000,
                sessionFingerprint: "opus_high_single_project_long_threads",
                isActive: true
            )
        ],
        currentSessionId: "session_1",
        multiAccountDetector: MultiAccountDetector()
    )
    .frame(width: 300)
    .padding()
}

#Preview("Multiple Accounts") {
    MultiAccountSessionsView(
        accountSessions: [
            AccountSession(
                id: "session_1",
                entries: [],
                firstSeen: Date().addingTimeInterval(-14400),
                lastSeen: Date().addingTimeInterval(-7200),
                totalTokens: 125_000,
                sessionFingerprint: "sonnet_medium_few_projects_medium_threads",
                isActive: false
            ),
            AccountSession(
                id: "session_2",
                entries: [],
                firstSeen: Date().addingTimeInterval(-3600),
                lastSeen: Date(),
                totalTokens: 45_000,
                sessionFingerprint: "opus_high_single_project_long_threads",
                isActive: true
            )
        ],
        currentSessionId: "session_2",
        multiAccountDetector: MultiAccountDetector()
    )
    .frame(width: 300)
    .padding()
}