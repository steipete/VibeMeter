import AppKit
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
                providerRowContent(for: provider)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Provider spending breakdown")
        .accessibilityHint("Lists spending for each connected AI service provider")
    }

    private var totalSpendingSection: some View {
        HStack(alignment: .center) {
            Text("Total Spending")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary.opacity(0.8))

            Spacer()

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
        }
        .standardPadding(vertical: 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.03)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total spending section")
        .accessibilityValue(currentSpendingDisplay ?? "No data available")
    }

    private var spendingLimitsSection: some View {
        HStack(alignment: .center) {
            limitsLabel
            Spacer()
            limitsValues
        }
        .standardPadding(vertical: 10)
        .background(limitsBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Spending limits")
        .accessibilityValue("Warning at \(formattedWarningLimit), upper limit at \(formattedUpperLimit)")
        .accessibilityHint("Configure these limits in settings")
    }

    private var limitsLabel: some View {
        Text("Limits")
            .font(.body.weight(.medium))
            .foregroundStyle(.primary.opacity(0.8))
    }

    private var limitsValues: some View {
        HStack(spacing: 12) {
            warningLimitText
            limitsSeparator
            upperLimitText
        }
    }

    private var warningLimitText: some View {
        Text(formattedWarningLimit)
            .font(.body.weight(.medium))
            .foregroundStyle(.orange)
            .accessibilityLabel("Warning limit: \(formattedWarningLimit)")
    }

    private var limitsSeparator: some View {
        Text("•")
            .font(.body)
            .foregroundStyle(.secondary)
            .accessibilityHidden(true)
    }

    private var upperLimitText: some View {
        Text(formattedUpperLimit)
            .font(.body.weight(.medium))
            .foregroundStyle(.red)
            .accessibilityLabel("Upper limit: \(formattedUpperLimit)")
    }

    private var limitsBackground: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.primary.opacity(0.03))
    }

    // MARK: - Helper Properties

    private var formattedWarningLimit: String {
        "\(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))"
    }

    private var formattedUpperLimit: String {
        "\(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))"
    }

    private var currentSpendingDisplay: String? {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return nil }

        let totalSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates)

        // Format without unnecessary decimals
        if totalSpending == 0 {
            return "\(currencyData.selectedSymbol)0"
        } else {
            let formatter = NumberFormatter.vibeMeterCurrency
            let formattedAmount = formatter.string(from: NSNumber(value: totalSpending)) ?? "0"
            return "\(currencyData.selectedSymbol)\(formattedAmount)"
        }
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

    // MARK: - Helper Views

    @ViewBuilder
    private func providerRowContent(for provider: ServiceProvider) -> some View {
        VStack(spacing: 8) {
            providerHeaderRow(for: provider)
            providerUsageBar(for: provider)
        }
        .standardPadding(vertical: 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.primary.opacity(0.05)))
        .onTapGesture {
            ProviderInteractionHandler.openProviderDashboard(
                for: provider,
                loginManager: loginManager)
        }
        .id({
            let refreshTime = spendingData.getSpendingData(for: provider)?
                .lastSuccessfulRefresh?.timeIntervalSince1970 ?? 0
            return "\(provider.rawValue)-\(refreshTime)-\(currencyData.selectedCode)"
        }())
    }

    @ViewBuilder
    private func providerHeaderRow(for provider: ServiceProvider) -> some View {
        HStack(spacing: 12) {
            ProviderIconView(provider: provider, spendingData: spendingData)
                .frame(width: 20, height: 20)

            Text(provider.displayName)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            ProviderSpendingAmountView(
                provider: provider,
                spendingData: spendingData,
                currencyData: currencyData)
                .font(.body.weight(.medium))
        }
    }

    @ViewBuilder
    private func providerUsageBar(for provider: ServiceProvider) -> some View {
        if provider == .claude {
            // For Claude, show token usage information
            if let providerData = spendingData.getSpendingData(for: provider) {
                VStack(alignment: .leading, spacing: 4) {
                    // Show token counts if available
                    if let pricingDescription = providerData.latestInvoiceResponse?.pricingDescription {
                        // Split the description to show input and output on separate lines
                        let components = pricingDescription.description.components(separatedBy: ", ")
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(components, id: \.self) { component in
                                Text(component)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.leading, 32)
                    }

                    // Show 5-hour window usage for Pro accounts
                    if let usageData = providerData.usageData {
                        HStack(spacing: 8) {
                            Text("5h-window:")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 6)

                                    if let maxRequests = usageData.maxRequests, maxRequests > 0 {
                                        let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(progress > 0.8 ? Color.orange : Color.accentColor)
                                            .frame(width: geometry.size.width * progress, height: 6)
                                    }
                                }
                            }
                            .frame(height: 6)

                            if let maxRequests = usageData.maxRequests, maxRequests > 0 {
                                Text("\(TokenFormatter.format(usageData.currentRequests))/\(TokenFormatter.format(maxRequests))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                        }
                        .padding(.leading, 32)
                    }

                    // Add button to view detailed usage report if we have access
                    if ClaudeLogManager.shared.hasAccess {
                        HStack {
                            Button(action: {
                                ClaudeUsageReportWindowController.showWindow()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.doc.horizontal")
                                        .font(.caption)
                                    Text("View Token Report")
                                        .font(.caption)
                                }
                                .foregroundStyle(.link)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 32)
                            .padding(.top, 4)
                        }
                    }
                }
            }
        } else if let providerData = spendingData.getSpendingData(for: provider),
                  let usageData = providerData.usageData,
                  let maxRequests = usageData.maxRequests {
            // Original implementation for other providers
            HStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)

                        let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(progress > 0.8 ? Color.orange : Color.accentColor)
                            .frame(width: geometry.size.width * progress, height: 6)
                    }
                }
                .frame(height: 6)

                Text("\(usageData.currentRequests)/\(maxRequests)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }
            .padding(.leading, 32)
        }
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
