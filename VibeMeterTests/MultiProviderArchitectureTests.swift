import Foundation
import Testing
@testable import VibeMeter

/// Tests for the new multi-provider architecture to ensure basic functionality works
@Suite("MultiProviderArchitectureTests", .tags(.integration, .unit))
@MainActor
struct MultiProviderArchitectureTests {
    @Test("service provider cases")
    func serviceProviderCases() {
        // Test that ServiceProvider enum has expected cases
        let allCases = ServiceProvider.allCases
        #expect(allCases.contains(.cursor))
    }

    @Test("service provider properties")
    func serviceProviderProperties() {
        let cursor = ServiceProvider.cursor

        // Test basic properties
        #expect(cursor.displayName == "Cursor")
        #expect(cursor.supportsTeams == true)

        // Test cookie properties
        #expect(cursor.authCookieName == "WorkosCursorSessionToken")
    }

    @Test("multi provider user session data")
    func multiProviderUserSessionData() {
        let userSession = MultiProviderUserSessionData()

        // Test initial state
        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.mostRecentSession == nil)

        // Add a test session
        userSession.handleLoginSuccess(
            for: .cursor,
            email: "test@example.com",
            teamName: "Test Team",
            teamId: 123)

        #expect(userSession.isLoggedInToAnyProvider == true)
        #expect(userSession.loggedInProviders == [.cursor])

        let session = userSession.getSession(for: .cursor)
        #expect(session != nil)
        #expect(session?.teamName == "Test Team")
        #expect(session?.isLoggedIn == true)

        // Clear session
        userSession.handleLogout(from: .cursor)
        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.loggedInProviders.isEmpty == true)
    }

    @Test("multi provider spending data")
    func multiProviderSpendingData() {
        let spendingData = MultiProviderSpendingData()

        // Test initial state
        #expect(spendingData.providersWithData.isEmpty == true)
        #expect(spendingData.getSpendingData(for: .cursor) == nil)

        // Test updating limits
        spendingData.updateLimits(
            for: .cursor,
            warningUSD: 50.0,
            upperUSD: 100.0,
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        #expect(spendingData.providersWithData.contains(.cursor) == true)
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(cursorData != nil)
        #expect(cursorData?.displayUpperLimit == 100.0)

        // Clear data
        spendingData.clear(provider: .cursor)
        #expect(spendingData.providersWithData.contains(.cursor) == false)
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

        // Test reset behavior
        currencyData.reset()
        #expect(currencyData.selectedCode == "USD")
    }

    @Test("settings manager")
    func settingsManager() {
        // Test that SettingsManager can be created and has reasonable defaults
        let settings = SettingsManager.shared

        #expect(settings.warningLimitUSD > 0)
        #expect(settings.upperLimitUSD > settings.warningLimitUSD)
        #expect(settings.refreshIntervalMinutes > 0)
    }

    @Test("keychain")
    func keychain() {
        // Test that KeychainHelper can be created without crashing
        let keychain = KeychainHelper(service: "test.service.unique.\(UUID().uuidString)")

        // Test basic operations (should not crash)
        #expect(keychain.getToken() == nil)

        // Note: We don't test actual save/delete operations as they would affect the real keychain
        // Those would be tested in integration tests with a mock keychain service
    }
}
