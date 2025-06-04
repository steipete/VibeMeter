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
        settingsManager: any SettingsManagerProtocol
    ) {
        self.userSession = userSession
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.settingsManager = settingsManager
    }
    
    // MARK: - Public Methods
    
    /// Creates tooltip text for the status bar item.
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
        let keyboardShortcuts = createKeyboardShortcutsInfo()
        
        return [spendingInfo, refreshInfo, keyboardShortcuts].joined(separator: "\n")
    }
    
    // MARK: - Private Methods
    
    private func createSpendingInfo() -> String {
        let totalSpendingUSD = spendingData.totalSpendingConverted(
            to: "USD",
            rates: currencyData.effectiveRates
        )
        let upperLimit = settingsManager.upperLimitUSD
        let percentage = (totalSpendingUSD / upperLimit * 100).rounded()
        
        return "VibeMeter - \(Int(percentage))% of limit"
    }
    
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
    
    private func createKeyboardShortcutsInfo() -> String {
        var shortcuts = "\nKeyboard shortcuts:"
        shortcuts += "\n⌘R - Refresh data"
        shortcuts += "\n⌘, - Open Settings"
        shortcuts += "\n⌘Q - Quit VibeMeter"
        shortcuts += "\nESC - Close menu"
        return shortcuts
    }
}