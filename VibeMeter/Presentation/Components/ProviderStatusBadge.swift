import SwiftUI

/// Visual badge component displaying provider connection status.
///
/// This component shows a colored icon with optional animation for active states,
/// providing immediate visual feedback about the provider's connection health.
struct ProviderStatusBadge: View {
    let status: ProviderConnectionStatus
    let size: CGFloat

    @State
    private var isAnimating = false

    var body: some View {
        ZStack {
            // Background circle with subtle color
            Circle()
                .fill(status.displayColor.opacity(0.15))
                .frame(width: size, height: size)

            // Status icon
            Image(systemName: status.iconName)
                .font(.system(size: size * 0.55, weight: .medium, design: .rounded))
                .foregroundStyle(status.displayColor)
                .symbolEffect(
                    .pulse.byLayer,
                    options: .repeating,
                    isActive: status.isActive)
        }
        .help(status.description + (status.isActive ? "" : " (⌘R to refresh)")) // Tooltip on hover
        .accessibilityLabel("Status: \(status.description)")
        .accessibilityValue(status.isActive ? "Active" : "Inactive")
        .onAppear {
            isAnimating = status.isActive
        }
        .onChange(of: status) { _, newStatus in
            withAnimation(.easeInOut(duration: 0.3)) {
                isAnimating = newStatus.isActive
            }
        }
    }
}

/// Larger status indicator with text for detailed views.
struct ProviderStatusIndicator: View {
    let status: ProviderConnectionStatus
    let showText: Bool

    var body: some View {
        HStack(spacing: 6) {
            ProviderStatusBadge(status: status, size: 16)

            if showText {
                Text(status.shortDescription)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(status.displayColor)
            }
        }
        .padding(.horizontal, showText ? 8 : 0)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.displayColor.opacity(0.1))
                .opacity(showText ? 1 : 0))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Provider status: \(status.description)")
        .accessibilityValue(status.isActive ? "Active" : "Inactive")
    }
}

/// Menu bar status dot indicator for overall system status.
struct MenuBarStatusDot: View {
    let status: ProviderConnectionStatus

    var body: some View {
        if status.isError {
            Circle()
                .fill(status.displayColor)
                .frame(width: 5, height: 5)
                .shadow(color: status.displayColor.opacity(0.6), radius: 2)
                .accessibilityLabel("Error indicator")
                .accessibilityHint("Connection error detected")
        }
    }
}

// MARK: - Previews

#Preview("Status Badges") {
    VStack(spacing: 20) {
        // Small badges
        HStack(spacing: 20) {
            ForEach(previewStatuses, id: \.0) { name, status in
                VStack {
                    ProviderStatusBadge(status: status, size: 20)
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Divider()

        // Large indicators with text
        VStack(alignment: .leading, spacing: 12) {
            ForEach(previewStatuses, id: \.0) { _, status in
                ProviderStatusIndicator(status: status, showText: true)
            }
        }
    }
    .padding(40)
    .background(Color(NSColor.windowBackgroundColor))
}

private let previewStatuses: [(String, ProviderConnectionStatus)] = [
    ("Disconnected", .disconnected),
    ("Connecting", .connecting),
    ("Connected", .connected),
    ("Syncing", .syncing),
    ("Error", .error(message: "Connection failed")),
    ("Rate Limited", .rateLimited(until: Date(timeIntervalSinceNow: 3600))),
    ("Stale", .stale),
]
