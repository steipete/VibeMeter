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

    struct ProviderPropertyTestCase {
        let provider: ServiceProvider
        let expectedDisplayName: String
        let expectedSupportsTeams: Bool
        let expectedAuthCookieName: String
    }

    @Test("Service provider properties", arguments: [
        ProviderPropertyTestCase(
            provider: .cursor,
            expectedDisplayName: "Cursor",
            expectedSupportsTeams: true,
            expectedAuthCookieName: "WorkosCursorSessionToken"),
    ])
    func serviceProviderProperties(testCase: ProviderPropertyTestCase) {
        let provider = testCase.provider

        #expect(provider.displayName == testCase.expectedDisplayName)
        #expect(provider.supportsTeams == testCase.expectedSupportsTeams)
        #expect(provider.authCookieName == testCase.expectedAuthCookieName)
    }

    struct SessionTestCase {
        let provider: ServiceProvider
        let email: String
        let teamName: String
        let teamId: Int
        let description: String
    }

    @Test("User session operations", arguments: [
        SessionTestCase(
            provider: .cursor,
            email: "test@example.com",
            teamName: "Test Team",
            teamId: 123,
            description: "Basic session"),
        SessionTestCase(
            provider: .cursor,
            email: "user@company.com",
            teamName: "Company Team",
            teamId: 456,
            description: "Company session"),
        SessionTestCase(
            provider: .cursor,
            email: "admin@org.com",
            teamName: "Org Admin",
            teamId: 789,
            description: "Admin session"),
    ])
    func userSessionOperations(testCase: SessionTestCase) {
        let userSession = MultiProviderUserSessionData()

        // Test initial state
        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.mostRecentSession == nil)

        // Add session
        userSession.handleLoginSuccess(
            for: testCase.provider,
            email: testCase.email,
            teamName: testCase.teamName,
            teamId: testCase.teamId)

        #expect(userSession.isLoggedInToAnyProvider == true)
        #expect(userSession.loggedInProviders == [testCase.provider])

        let session = userSession.getSession(for: testCase.provider)
        #expect(session != nil)
        #expect(session?.teamName == testCase.teamName)
        #expect(session?.teamId == testCase.teamId)
        #expect(session?.isLoggedIn == true)

        // Clear session
        userSession.handleLogout(from: testCase.provider)
        #expect(userSession.isLoggedInToAnyProvider == false)
        #expect(userSession.loggedInProviders.isEmpty == true)
    }

    struct SpendingDataTestCase {
        let provider: ServiceProvider
        let warningUSD: Double
        let upperUSD: Double
        let currency: String
        let description: String
    }

    @Test("Multi-provider spending data operations", arguments: [
        SpendingDataTestCase(
            provider: .cursor,
            warningUSD: 50.0,
            upperUSD: 100.0,
            currency: "USD",
            description: "Basic USD limits"),
        SpendingDataTestCase(
            provider: .cursor,
            warningUSD: 100.0,
            upperUSD: 500.0,
            currency: "EUR",
            description: "EUR limits"),
        SpendingDataTestCase(
            provider: .cursor,
            warningUSD: 0.0,
            upperUSD: 1000.0,
            currency: "USD",
            description: "Zero warning limit"),
    ])
    func multiProviderSpendingDataOperations(testCase: SpendingDataTestCase) {
        let spendingData = MultiProviderSpendingData()

        // Test initial state
        #expect(spendingData.providersWithData.isEmpty == true)
        #expect(spendingData.getSpendingData(for: testCase.provider) == nil)

        // Test updating limits
        spendingData.updateLimits(
            for: testCase.provider,
            warningUSD: testCase.warningUSD,
            upperUSD: testCase.upperUSD,
            rates: [testCase.currency: 1.0],
            targetCurrency: testCase.currency)

        #expect(spendingData.providersWithData.contains(testCase.provider) == true)
        let providerData = spendingData.getSpendingData(for: testCase.provider)
        #expect(providerData != nil)
        #expect(providerData?.displayUpperLimit == testCase.upperUSD)

        // Clear data
        spendingData.clear(provider: testCase.provider)
        #expect(spendingData.providersWithData.contains(testCase.provider) == false)
    }

    @Test("Currency operations", arguments: [
        (code: "EUR", rates: ["EUR": 1.0, "USD": 1.1], description: "EUR base"),
        (code: "GBP", rates: ["GBP": 1.0, "USD": 1.3], description: "GBP base"),
        (code: "JPY", rates: ["JPY": 1.0, "USD": 0.0067], description: "JPY base")
    ])
    func currencyOperations(code: String, rates: [String: Double], description _: String) {
        let currencyData = CurrencyData()

        // Test initial state
        #expect(currencyData.selectedCode == "USD")
        #expect(currencyData.exchangeRatesAvailable == true)

        // Test updating currency
        currencyData.updateSelectedCurrency(code)
        #expect(currencyData.selectedCode == code)

        // Test updating exchange rates
        currencyData.updateExchangeRates(rates)
        #expect(currencyData.currentExchangeRates == rates)

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
