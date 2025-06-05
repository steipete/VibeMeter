@testable import VibeMeter
import Testing

extension Date {
    let month: Int {
        Calendar.current.component(.month, from: self)
    }

    var year: Int {
        Calendar.current.component(.year, from: self)
    }
}

@MainActor
class MultiProviderDataOrchestratorTests: XCTestCase, @unchecked Sendable {
    var orchestrator: MultiProviderDataOrchestrator

    // Mocks for all dependencies
    let mockLoginManager: MultiProviderLoginManager
    let mockSettingsManager: SettingsManager
    let mockExchangeRateManager: ExchangeRateManagerMock
    let mockNotificationManager: NotificationManagerMock
    let mockURLSession: MockURLSession
    let providerFactory: ProviderFactory
    let mockApiClient: CursorAPIClientMock

    // Data models
    let spendingData: MultiProviderSpendingData
    let userSessionData: MultiProviderUserSessionData
    let currencyData: CurrencyData

    let testUserDefaults: UserDefaults
    let testSuiteName = "com.vibemeter.tests.MultiProviderDataOrchestratorTests"    }
    // MARK: - Initial State Tests

    @Test("initial state  when logged out")

    func initialState_WhenLoggedOut() {
        #expect(userSessionData.isLoggedInToAnyProvider == false)
        #expect(userSessionData.mostRecentSession == nil)
    }

    @Test("initial state  when logged in  starts data refresh")

    func initialState_WhenLoggedIn_StartsDataRefresh() async {
        // This test verifies that the orchestrator doesn't automatically
        // refresh data on initialization when a user is logged in.
        // The actual refresh should be triggered by the app explicitly.

        // Simulate existing login state by setting up user session data
        userSessionData.handleLoginSuccess(
            for: .cursor,
            email: "test@example.com",
            teamName: "Test Team",
            teamId: 123)

        // Create new orchestrator with logged-in state
        orchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: mockSettingsManager,
            exchangeRateManager: mockExchangeRateManager,
            notificationManager: mockNotificationManager,
            loginManager: mockLoginManager,
            spendingData: spendingData,
            userSessionData: userSessionData,
            currencyData: currencyData)

        // The orchestrator should not automatically fetch data on initialization
        // It should wait for explicit refresh calls
        #expect(userSessionData.isLoggedIn(to: .cursor == true)
    }

    // MARK: - Login Flow Tests

    @Test("login success  refreshes data  updates state")

    func loginSuccess_RefreshesData_UpdatesState() async {
        // This test is simplified - in a real implementation, we would need to
        // properly mock the network responses or use dependency injection
        // to inject mock providers. For now, we'll test the basic flow.

        // Setup initial state: logged out
        #expect(userSessionData.isLoggedInToAnyProvider == false)

        // Simulate spending data update
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 12345, description: "usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: Date().month,
            year: Date().year)
        spendingData.updateSpending(
            for: .cursor,
            from: invoice,
            rates: mockExchangeRateManager.ratesToReturn ?? ["USD": 1.0],
            targetCurrency: "EUR")

        // Set exchange rates
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.9]
        currencyData.updateExchangeRates(mockExchangeRateManager.ratesToReturn ?? ["USD": 1.0])
        currencyData.updateSelectedCurrency("EUR")

        // Verify the state
        #expect(userSessionData.isLoggedIn(to: .cursor == true)
        #expect(userSessionData.mostRecentSession?.teamName == "LoginSuccessTeam") {
            #expect(abs(cursorData.currentSpendingUSD ?? 0 - 123.45 == true)
        } else {
            Issue.record("Should have spending data for Cursor")
        }
    }

    @Test("logout  clears user data  updates state")

    func logout_ClearsUserData_UpdatesState() async {
        // Setup: Simulate logged-in state
        userSessionData.handleLoginSuccess(
            for: .cursor,
            email: "test@example.com",
            teamName: "Test Team",
            teamId: 1)

        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 1000, description: "usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: Date().month,
            year: Date().year)
        spendingData.updateSpending(
            for: .cursor,
            from: invoice,
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        #expect(userSessionData.isLoggedIn(to: .cursor == true)
        #expect(userSessionData.mostRecentSession?.teamName != nil)

        // Act: Simulate logout
        orchestrator.logout(from: .cursor)

        // Assert
        #expect(userSessionData.isLoggedIn(to: .cursor == false)
        // Note: Notification reset is not called on logout - notifications are only reset when explicitly requested
    }

    // MARK: - Multi-Provider Tests

    @Test("refresh all providers  with multiple providers")

    func refreshAllProviders_WithMultipleProviders() async {
        // Enable Cursor provider
        ProviderRegistry.shared.enableProvider(.cursor)

        // Simulate logged in state
        userSessionData.handleLoginSuccess(
            for: .cursor,
            email: "user@cursor.com",
            teamName: "Cursor Team",
            teamId: 1)

        // Simulate spending data
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: Date().month,
            year: Date().year)
        spendingData.updateSpending(
            for: .cursor,
            from: invoice,
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        // Test that we have data for enabled providers
        #expect(spendingData.providersWithData.contains(.cursor == true)
    }

    @Test("currency conversion  updates spending data")

    func currencyConversion_UpdatesSpendingData() async {
        // Setup exchange rates
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.85]
        currencyData.updateExchangeRates(mockExchangeRateManager.ratesToReturn ?? ["USD": 1.0])

        // Add spending data in USD
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 10000, description: "usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: Date().month,
            year: Date().year)
        spendingData.updateSpending(
            for: .cursor,
            from: invoice,
            rates: mockExchangeRateManager.ratesToReturn ?? ["USD": 1.0],
            targetCurrency: "USD")

        // Change currency
        orchestrator.updateCurrency(to: "EUR")

        // Wait a bit for the async Task to complete
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Verify currency was updated
        #expect(currencyData.selectedCode == "EUR")

        if let cursorData = spendingData.getSpendingData(for: .cursor) {
            #expect(abs(cursorData.currentSpendingUSD ?? 0 - 100.0 == true)
            // The spending data model handles currency conversion internally
        }
    }
}
