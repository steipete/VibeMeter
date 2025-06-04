import SwiftUI

/// A view that displays the icon for a service provider.
///
/// This component provides a consistent way to display provider icons throughout the app,
/// with support for status indicators and proper sizing. It uses the provider's asset
/// image when available, or falls back to a text-based icon.
struct ProviderIconView: View {
    let provider: ServiceProvider
    let spendingData: MultiProviderSpendingData
    var showStatusBadge: Bool = true

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Provider icon
            if provider == .cursor {
                Image(asset: VibeMeterAsset.cursor)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            } else {
                // Fallback for future providers
                Image(systemName: "cpu")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
            }

            // Connection status indicator
            if showStatusBadge,
               let providerData = spendingData.getSpendingData(for: provider) {
                connectionStatusIndicator(for: providerData.connectionStatus)
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(provider.displayName) icon")
    }

    @ViewBuilder
    private func connectionStatusIndicator(for status: ProviderConnectionStatus) -> some View {
        switch status {
        case .connected:
            Circle()
                .fill(Color.green)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.windowBackground(for: colorScheme), lineWidth: 1))
        case .connecting, .syncing:
            Circle()
                .fill(Color.orange)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.windowBackground(for: colorScheme), lineWidth: 1))
                .transition(.scale.combined(with: .opacity))
        case .error:
            Circle()
                .fill(Color.red)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.windowBackground(for: colorScheme), lineWidth: 1))
        case .rateLimited:
            Circle()
                .fill(Color.orange)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.windowBackground(for: colorScheme), lineWidth: 1))
        case .stale:
            Circle()
                .fill(Color.yellow)
                .frame(width: 6, height: 6)
                .overlay(Circle().stroke(Color.windowBackground(for: colorScheme), lineWidth: 1))
        case .disconnected:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Provider Icon View") {
    let spendingData = MultiProviderSpendingData()

    // Add sample data
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 2497, description: "Pro Usage", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025),
        rates: [:],
        targetCurrency: "USD")

    return HStack(spacing: 20) {
        VStack {
            ProviderIconView(provider: .cursor, spendingData: spendingData)
            Text("Connected")
                .font(.caption)
        }

        VStack {
            ProviderIconView(provider: .cursor, spendingData: spendingData, showStatusBadge: false)
            Text("No Badge")
                .font(.caption)
        }
    }
    .padding()
    .frame(width: 200, height: 100)
    .background(Color(NSColor.windowBackgroundColor))
}
