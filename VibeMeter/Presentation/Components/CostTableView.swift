import SwiftUI

/// Component that displays spending data in a structured table format.
///
/// This view presents total spending, provider breakdown, and spending limits in organized
/// sections with proper visual hierarchy. It includes currency conversion, progress indicators,
/// and spending threshold warnings with color-coded visual feedback.
struct CostTableView: View {
    let settingsManager: any SettingsManagerProtocol
    let loginManager: MultiProviderLoginManager?

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    @State
    private var selectedProvider: ServiceProvider?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            totalSpendingSection

            if !spendingData.providersWithData.isEmpty {
                providerBreakdownSection
            }

            spendingLimitsSection
        }
    }

    private var totalSpendingSection: some View {
        HStack(alignment: .center) {
            Text("Total Spending")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if let totalSpending = currentSpendingDisplay {
                Text(totalSpending)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } else {
                Text("No data")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thickMaterial))
    }

    private var providerBreakdownSection: some View {
        VStack(spacing: 0) {
            ForEach(spendingData.providersWithData, id: \.self) { provider in
                ProviderSpendingRowView(
                    provider: provider,
                    loginManager: loginManager,
                    selectedProvider: $selectedProvider)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thickMaterial))
    }

    private var spendingLimitsSection: some View {
        HStack(alignment: .center) {
            Text("Limits")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(
                "\(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.orange)

            Text("•")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Text(
                "\(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.thickMaterial))
    }

    // MARK: - Helper Properties

    private var currentSpendingDisplay: String? {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return nil }

        let totalSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates)

        return "\(currencyData.selectedSymbol)\(totalSpending.formatted(.number.precision(.fractionLength(2))))"
    }

    private var convertedWarningLimit: Double {
        currencyData.convertAmount(
            settingsManager.warningLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.warningLimitUSD
    }

    private var convertedUpperLimit: Double {
        currencyData.convertAmount(
            settingsManager.upperLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.upperLimitUSD
    }
}

// MARK: - Preview

#Preview {
    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

    // Add sample data
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 1997, description: "Pro Usage", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025),
        rates: [:],
        targetCurrency: "EUR")

    spendingData.updateUsage(
        for: .cursor,
        from: ProviderUsageData(
            currentRequests: 1535,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor))

    return CostTableView(
        settingsManager: MockSettingsManager(),
        loginManager: nil)
        .environment(spendingData)
        .environment(currencyData)
        .padding()
        .frame(width: 280)
        .background(Color(NSColor.windowBackgroundColor))
}

// MARK: - Mock Settings Manager

@MainActor
private class MockSettingsManager: SettingsManagerProtocol {
    var providerSessions: [ServiceProvider: ProviderSession] = [:]
    var selectedCurrencyCode: String = "EUR"
    var warningLimitUSD: Double = 200
    var upperLimitUSD: Double = 1000
    var refreshIntervalMinutes: Int = 5
    var launchAtLoginEnabled: Bool = false
    var showCostInMenuBar: Bool = true
    var showInDock: Bool = false
    var enabledProviders: Set<ServiceProvider> = [.cursor]

    func clearUserSessionData() {}
    func clearUserSessionData(for _: ServiceProvider) {}
    func getSession(for _: ServiceProvider) -> ProviderSession? { nil }
    func updateSession(for _: ServiceProvider, session _: ProviderSession) {}
}
