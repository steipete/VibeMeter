import SwiftUI

/// Displays usage data with progress bar for a provider.
///
/// This view shows current usage statistics with an animated progress bar
/// and handles loading states with shimmer effects.
struct ProviderUsageBadgeView: View {
    let provider: ServiceProvider
    let spendingData: MultiProviderSpendingData
    let showTimestamp: Bool
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        if let providerData = spendingData.getSpendingData(for: provider) {
            if let usage = providerData.usageData,
               let maxRequests = usage.maxRequests, maxRequests > 0 {
                usageDataBadge(usage: usage, maxRequests: maxRequests)
            } else if providerData.connectionStatus == .connecting || providerData.connectionStatus == .syncing {
                // Show shimmer for usage data while loading
                usageDataShimmer()
            }
        }
    }

    private func usageDataShimmer() -> some View {
        HStack(spacing: 6) {
            // Usage text shimmer
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 45, height: 12)
                .shimmer()

            // Progress bar shimmer
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: showTimestamp ? 60 : 80, height: 3)
                .shimmer()
        }
        .accessibilityLabel("Loading usage data")
    }

    private func usageDataBadge(usage: ProviderUsageData, maxRequests: Int) -> some View {
        let progress = min(max(Double(usage.currentRequests) / Double(maxRequests), 0.0), 1.0)
        let progressPercentage = Int((progress * 100).rounded())
        return HStack(spacing: 6) {
            Text("\(usage.currentRequests)/\(maxRequests)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Usage: \(usage.currentRequests) of \(maxRequests) requests")
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.3), value: usage.currentRequests)

            CustomProgressBar(
                progress: progress,
                progressColor: Color.progressColor(for: progress, colorScheme: colorScheme),
                backgroundColor: Color.gaugeBackground(for: colorScheme))
                .frame(width: showTimestamp ? 60 : 80, height: 3) // Extended width, larger when no timestamp
                .accessibilityLabel("Usage progress: \(progressPercentage) percent")
                .accessibilityValue("\(usage.currentRequests) requests used out of \(maxRequests) allowed")
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .animation(.easeOut(duration: 0.3), value: progress)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Custom progress bar that works with drawingGroup() by using Canvas instead of NSProgressIndicator
private struct CustomProgressBar: View {
    let progress: Double
    let progressColor: Color
    let backgroundColor: Color

    @State
    private var animatedProgress: Double = 0

    var body: some View {
        Canvas { context, size in
            let cornerRadius: CGFloat = 1.5
            let backgroundRect = CGRect(origin: .zero, size: size)
            let progressWidth = size.width * animatedProgress
            let progressRect = CGRect(x: 0, y: 0, width: progressWidth, height: size.height)

            // Draw background
            context.fill(
                Path(roundedRect: backgroundRect, cornerRadius: cornerRadius),
                with: .color(backgroundColor))

            // Draw progress fill
            if animatedProgress > 0 {
                context.fill(
                    Path(roundedRect: progressRect, cornerRadius: cornerRadius),
                    with: .color(progressColor))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeOut(duration: 0.3)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Preview

#Preview("With Usage Data") {
    let spendingData = MultiProviderSpendingData()

    // Add sample usage data
    spendingData.updateUsage(
        for: .cursor,
        from: ProviderUsageData(
            currentRequests: 350,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor))

    return VStack(spacing: 16) {
        ProviderUsageBadgeView(
            provider: .cursor,
            spendingData: spendingData,
            showTimestamp: true)

        ProviderUsageBadgeView(
            provider: .cursor,
            spendingData: spendingData,
            showTimestamp: false)
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Loading") {
    let spendingData = MultiProviderSpendingData()

    return ProviderUsageBadgeView(
        provider: .cursor,
        spendingData: spendingData,
        showTimestamp: true)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
}
