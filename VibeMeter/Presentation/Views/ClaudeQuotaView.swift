import AppKit
import SwiftUI

/// Displays Claude's 5-hour window quota usage
struct ClaudeQuotaView: View {
    @State
    private var fiveHourWindow: FiveHourWindow?
    @State
    private var isLoading = true
    @State
    private var error: Error?

    @State
    private var provider: ClaudeProvider?

    private func getProvider() -> ClaudeProvider {
        if let provider {
            return provider
        }
        let newProvider = ClaudeProvider(settingsManager: SettingsManager.shared)
        self.provider = newProvider
        return newProvider
    }

    // Timer removed in favor of onLegacyTimer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("Claude 5-Hour Window", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                // Info button to show usage report
                Button(action: {
                    openUsageReport()
                }) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("View detailed token usage report")

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            // Content
            if let window = fiveHourWindow {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .frame(height: 20)

                        // Progress
                        RoundedRectangle(cornerRadius: 6)
                            .fill(progressColor(for: window))
                            .frame(
                                width: geometry.size.width * (window.percentageUsed / 100),
                                height: 20)
                            .animation(.smooth(duration: 0.3), value: window.percentageUsed)
                    }
                }
                .frame(height: 20)

                // Stats
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Used")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(window.percentageUsed))%")
                            .font(.body.monospacedDigit())
                            .fontWeight(.medium)
                    }

                    Spacer()

                    VStack(alignment: .center, spacing: 2) {
                        Text("Remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(window.percentageRemaining))%")
                            .font(.body.monospacedDigit())
                            .fontWeight(.medium)
                            .foregroundStyle(progressColor(for: window))
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Resets in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timeUntilReset(window.resetDate))
                            .font(.body.monospacedDigit())
                            .fontWeight(.medium)
                    }
                }

                // Warning if quota is low
                if window.percentageUsed > 80 {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Text(quotaWarningMessage(for: window))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else if let error {
                // Error state
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.secondary)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 8)
            }
        }
        .task {
            await loadQuotaData()
        }
        .task {
            // Refresh data every 60 seconds
            for await _ in AsyncTimerSequence.seconds(60) {
                await loadQuotaData()
            }
        }
    }

    private func openUsageReport() {
        ClaudeUsageReportWindowController.showWindow()
    }

    // MARK: - Helper Methods

    private func loadQuotaData() async {
        do {
            let window = try await getProvider().getFiveHourWindowUsage()
            await MainActor.run {
                self.fiveHourWindow = window
                self.isLoading = false
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }

    private func progressColor(for window: FiveHourWindow) -> Color {
        switch window.percentageUsed {
        case 0 ..< 50:
            .green
        case 50 ..< 80:
            .orange
        default:
            .red
        }
    }

    private func timeUntilReset(_ resetDate: Date) -> String {
        let interval = resetDate.timeIntervalSince(Date())
        guard interval > 0 else { return "Now" }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func quotaWarningMessage(for window: FiveHourWindow) -> String {
        if window.isExhausted {
            "Quota exhausted. Please wait for reset."
        } else if window.percentageUsed > 90 {
            "Almost out of quota for this window."
        } else {
            "Running low on quota for this window."
        }
    }
}

// MARK: - Preview

#Preview {
    ClaudeQuotaView()
        .frame(width: 300)
        .padding()
}
