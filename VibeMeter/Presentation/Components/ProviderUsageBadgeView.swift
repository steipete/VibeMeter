import SwiftUI

/// A badge view that displays usage information for a provider.
///
/// This component shows request usage as a progress bar with text indicating
/// current and maximum requests. It adapts to show loading states and handles
/// cases where usage data is not available.
struct ProviderUsageBadgeView: View {
    let provider: ServiceProvider
    let spendingData: MultiProviderSpendingData
    let showTimestamp: Bool

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        if let providerData = spendingData.getSpendingData(for: provider),
           let usageData = providerData.usageData,
           let maxRequests = usageData.maxRequests {
            HStack(spacing: 6) {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        // Progress fill
                        let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor(for: progress))
                            .frame(width: geometry.size.width * progress, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(width: 60, height: 4)

                // Usage text
                Text("\(usageData.currentRequests)/\(maxRequests)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("\(usageData.currentRequests) of \(maxRequests) requests used")

                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Usage: \(usageData.currentRequests) of \(maxRequests) requests")
            .accessibilityValue("\(Int((Double(usageData.currentRequests) / Double(maxRequests)) * 100))% used")
        } else if let providerData = spendingData.getSpendingData(for: provider),
                  providerData.connectionStatus == .connecting || providerData.connectionStatus == .syncing {
            // Loading state
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)

                Text("Loading usage...")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        } else {
            // No usage data available
            EmptyView()
        }
    }

    private func progressColor(for progress: Double) -> Color {
        switch progress {
        case 0 ..< 0.5:
            .accentColor
        case 0.5 ..< 0.8:
            .orange
        default:
            .red
        }
    }
}

// MARK: - Preview

#Preview("Provider Usage Badge") {
    let spendingData = MultiProviderSpendingData()

    // Add sample data
    spendingData.updateUsage(
        for: .cursor,
        from: ProviderUsageData(
            currentRequests: 350,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor))

    return VStack(spacing: 16) {
        // Normal usage
        ProviderUsageBadgeView(
            provider: .cursor,
            spendingData: spendingData,
            showTimestamp: true)

        // Update for high usage
        Button("Set High Usage") {
            spendingData.updateUsage(
                for: .cursor,
                from: ProviderUsageData(
                    currentRequests: 480,
                    totalRequests: 4387,
                    maxRequests: 500,
                    startOfMonth: Date(),
                    provider: .cursor))
        }
    }
    .padding()
    .frame(width: 250, height: 100)
    .background(Color(NSColor.windowBackgroundColor))
}
