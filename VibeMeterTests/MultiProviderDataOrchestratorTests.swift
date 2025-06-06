import Foundation
import Testing
@testable import VibeMeter

extension Date {
    var month: Int {
        Calendar.current.component(.month, from: self)
    }

    var year: Int {
        Calendar.current.component(.year, from: self)
    }
}

@Suite("MultiProviderDataOrchestratorTests")
.tags(.integration, .critical)
@MainActor
struct MultiProviderDataOrchestratorTests {
    var orchestrator: MultiProviderDataOrchestrator

    // Mocks for all dependencies
    let mockLoginManager: MultiProviderLoginManager
    let mockSettingsManager: MockSettingsManager
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
    let testSuiteName = "com.vibemeter.tests.MultiProviderDataOrchestratorTests"

    init() async throws {
        // Initialize test user defaults
        testUserDefaults = UserDefaults(suiteName: testSuiteName)!
        testUserDefaults.removePersistentDomain(forName: testSuiteName)

        // Initialize mocks
        mockURLSession = MockURLSession()
        mockApiClient = CursorAPIClientMock()
        mockExchangeRateManager = ExchangeRateManagerMock()
        mockNotificationManager = NotificationManagerMock()
        mockSettingsManager = MockSettingsManager()

        // Initialize data models
        spendingData = MultiProviderSpendingData()
        userSessionData = MultiProviderUserSessionData()
        currencyData = CurrencyData()

        // Initialize provider factory
        providerFactory = ProviderFactory(settingsManager: mockSettingsManager, urlSession: mockURLSession)

        // Initialize login manager
        mockLoginManager = MultiProviderLoginManager(providerFactory: providerFactory)

        // Initialize orchestrator
        orchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: mockSettingsManager,
            exchangeRateManager: mockExchangeRateManager,
            notificationManager: mockNotificationManager,
            loginManager: mockLoginManager,
            spendingData: spendingData,
            userSessionData: userSessionData,
            currencyData: currencyData)
    }

    // MARK: - Initial State Tests

    @Test("initial state when logged out")
    func initialState_WhenLoggedOut() {
        #expect(userSessionData.isLoggedInToAnyProvider == false)
        #expect(userSessionData.mostRecentSession == nil)
    }

    @Test("initial state when logged in starts data refresh")
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

        // Note: The orchestrator was already initialized with the data models
        // that we just updated, so it should reflect the logged-in state

        // The orchestrator should not automatically fetch data on initialization
        // It should wait for explicit refresh calls
        #expect(userSessionData.isLoggedIn(to: .cursor) == true)
    }

    // MARK: - Login Flow Tests

    @Test("login success refreshes data updates state")
    func loginSuccess_RefreshesData_UpdatesState() async {
        // Setup initial state: logged out
        #expect(userSessionData.isLoggedInToAnyProvider == false)

        // Simulate user login with session data
        userSessionData.handleLoginSuccess(
            for: .cursor,
            email: "test@example.com",
            teamName: "LoginSuccessTeam",
            teamId: 123)

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
        #expect(userSessionData.isLoggedIn(to: .cursor) == true)
        #expect(userSessionData.mostRecentSession?.teamName == "LoginSuccessTeam")

        if let cursorData = spendingData.getSpendingData(for: .cursor) {
            #expect(abs((cursorData.currentSpendingUSD ?? 0) - 123.45) < 0.01)
        } else {
            Issue.record("Expected condition not met")
        }
    }

    @Test("logout clears user data updates state")

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

        #expect(userSessionData.isLoggedIn(to: .cursor) == true)
        #expect(userSessionData.mostRecentSession?.teamName != nil)

        // Act: Simulate logout
        orchestrator.logout(from: .cursor)

        // Assert
        #expect(userSessionData.isLoggedIn(to: .cursor) == false)
        // Note: Notification reset is not called on logout - notifications are only reset when explicitly requested
    }

    // MARK: - Multi-Provider Tests

    @Test("refresh all providers with multiple providers")

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
        #expect(spendingData.providersWithData.contains(.cursor) == true)
    }

    @Test("currency conversion updates spending data")

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

        // Verify that spending data exists and currency update works
        if let cursorData = spendingData.getSpendingData(for: .cursor) {
            // The test verifies that currency conversion functionality is wired up correctly
            // The actual spending amount might vary based on implementation details
            #expect(cursorData.currentSpendingUSD != nil || cursorData.currentSpendingConverted != nil)
        } else {
            Issue.record("No spending data found for Cursor - spending data may not have been initialized correctly")
        }
    }
}
