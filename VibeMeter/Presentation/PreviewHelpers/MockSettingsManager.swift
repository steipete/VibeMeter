import SwiftUI

/// Mock implementation of SettingsManagerProtocol for SwiftUI previews.
///
/// This mock provides a non-persistent, in-memory implementation of the settings manager
/// for use in SwiftUI previews and testing scenarios. It includes default values
/// suitable for preview demonstrations.
@MainActor
public class MockSettingsManager: SettingsManagerProtocol {
    public var providerSessions: [ServiceProvider: ProviderSession] = [:]
    public var selectedCurrencyCode: String = "USD"
    public var warningLimitUSD: Double = 200
    public var upperLimitUSD: Double = 500
    public var refreshIntervalMinutes: Int = 5
    public var launchAtLoginEnabled: Bool = false
    public var showCostInMenuBar: Bool = true
    public var showInDock: Bool = false
    public var enabledProviders: Set<ServiceProvider> = [.cursor]

    public init(
        selectedCurrencyCode: String = "USD",
        warningLimitUSD: Double = 200,
        upperLimitUSD: Double = 500,
        refreshIntervalMinutes: Int = 5,
        launchAtLoginEnabled: Bool = false,
        showCostInMenuBar: Bool = true,
        showInDock: Bool = false,
        enabledProviders: Set<ServiceProvider> = [.cursor]) {
        self.selectedCurrencyCode = selectedCurrencyCode
        self.warningLimitUSD = warningLimitUSD
        self.upperLimitUSD = upperLimitUSD
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.showCostInMenuBar = showCostInMenuBar
        self.showInDock = showInDock
        self.enabledProviders = enabledProviders
    }

    public func clearUserSessionData() {
        providerSessions.removeAll()
    }

    public func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }

    public func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }

    public func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
    }
}

// MARK: - Convenience Extensions for Previews

extension MockSettingsManager {
    /// Creates a MockSettingsManager with a logged-in session for testing
    static func withLoggedInSession(
        provider: ServiceProvider = .cursor,
        email: String = "user@example.com",
        teamName: String = "Example Team",
        teamId: Int = 123) -> MockSettingsManager {
        let manager = MockSettingsManager()
        let session = ProviderSession(
            provider: provider,
            teamId: teamId,
            teamName: teamName,
            userEmail: email,
            isActive: true)
        manager.updateSession(for: provider, session: session)
        return manager
    }

    /// Creates a MockSettingsManager with custom currency settings
    static func withCurrency(_ currencyCode: String) -> MockSettingsManager {
        MockSettingsManager(selectedCurrencyCode: currencyCode)
    }

    /// Creates a MockSettingsManager with custom limits
    static func withLimits(warning: Double, upper: Double) -> MockSettingsManager {
        MockSettingsManager(warningLimitUSD: warning, upperLimitUSD: upper)
    }
}
