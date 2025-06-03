import SwiftUI

/// Individual row component displaying spending data for a single service provider.
///
/// This view shows provider-specific information including provider name, icon, spending amount,
/// and usage metrics with progress indicators. It supports hover states and provides detailed
/// usage information for request quotas and consumption tracking.
struct ProviderSpendingRowView: View {
    let provider: ServiceProvider
    let loginManager: MultiProviderLoginManager?
    @Binding
    var selectedProvider: ServiceProvider?
    let showTimestamp: Bool

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    init(provider: ServiceProvider, loginManager: MultiProviderLoginManager?, selectedProvider: Binding<ServiceProvider?>, showTimestamp: Bool = true) {
        self.provider = provider
        self.loginManager = loginManager
        self._selectedProvider = selectedProvider
        self.showTimestamp = showTimestamp
    }

    var body: some View {
        VStack(spacing: 1) {
            mainProviderRow

            // Show usage data and optionally last refresh on second line
            HStack {
                // Align with icon column above (20px wide from mainProviderRow)
                Color.clear
                    .frame(width: 20)

                // Usage data badge with extended progress bar
                if let providerData = spendingData.getSpendingData(for: provider),
                   let usage = providerData.usageData,
                   let maxRequests = usage.maxRequests, maxRequests > 0 {
                    usageDataBadge(usage: usage, maxRequests: maxRequests)
                }

                Spacer()

                // Last refresh timestamp (only if enabled)
                if showTimestamp,
                   let providerData = spendingData.getSpendingData(for: provider),
                   let lastRefresh = providerData.lastSuccessfulRefresh {
                    RelativeTimestampView(
                        date: lastRefresh,
                        style: .withPrefix,
                        showFreshnessColor: false)
                        .font(.system(size: 9))
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(minHeight: showTimestamp ? 12 : 16) // Slightly taller when no timestamp
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2) // Reduce vertical padding
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProvider == provider ? Color.white.opacity(0.08) : Color.clear))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProvider = hovering ? provider : nil
            }
        }
        .onTapGesture {
            openProviderDashboard()
        }
    }

    private var mainProviderRow: some View {
        HStack(spacing: 8) {
            // Provider icon with status badge overlay
            ZStack(alignment: .topTrailing) {
                Group {
                    if provider.iconName.contains(".") {
                        // System symbol - use font sizing
                        Image(systemName: provider.iconName)
                            .font(.system(size: 14))
                    } else {
                        // Custom asset - use resizable with explicit sizing
                        Image(provider.iconName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
                .foregroundStyle(provider.accentColor)
                .frame(width: 16, height: 16)

                // Status badge overlay
                if let providerData = spendingData.getSpendingData(for: provider) {
                    ProviderStatusBadge(
                        status: providerData.connectionStatus,
                        size: 10)
                        .offset(x: 4, y: -4)
                }
            }
            .frame(width: 20, height: 16) // Reduce height while keeping width for alignment

            // Provider name
            Text(provider.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            // Amount with consistent number formatting
            Group {
                if let providerData = spendingData.getSpendingData(for: provider),
                   let spendingUSD = providerData.currentSpendingUSD {
                    // Convert using current rates for consistency with total
                    let convertedSpending = currencyData.selectedCode == "USD" ? spendingUSD :
                        ExchangeRateManager.shared.convert(
                            spendingUSD,
                            from: "USD",
                            to: currencyData.selectedCode,
                            rates: currencyData.effectiveRates) ?? spendingUSD

                    Text(
                        "\(currencyData.selectedSymbol)\(convertedSpending.formatted(.number.precision(.fractionLength(2))))")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                } else {
                    Text("--")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func usageDataBadge(usage: ProviderUsageData, maxRequests: Int) -> some View {
        let progress = min(max(Double(usage.currentRequests) / Double(maxRequests), 0.0), 1.0)
        return HStack(spacing: 6) {
            Text("\(usage.currentRequests)/\(maxRequests)")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: ProgressColorHelper.color(for: progress)))
                .frame(width: showTimestamp ? 60 : 80, height: 3) // Extended width, larger when no timestamp
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 1.5))
        }
    }

    // Progress color logic moved to ProgressColorHelper

    private func openProviderDashboard() {
        guard let loginManager,
              let authToken = loginManager.getAuthToken(for: provider) else {
            // Fallback to opening without auth
            BrowserAuthenticationHelper.openURL(provider.dashboardURL)
            return
        }

        // For providers that support authenticated browser sessions,
        // we can create a URL with the session token
        switch provider {
        case .cursor:
            if !BrowserAuthenticationHelper.openCursorDashboardWithAuth(authToken: authToken) {
                // Fallback to opening dashboard without auth
                BrowserAuthenticationHelper.openURL(provider.dashboardURL)
            }
        }
    }
}

/// ServiceProvider extension defining accent colors for UI theming.
///
/// This private extension provides the accent color for each service provider,
/// used for visual consistency in icons and highlights throughout the UI.
private extension ServiceProvider {
    var accentColor: Color {
        switch self {
        case .cursor:
            .blue
        }
    }
}

// MARK: - Preview

#Preview("Provider Spending Row - With Data") {
    @Previewable @State
    var selectedProvider: ServiceProvider?

    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

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

    spendingData.updateUsage(
        for: .cursor,
        from: ProviderUsageData(
            currentRequests: 350,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor))

    return VStack(spacing: 16) {
        ProviderSpendingRowView(
            provider: .cursor,
            loginManager: nil,
            selectedProvider: $selectedProvider,
            showTimestamp: true)
            .environment(spendingData)
            .environment(currencyData)

        Text("Selected: \(selectedProvider?.displayName ?? "None")")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
    .padding()
    .frame(width: 320, height: 100)
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Provider Spending Row - Loading") {
    @Previewable @State
    var selectedProvider: ServiceProvider?

    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

    return ProviderSpendingRowView(
        provider: .cursor,
        loginManager: nil,
        selectedProvider: $selectedProvider,
        showTimestamp: true)
        .environment(spendingData)
        .environment(currencyData)
        .padding()
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
}
