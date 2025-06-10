import Foundation
@testable import VibeMeter

/// Mock implementation of SettingsManagerProtocol for tests.
///
/// This mock provides a non-persistent, in-memory implementation of the settings manager
/// for use in testing scenarios. It includes default values suitable for tests.
@MainActor
final class MockSettingsManager: SettingsManagerProtocol {
    var providerSessions: [ServiceProvider: ProviderSession] = [:]
    var selectedCurrencyCode: String = "USD"
    var warningLimitUSD: Double = 200
    var upperLimitUSD: Double = 500
    var refreshIntervalMinutes: Int = 5
    var launchAtLoginEnabled: Bool = false
    var showInDock: Bool = false
    var enabledProviders: Set<ServiceProvider> = [.cursor]
    var menuBarDisplayMode: MenuBarDisplayMode = .both
    var updateChannel: UpdateChannel = .stable
    
    // Sub-managers for protocol compliance
    lazy var displaySettingsManager = DisplaySettingsManager(userDefaults: UserDefaults())
    lazy var sessionSettingsManager = SessionSettingsManager(userDefaults: UserDefaults())

    init(
        selectedCurrencyCode: String = "USD",
        warningLimitUSD: Double = 200,
        upperLimitUSD: Double = 500,
        refreshIntervalMinutes: Int = 5,
        launchAtLoginEnabled: Bool = false,
        menuBarDisplayMode: MenuBarDisplayMode = .both,
        showInDock: Bool = false,
        enabledProviders: Set<ServiceProvider> = [.cursor],
        updateChannel: UpdateChannel = .stable) {
        self.selectedCurrencyCode = selectedCurrencyCode
        self.warningLimitUSD = warningLimitUSD
        self.upperLimitUSD = upperLimitUSD
        self.refreshIntervalMinutes = refreshIntervalMinutes
        self.launchAtLoginEnabled = launchAtLoginEnabled
        self.menuBarDisplayMode = menuBarDisplayMode
        self.showInDock = showInDock
        self.enabledProviders = enabledProviders
        self.updateChannel = updateChannel
    }

    func clearUserSessionData() {
        providerSessions.removeAll()
    }

    func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }

    func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }

    func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
    }
}

// MARK: - Convenience Extensions for Tests

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
