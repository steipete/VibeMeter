import Foundation

// MARK: - Status Bar Accessibility Provider

/// Provides accessibility descriptions for the status bar item.
///
/// This provider creates detailed accessibility information that helps
/// screen readers and assistive technologies understand the current state.
final class StatusBarAccessibilityProvider {
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

    /// Creates accessibility description for the status bar item.
    @MainActor
    func createAccessibilityDescription() -> String {
        guard userSession.isLoggedInToAnyProvider else {
            return "Not logged in to any AI service provider. Click to open VibeMeter and log in."
        }

        let providers = spendingData.providersWithData
        guard !providers.isEmpty else {
            return "Loading AI service spending data. Please wait."
        }

        let spendingInfo = createSpendingAccessibilityInfo()
        let refreshInfo = createRefreshAccessibilityInfo(for: providers)

        return "\(spendingInfo) \(refreshInfo) Click to view details."
    }

    // MARK: - Private Methods

    @MainActor
    private func createSpendingAccessibilityInfo() -> String {
        let totalSpendingUSD = spendingData.totalSpendingConverted(
            to: "USD",
            rates: currencyData.effectiveRates)
        let upperLimit = settingsManager.upperLimitUSD
        let percentage = (totalSpendingUSD / upperLimit * 100).rounded()

        let userSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates)
        let userLimit = settingsManager.upperLimitUSD * currencyData.effectiveRates[
            currencyData.selectedCode,
            default: 1.0
        ]

        let spendingText =
            "\(currencyData.selectedSymbol)\(userSpending.formatted(.number.precision(.fractionLength(2))))"
        let limitText = "\(currencyData.selectedSymbol)\(userLimit.formatted(.number.precision(.fractionLength(2))))"

        let statusText = determineStatusText(for: percentage)

        let percentageText = "\(Int(percentage)) percent used"
        return "\(statusText). Current spending: \(spendingText) of \(limitText) limit. \(percentageText)."
    }

    private func determineStatusText(for percentage: Double) -> String {
        switch percentage {
        case 0 ..< 50:
            "Low usage"
        case 50 ..< 80:
            "Moderate usage"
        case 80 ..< 100:
            "High usage, approaching limit"
        default:
            "Over limit"
        }
    }

    @MainActor
    private func createRefreshAccessibilityInfo(for providers: [ServiceProvider]) -> String {
        let mostRecentRefresh = providers
            .compactMap { provider in
                spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh
            }
            .max()

        guard let lastRefresh = mostRecentRefresh else {
            return "Data never updated."
        }

        let refreshText = RelativeTimeFormatter.string(from: lastRefresh, style: .medium)
        return "Data \(refreshText)."
    }
}
