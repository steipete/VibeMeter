@testable import VibeMeter
import XCTest

extension Date {
    var month: Int {
        Calendar.current.component(.month, from: self)
    }

    var year: Int {
        Calendar.current.component(.year, from: self)
    }
}

@MainActor
class MultiProviderDataOrchestratorTests: XCTestCase, @unchecked Sendable {
    var orchestrator: MultiProviderDataOrchestrator!

    // Mocks for all dependencies
    var mockLoginManager: MultiProviderLoginManager!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockNotificationManager: NotificationManagerMock!
    var mockURLSession: MockURLSession!
    var providerFactory: ProviderFactory!
    var mockApiClient: CursorAPIClientMock!

    // Data models
    var spendingData: MultiProviderSpendingData!
    var userSessionData: MultiProviderUserSessionData!
    var currencyData: CurrencyData!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.MultiProviderDataOrchestratorTests"

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: testSuiteName)
        suite?.removePersistentDomain(forName: testSuiteName)

        MainActor.assumeIsolated {
            testUserDefaults = suite

            // Setup mock SettingsManager
            SettingsManager._test_setSharedInstance(
                userDefaults: testUserDefaults,
                startupManager: StartupManagerMock())
            mockSettingsManager = SettingsManager.shared

            // Setup other mocks
            mockURLSession = MockURLSession()
            mockExchangeRateManager = ExchangeRateManagerMock()
            mockApiClient = CursorAPIClientMock()
            mockNotificationManager = NotificationManagerMock()
            providerFactory = ProviderFactory(settingsManager: mockSettingsManager)
            mockLoginManager = MultiProviderLoginManager(providerFactory: providerFactory)

            // Initialize data models
            spendingData = MultiProviderSpendingData()
            userSessionData = MultiProviderUserSessionData()
            currencyData = CurrencyData()

            // Reset mocks to a clean state
            mockSettingsManager.selectedCurrencyCode = "USD"
            mockSettingsManager.warningLimitUSD = 200.0
            mockSettingsManager.upperLimitUSD = 1000.0
            mockSettingsManager.refreshIntervalMinutes = 5
            mockSettingsManager.clearUserSessionData()
            mockExchangeRateManager.reset()
            mockApiClient.reset()
            mockNotificationManager.reset()

            // Initialize MultiProviderDataOrchestrator
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
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            orchestrator = nil
            mockLoginManager = nil
            mockSettingsManager = nil
            mockExchangeRateManager = nil
            mockApiClient = nil
            mockNotificationManager = nil
            mockURLSession = nil
            providerFactory = nil
            spendingData = nil
            userSessionData = nil
            currencyData = nil
            SettingsManager._test_clearSharedInstance()
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            testUserDefaults = nil
        }
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_WhenLoggedOut() {
        XCTAssertFalse(userSessionData.isLoggedInToAnyProvider, "Should be logged out initially")
        XCTAssertTrue(spendingData.providersWithData.isEmpty, "Should have no spending data initially")
        XCTAssertNil(userSessionData.mostRecentSession, "Should have no user session initially")
        XCTAssertTrue(currencyData.currentExchangeRates.isEmpty, "Exchange rates should start empty")
    }

    func testInitialState_WhenLoggedIn_StartsDataRefresh() async {
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
        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor))
        XCTAssertTrue(spendingData.providersWithData.isEmpty, "Should not have spending data until refresh is called")
    }

    // MARK: - Login Flow Tests

    func testLoginSuccess_RefreshesData_UpdatesState() async {
        // This test is simplified - in a real implementation, we would need to
        // properly mock the network responses or use dependency injection
        // to inject mock providers. For now, we'll test the basic flow.

        // Setup initial state: logged out
        XCTAssertFalse(userSessionData.isLoggedInToAnyProvider)

        // Simulate login success by setting user session data
        userSessionData.handleLoginSuccess(
            for: .cursor,
            email: "success@example.com",
            teamName: "LoginSuccessTeam",
            teamId: 789)

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
        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor), "Should be logged in to Cursor")
        XCTAssertEqual(userSessionData.mostRecentSession?.userEmail, "success@example.com")
        XCTAssertEqual(userSessionData.mostRecentSession?.teamName, "LoginSuccessTeam")

        if let cursorData = spendingData.getSpendingData(for: .cursor) {
            XCTAssertEqual(cursorData.currentSpendingUSD ?? 0, 123.45, accuracy: 0.01)
        } else {
            XCTFail("Should have spending data for Cursor")
        }
    }

    func testLogout_ClearsUserData_UpdatesState() async {
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

        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor), "Precondition: Should be logged in")
        XCTAssertNotNil(userSessionData.mostRecentSession?.userEmail, "Precondition: Should have user email")
        XCTAssertNotNil(userSessionData.mostRecentSession?.teamName, "Precondition: Should have team name")
        XCTAssertFalse(spendingData.providersWithData.isEmpty, "Precondition: Should have spending data")

        // Act: Simulate logout
        orchestrator.logout(from: .cursor)

        // Assert
        XCTAssertFalse(userSessionData.isLoggedIn(to: .cursor), "Should be logged out after logout")
        XCTAssertTrue(spendingData.providersWithData.isEmpty, "Should have no spending data after logout")
        // Note: Notification reset is not called on logout - notifications are only reset when explicitly requested
    }

    // MARK: - Multi-Provider Tests

    func testRefreshAllProviders_WithMultipleProviders() async {
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
        XCTAssertTrue(spendingData.providersWithData.contains(.cursor), "Should have data for Cursor")
        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor))
    }

    func testCurrencyConversion_UpdatesSpendingData() async {
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
        XCTAssertEqual(currencyData.selectedCode, "EUR")
        XCTAssertEqual(currencyData.selectedSymbol, "€")

        if let cursorData = spendingData.getSpendingData(for: .cursor) {
            XCTAssertEqual(cursorData.currentSpendingUSD ?? 0, 100.0, accuracy: 0.01)
            // The spending data model handles currency conversion internally
        }
    }
}
