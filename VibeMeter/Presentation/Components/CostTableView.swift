import SwiftUI

/// Component that displays spending data in a structured table format.
///
/// This view presents total spending, provider breakdown, and spending limits in organized
/// sections with proper visual hierarchy. It includes currency conversion, progress indicators,
/// and spending threshold warnings with color-coded visual feedback.
struct CostTableView: View {
    let settingsManager: any SettingsManagerProtocol
    let loginManager: MultiProviderLoginManager?
    let showTimestamps: Bool

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    @State
    private var selectedProvider: ServiceProvider?

    init(
        settingsManager: any SettingsManagerProtocol,
        loginManager: MultiProviderLoginManager?,
        showTimestamps: Bool = true) {
        self.settingsManager = settingsManager
        self.loginManager = loginManager
        self.showTimestamps = showTimestamps
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            totalSpendingSection

            if !spendingData.providersWithData.isEmpty {
                providerBreakdownSection
            }

            spendingLimitsSection
        }
        .id("cost-table-\(spendingData.providersWithData.count)-\(currencyData.selectedCode)-\(totalSpendingHash)")
    }

    private var totalSpendingSection: some View {
        HStack(alignment: .center) {
            Text("Total Spending")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            if let totalSpending = currentSpendingDisplay {
                Text(totalSpending)
                    .font(.title.weight(.semibold).monospaced())
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Total spending: \(totalSpending)")
            } else {
                Text("No data")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("No spending data available")
            }
        }
        .standardPadding(horizontal: 12, vertical: 8)
        .materialBackground(cornerRadius: 10, material: .thickMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total spending section")
        .accessibilityValue(currentSpendingDisplay ?? "No data available")
    }

    private var providerBreakdownSection: some View {
        VStack(spacing: 0) {
            ForEach(spendingData.providersWithData, id: \.self) { provider in
                ProviderSpendingRowView(
                    provider: provider,
                    loginManager: loginManager,
                    selectedProvider: $selectedProvider,
                    showTimestamp: showTimestamps)
                    .id(
                        "\(provider.rawValue)-\(spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh?.timeIntervalSince1970 ?? 0)-\(currencyData.selectedCode)")
            }
        }
        .standardPadding(horizontal: 3, vertical: 3)
        .materialBackground(cornerRadius: 10, material: .thickMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider spending breakdown")
        .accessibilityHint("Lists spending for each connected AI service provider")
    }

    private var spendingLimitsSection: some View {
        HStack(alignment: .center) {
            Text("Limits")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text(
                "\(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.orange)
                .accessibilityLabel(
                    "Warning limit: \(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))")

            Text("•")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .accessibilityHidden(true)

            Text(
                "\(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .accessibilityLabel(
                    "Upper limit: \(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
        }
        .standardPadding(horizontal: 12, vertical: 8)
        .materialBackground(cornerRadius: 10, material: .thickMaterial)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spending limits")
        .accessibilityValue(
            "Warning at \(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0)))), upper limit at \(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
        .accessibilityHint("Configure these limits in settings")
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

    /// Hash for total spending state to optimize SwiftUI performance
    private var totalSpendingHash: Int {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return 0 }

        let totalSpending = spendingData.totalSpendingConverted(
            to: "USD", // Use USD for consistency
            rates: currencyData.effectiveRates)

        // Create hash from key spending values that affect display
        var hasher = Hasher()
        hasher.combine(totalSpending)
        hasher.combine(settingsManager.warningLimitUSD)
        hasher.combine(settingsManager.upperLimitUSD)
        hasher.combine(providers.count)
        return hasher.finalize()
    }
}

// MARK: - Preview

#Preview {
    let spendingData = PreviewData.mockSpendingData(cents: 1997, currentRequests: 1535, maxRequests: 500)

    return CostTableView(
        settingsManager: MockServices.settingsManager(currency: "EUR"),
        loginManager: nil,
        showTimestamps: true)
        .withSpendingEnvironment(spendingData)
        .componentFrame(width: 280)
        .previewBackground()
        .padding()
}
