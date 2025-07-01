import SwiftUI

/// Displays detailed Claude session information with cost tracking
struct ClaudeSessionDetailView: View {
    @State private var sessionTracking: ClaudeSessionTracker.SessionTracking?
    @State private var sessionProgress: (windowProgress: Double, sessionProgress: Double, efficiency: Double)?
    @State private var isLoading = true
    @State private var error: Error?
    
    @Environment(\.dismiss) private var dismiss
    
    private let sessionTracker = ClaudeSessionTracker()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if isLoading {
                ProgressView("Loading session data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ErrorView(error: error) {
                    Task { await loadData() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let tracking = sessionTracking {
                ScrollView {
                    VStack(spacing: 20) {
                        // Current Window Overview
                        currentWindowCard(tracking)
                        
                        // Active Session Details
                        if let currentSession = tracking.currentSession {
                            activeSessionCard(currentSession)
                        }
                        
                        // Session Statistics
                        sessionStatisticsCard(tracking)
                        
                        // Recent Sessions List
                        recentSessionsList(tracking)
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView(
                    "No Session Data",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("No active Claude sessions found")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 600)
        .task {
            await loadData()
            startTimer()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Claude Session Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let progress = sessionProgress {
                    Text("Window: \(Int(progress.windowProgress))% • Efficiency: \(Int(progress.efficiency)) tokens/min")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private func currentWindowCard(_ tracking: ClaudeSessionTracker.SessionTracking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current 5-Hour Window", systemImage: "timer")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(
                    title: "Sessions",
                    value: "\(tracking.sessionsInWindow)",
                    icon: "square.stack.3d.up"
                )
                
                StatItem(
                    title: "Total Tokens",
                    value: TokenFormatter.format(tracking.activeWindow.totalTokens),
                    icon: "character.cursor.ibeam"
                )
                
                StatItem(
                    title: "Total Cost",
                    value: tracking.activeWindow.totalCost.formattedCurrency,
                    icon: "dollarsign.circle"
                )
                
                if let progress = sessionProgress {
                    StatItem(
                        title: "Window Progress",
                        value: "\(Int(progress.windowProgress))%",
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
            }
            
            // Window time info
            HStack {
                Label(tracking.activeWindow.startTime.formatted(.dateTime.hour().minute()), systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Label(tracking.activeWindow.endTime.formatted(.dateTime.hour().minute()), systemImage: "clock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func activeSessionCard(_ session: ClaudeSessionTracker.Session) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Active Session", systemImage: "bolt.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                
                Spacer()
                
                // Live indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                        .animation(.easeInOut(duration: 1).repeatForever(), value: true)
                    
                    Text("LIVE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
            }
            
            HStack(spacing: 20) {
                StatItem(
                    title: "Duration",
                    value: formatDuration(session.duration),
                    icon: "timer"
                )
                
                StatItem(
                    title: "Tokens Used",
                    value: TokenFormatter.format(session.totalTokens),
                    icon: "character.cursor.ibeam"
                )
                
                StatItem(
                    title: "Session Cost",
                    value: session.totalCost.formattedCurrency,
                    icon: "dollarsign.circle.fill"
                )
                
                if session.models.count == 1 {
                    StatItem(
                        title: "Model",
                        value: formatModelName(session.models.first ?? ""),
                        icon: "cpu"
                    )
                }
            }
            
            // Progress bar
            if let progress = sessionProgress {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Session Progress")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("Ends at \(session.expectedEndTime, format: .dateTime.hour().minute())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    ProgressView(value: progress.sessionProgress / 100)
                        .progressViewStyle(.linear)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func sessionStatisticsCard(_ tracking: ClaudeSessionTracker.SessionTracking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Session Statistics", systemImage: "chart.bar.xaxis")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(
                    title: "Avg Session",
                    value: formatDuration(tracking.averageSessionLength),
                    icon: "clock.arrow.2.circlepath"
                )
                
                StatItem(
                    title: "Cost/Session",
                    value: tracking.sessionsInWindow > 0 
                        ? (tracking.totalCostInWindow / Double(tracking.sessionsInWindow)).formattedCurrency
                        : "$0.00",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                if let efficiency = sessionProgress?.efficiency {
                    StatItem(
                        title: "Efficiency",
                        value: "\(Int(efficiency)) tok/min",
                        icon: "speedometer"
                    )
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func recentSessionsList(_ tracking: ClaudeSessionTracker.SessionTracking) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Sessions", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            
            if tracking.recentSessions.isEmpty {
                Text("No recent sessions")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(tracking.recentSessions, id: \.id) { session in
                        SessionRow(session: session)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Actions
    
    private func loadData() async {
        isLoading = true
        error = nil
        
        // Load session tracking data
        let tracking = await MainActor.run {
            sessionTracker.getSessionTracking()
        }
        
        let progress = await MainActor.run {
            sessionTracker.getSessionProgress()
        }
        
        await MainActor.run {
            self.sessionTracking = tracking
            self.sessionProgress = progress
            self.isLoading = false
        }
    }
    
    private func startTimer() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await loadData()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatModelName(_ model: String) -> String {
        if model.contains("sonnet") {
            return "Sonnet"
        } else if model.contains("opus") {
            return "Opus"
        } else if model.contains("haiku") {
            return "Haiku"
        } else {
            return model.components(separatedBy: "-").last ?? model
        }
    }
}

// MARK: - Supporting Views

private struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

private struct SessionRow: View {
    let session: ClaudeSessionTracker.Session
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(session.startTime, format: .dateTime.hour().minute())
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    if session.isActive {
                        Label("Active", systemImage: "bolt.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                
                Text("\(session.entryCount) entries • \(formatDuration(session.duration))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(session.totalCost.formattedCurrency)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(TokenFormatter.format(session.totalTokens))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        return "\(minutes)m"
    }
}

private struct ErrorView: View {
    let error: Error
    let retry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Failed to Load Session Data")
                .font(.headline)
            
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            
            Button("Retry", action: retry)
                .buttonStyle(.bordered)
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct ClaudeSessionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ClaudeSessionDetailView()
    }
}
#endif