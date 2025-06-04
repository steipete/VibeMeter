import SwiftUI

/// Component that displays spending data in a structured table format.
///
/// This view presents provider details, total spending, and spending limits in organized
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
        VStack(alignment: .leading, spacing: 8) {
            // Provider breakdown at the top
            if !spendingData.providersWithData.isEmpty {
                providerBreakdownSection
            }

            // Total spending in the middle
            totalSpendingSection

            // Spending limits at the bottom
            spendingLimitsSection
        }
        .id("cost-table-\(spendingData.providersWithData.count)-\(currencyData.selectedCode)-\(totalSpendingHash)")
    }

    private var providerBreakdownSection: some View {
        VStack(spacing: 4) {
            ForEach(spendingData.providersWithData, id: \.self) { provider in
                VStack(spacing: 8) {
                    // Top row: Icon, provider name, and amount
                    HStack(spacing: 12) {
                        // Provider icon on the left
                        ProviderIconView(provider: provider, spendingData: spendingData)
                            .frame(width: 20, height: 20)

                        // Provider name
                        Text(provider.displayName)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Spacer()

                        // Amount on the right
                        ProviderSpendingAmountView(
                            provider: provider,
                            spendingData: spendingData,
                            currencyData: currencyData)
                            .font(.body.weight(.medium))
                    }

                    // Usage bar with text on the same line
                    if let providerData = spendingData.getSpendingData(for: provider),
                       let usageData = providerData.usageData,
                       let maxRequests = usageData.maxRequests {
                        HStack(spacing: 8) {
                            // Progress bar
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    // Background track
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 6)

                                    // Progress fill
                                    let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(progress > 0.8 ? Color.orange : Color.accentColor)
                                        .frame(width: geometry.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)

                            // Usage text on the same line
                            Text("\(usageData.currentRequests)/\(maxRequests)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                        }
                        .padding(.leading, 32) // Align with text above (icon width + spacing)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05)))
                .onTapGesture {
                    ProviderInteractionHandler.openProviderDashboard(
                        for: provider,
                        loginManager: loginManager)
                }
                .id(
                    "\(provider.rawValue)-\(spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh?.timeIntervalSince1970 ?? 0)-\(currencyData.selectedCode)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider spending breakdown")
        .accessibilityHint("Lists spending for each connected AI service provider")
    }

    private var totalSpendingSection: some View {
        HStack(alignment: .center) {
            Spacer()

            Text("Total Spending")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary.opacity(0.8))

            Spacer(minLength: 20)

            if let totalSpending = currentSpendingDisplay {
                Text(totalSpending)
                    .font(.title2.weight(.semibold).monospaced())
                    .foregroundStyle(.primary)
                    .accessibilityLabel("Total spending: \(totalSpending)")
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.3), value: totalSpending)
            } else if isLoadingData {
                // Show shimmer while data is loading
                ShimmerShapes.totalSpending
            } else {
                Text("No data")
                    .font(.body)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("No spending data available")
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total spending section")
        .accessibilityValue(currentSpendingDisplay ?? "No data available")
    }

    private var spendingLimitsSection: some View {
        HStack(alignment: .center) {
            Spacer()

            Text("Limits")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary.opacity(0.8))

            Spacer(minLength: 20)

            HStack(spacing: 12) {
                Text(
                    "\(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.orange)
                    .accessibilityLabel(
                        "Warning limit: \(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))")

                Text("•")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(
                    "\(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.red)
                    .accessibilityLabel(
                        "Upper limit: \(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03)))
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

    /// Determines if any provider is currently loading data
    private var isLoadingData: Bool {
        spendingData.providersWithData.contains { provider in
            if let providerData = spendingData.getSpendingData(for: provider) {
                return providerData.connectionStatus == .connecting || providerData.connectionStatus == .syncing
            }
            return false
        }
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
