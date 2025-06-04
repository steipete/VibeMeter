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
    @Environment(\.colorScheme)
    private var colorScheme

    init(
        provider: ServiceProvider,
        loginManager: MultiProviderLoginManager?,
        selectedProvider: Binding<ServiceProvider?>,
        showTimestamp: Bool = true) {
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
                ProviderUsageBadgeView(
                    provider: provider,
                    spendingData: spendingData,
                    showTimestamp: showTimestamp)

                Spacer()

                // Last refresh timestamp (only if enabled)
                if showTimestamp,
                   let providerData = spendingData.getSpendingData(for: provider),
                   let lastRefresh = providerData.lastSuccessfulRefresh {
                    RelativeTimestampView(
                        date: lastRefresh,
                        style: .withPrefix,
                        showFreshnessColor: false)
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                }
            }
            .frame(minHeight: showTimestamp ? 12 : 16) // Slightly taller when no timestamp
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2) // Reduce vertical padding
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(selectedProvider == provider ? Color.selectionBackground(for: colorScheme) : Color.clear))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedProvider = hovering ? provider : nil
            }
        }
        .onTapGesture {
            ProviderInteractionHandler.openProviderDashboard(
                for: provider,
                loginManager: loginManager)
        }
        .id(providerRowId)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(providerAccessibilityLabel)
        .accessibilityHint("Double tap to open \(provider.displayName) dashboard")
        .accessibilityAddTraits(.isButton)
    }

    private var mainProviderRow: some View {
        HStack(spacing: 8) {
            // Provider icon with status badge overlay
            ProviderIconView(provider: provider, spendingData: spendingData)

            // Provider name
            Text(provider.displayName)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            // Amount with consistent number formatting
            ProviderSpendingAmountView(
                provider: provider,
                spendingData: spendingData,
                currencyData: currencyData)
        }
    }

    /// Unique identifier for SwiftUI performance optimization
    private var providerRowId: String {
        let providerData = spendingData.getSpendingData(for: provider)
        var hasher = Hasher()
        hasher.combine(provider.rawValue)
        hasher.combine(providerData?.currentSpendingUSD ?? 0)
        hasher.combine(providerData?.lastSuccessfulRefresh?.timeIntervalSince1970 ?? 0)
        hasher.combine(currencyData.selectedCode)
        hasher.combine(selectedProvider == provider)
        hasher.combine(showTimestamp)
        return "\(provider.rawValue)-\(hasher.finalize())"
    }

    /// Accessibility label for the entire provider row
    private var providerAccessibilityLabel: String {
        var components: [String] = [provider.displayName]

        if let providerData = spendingData.getSpendingData(for: provider),
           let spendingUSD = providerData.currentSpendingUSD {
            let convertedSpending = currencyData.selectedCode == "USD" ? spendingUSD :
                ExchangeRateManager.shared.convert(
                    spendingUSD,
                    from: "USD",
                    to: currencyData.selectedCode,
                    rates: currencyData.effectiveRates) ?? spendingUSD
            let formattedSpending = convertedSpending.formatted(.number.precision(.fractionLength(2)))
            let spendingText = "spending \(currencyData.selectedSymbol)\(formattedSpending)"
            components.append(spendingText)
        } else {
            components.append("no spending data")
        }

        return components.joined(separator: ", ")
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
