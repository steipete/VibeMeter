@testable import VibeMeter
import Testing

/// Tests for the new multi-provider architecture to ensure basic functionality works
@Suite("MultiProviderArchitectureTests")
@MainActor
struct MultiProviderArchitectureTests {
    @Test("service provider cases")

    func serviceProviderCases() {
        // Test that ServiceProvider enum has expected cases
        let allCases = ServiceProvider.allCases
        #expect(allCases.contains(.cursor == true)
    }

    @Test("service provider properties")

    func serviceProviderProperties() {
        let cursor = ServiceProvider.cursor

        // Test basic properties
        #expect(cursor.displayName == "Cursor")
        #expect(cursor.supportsTeams == true)

        // Test URLs
        #expect(cursor.authenticationURL != nil)

        // Test cookie properties
        #expect(cursor.authCookieName == "WorkosCursorSessionToken")
    }

    @Test("multi provider user session data")

    func multiProviderUserSessionData() {
        let userSession = MultiProviderUserSessionData()

        // Test initial state
        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.mostRecentSession == nil)

        #expect(userSession.isLoggedInToAnyProvider == true)
        #expect(userSession.loggedInProviders == [.cursor])
        #expect(session != nil)
        #expect(session?.teamName == "Test Team")
        #expect(session?.isLoggedIn ?? false == true)

        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.loggedInProviders.isEmpty == true)

    func multiProviderSpendingData() {
        let spendingData = MultiProviderSpendingData()

        // Test initial state
        #expect(spendingData.providersWithData.isEmpty == true)
        #expect(spendingData.getSpendingData(for: .cursor == nil)

        // Test updating limits
        spendingData.updateLimits(
            for: .cursor,
            warningUSD: 50.0,
            upperUSD: 100.0,
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        #expect(spendingData.providersWithData.contains(.cursor == true)
        #expect(cursorData != nil)
        #expect(cursorData?.displayUpperLimit == 100.0)
        #expect(
            spendingData.providersWithData.contains(.cursor == false)
    }

    @Test("currency data")

    func currencyData() {
        let currencyData = CurrencyData()

        // Test initial state
        #expect(currencyData.selectedCode == "USD")
        #expect(currencyData.exchangeRatesAvailable == true)

        // Test updating currency
        currencyData.updateSelectedCurrency("EUR")
        #expect(currencyData.selectedCode == "EUR")

        // Test updating exchange rates
        let testRates = ["EUR": 1.0, "USD": 1.1]
        currencyData.updateExchangeRates(testRates)
        #expect(currencyData.currentExchangeRates == testRates)
        #expect(currencyData.exchangeRatesAvailable == false)
        #expect(currencyData.selectedCode == "USD")
    }

    @Test("settings manager")

    func settingsManager() {
        // Test that SettingsManager can be created and has reasonable defaults
        let settings = SettingsManager.shared

        #expect(settings.warningLimitUSD > 0)
        #expect(
            settings.upperLimitUSD > settings.warningLimitUSD)
        #expect(settings.refreshIntervalMinutes > 0)

    func keychain() {
        // Test that KeychainHelper can be created without crashing
        let keychain = KeychainHelper(service: "test.service.unique.\(UUID().uuidString)")

        // Test basic operations (should not crash)
        let initialToken = keychain.getToken()
        #expect(initialToken == nil)

        // Note: We don't test actual save/delete operations as they would affect the real keychain
        // Those would be tested in integration tests with a mock keychain service
    }
}
