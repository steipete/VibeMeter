import Foundation

// MARK: - Status Bar Tooltip Provider

/// Provides tooltip text for the status bar item based on current application state.
///
/// This provider creates contextual tooltip information including spending data,
/// refresh status, and keyboard shortcuts for the status bar menu.
final class StatusBarTooltipProvider {
    // MARK: - Properties

    private let userSession: MultiProviderUserSessionData
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private let settingsManager: any SettingsManagerProtocol

    // MARK: - Initialization

    init(
        userSession: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        currencyData: CurrencyData,
        settingsManager: any SettingsManagerProtocol) {
        self.userSession = userSession
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.settingsManager = settingsManager
    }

    // MARK: - Public Methods

    /// Creates tooltip text for the status bar item.
    @MainActor
    func createTooltipText() -> String {
        guard userSession.isLoggedInToAnyProvider else {
            return "VibeMeter - Not logged in to any provider"
        }

        let providers = spendingData.providersWithData
        guard !providers.isEmpty else {
            return "VibeMeter - Loading data..."
        }

        let spendingInfo = createSpendingInfo()
        let refreshInfo = createRefreshInfo(for: providers)

        return [spendingInfo, refreshInfo].joined(separator: "\n")
    }

    // MARK: - Private Methods

    @MainActor
    private func createSpendingInfo() -> String {
        let totalSpendingUSD = spendingData.totalSpendingConverted(
            to: "USD",
            rates: currencyData.effectiveRates)

        if totalSpendingUSD > 0 {
            // Money has been spent - show spending as percentage of limit
            let upperLimit = settingsManager.upperLimitUSD
            let percentage = (totalSpendingUSD / upperLimit * 100).rounded()
            return "VibeMeter - \(Int(percentage))% of spending limit"
        } else {
            // No money spent - show requests used as percentage of available limit
            let requestPercentage = calculateRequestUsagePercentage()
            let percentage = (requestPercentage * 100).rounded()
            return "VibeMeter - \(Int(percentage))% of requests used"
        }
    }

    @MainActor
    private func createRefreshInfo(for providers: [ServiceProvider]) -> String {
        let mostRecentRefresh = providers
            .compactMap { provider in
                spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh
            }
            .max()

        guard let lastRefresh = mostRecentRefresh else {
            return "🔴 Never updated"
        }

        let refreshText = RelativeTimeFormatter.string(from: lastRefresh, style: .withPrefix)
        let freshnessIndicator = RelativeTimeFormatter.isFresh(lastRefresh) ? "🟢" : "🟡"
        var refreshInfo = "\(freshnessIndicator) \(refreshText)"

        // Add data freshness context
        if !RelativeTimeFormatter.isFresh(lastRefresh, withinMinutes: 15) {
            refreshInfo += " (May be outdated)"
        }

        return refreshInfo
    }

    /// Calculates the request usage percentage across all providers
    @MainActor
    private func calculateRequestUsagePercentage() -> Double {
        let providers = spendingData.providersWithData

        // Use same logic as ProviderUsageBadgeView for consistency
        for provider in providers {
            if let providerData = spendingData.getSpendingData(for: provider),
               let usageData = providerData.usageData,
               let maxRequests = usageData.maxRequests, maxRequests > 0 {
                // Calculate percentage using same formula as progress bar
                let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                return progress
            }
        }

        return 0.0
    }
}
