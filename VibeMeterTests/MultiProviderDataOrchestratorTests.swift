import Combine
@testable import VibeMeter
import XCTest

@MainActor
class MultiProviderDataOrchestratorTests: XCTestCase, @unchecked Sendable {
    var orchestrator: MultiProviderDataOrchestrator!

    // Mocks for all dependencies
    var mockLoginManager: MultiProviderLoginManager!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockNotificationManager: NotificationManagerMock!
    var providerFactory: ProviderFactory!
    var mockApiClient: CursorAPIClientMock!

    // Data models
    var spendingData: MultiProviderSpendingData!
    var userSessionData: MultiProviderUserSessionData!
    var currencyData: CurrencyData!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.MultiProviderDataOrchestratorTests"
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: testSuiteName)
        suite?.removePersistentDomain(forName: testSuiteName)

        MainActor.assumeIsolated {
            cancellables = []
            testUserDefaults = suite

            // Setup mock SettingsManager
            SettingsManager._test_setSharedInstance(userDefaults: testUserDefaults)
            mockSettingsManager = SettingsManager.shared

            // Setup other mocks
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
            providerFactory = nil
            spendingData = nil
            userSessionData = nil
            currencyData = nil
            SettingsManager._test_clearSharedInstance()
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            testUserDefaults = nil
            cancellables = nil
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
        // Setup mock responses
        mockApiClient.teamInfoToReturn = ProviderTeamInfo(id: 1, name: "InitTeam", provider: .cursor)
        mockApiClient.userInfoToReturn = ProviderUserInfo(email: "init@example.com", teamId: 1, provider: .cursor)
        mockApiClient.monthlyInvoiceToReturn = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 5000, description: "Usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)

        // Simulate existing login state
        mockLoginManager._test_setLoginState(true, for: .cursor)

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

        // Wait for async operations to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(mockApiClient.fetchTeamInfoCallCount > 0, "fetchTeamInfo should be called if logged in on init")
        XCTAssertTrue(mockApiClient.fetchUserInfoCallCount > 0, "fetchUserInfo should be called")
        XCTAssertTrue(mockApiClient.fetchMonthlyInvoiceCallCount > 0, "fetchMonthlyInvoice should be called")
    }

    // MARK: - Login Flow Tests

    func testLoginSuccess_RefreshesData_UpdatesState() async {
        // Setup initial state: logged out
        XCTAssertFalse(userSessionData.isLoggedInToAnyProvider)

        // Configure mocks for successful login and data fetch
        mockApiClient.teamInfoToReturn = ProviderTeamInfo(id: 789, name: "LoginSuccessTeam", provider: .cursor)
        mockApiClient.userInfoToReturn = ProviderUserInfo(email: "success@example.com", teamId: 789, provider: .cursor)
        mockApiClient.monthlyInvoiceToReturn = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 12345, description: "usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.9]
        mockSettingsManager.selectedCurrencyCode = "EUR"

        // Trigger login success callback
        await orchestrator.refreshData(for: .cursor, showSyncedMessage: true)

        // Wait for async operations to complete
        var attempts = 0
        while spendingData.providersWithData.isEmpty, attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }

        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor), "Should be logged in to Cursor")
        XCTAssertEqual(userSessionData.mostRecentSession?.userEmail, "success@example.com")
        XCTAssertEqual(userSessionData.mostRecentSession?.teamName, "LoginSuccessTeam")

        if let cursorData = spendingData.getSpendingData(for: .cursor) {
            XCTAssertEqual(cursorData.currentSpendingUSD ?? 0, 123.45, accuracy: 0.01)
        } else {
            XCTFail("Should have spending data for Cursor")
        }

        XCTAssertTrue(mockApiClient.fetchTeamInfoCallCount >= 1)
        XCTAssertTrue(mockApiClient.fetchUserInfoCallCount >= 1)
        XCTAssertTrue(mockApiClient.fetchMonthlyInvoiceCallCount >= 1)
    }

    func testLogout_ClearsUserData_UpdatesState() async {
        // Setup: Mock data first
        mockApiClient.teamInfoToReturn = ProviderTeamInfo(id: 1, name: "Test Team", provider: .cursor)
        mockApiClient.userInfoToReturn = ProviderUserInfo(email: "test@example.com", teamId: 1, provider: .cursor)
        mockApiClient.monthlyInvoiceToReturn = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 1000, description: "usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)

        // Simulate logged-in state
        await orchestrator.refreshData(for: .cursor, showSyncedMessage: false)

        // Wait for login to complete
        var attempts = 0
        while spendingData.providersWithData.isEmpty, attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }

        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor), "Precondition: Should be logged in")
        XCTAssertNotNil(userSessionData.mostRecentSession?.userEmail, "Precondition: Should have user email")
        XCTAssertNotNil(userSessionData.mostRecentSession?.teamName, "Precondition: Should have team name")

        // Act: Simulate logout
        orchestrator.logout(from: .cursor)

        // Assert
        XCTAssertFalse(userSessionData.isLoggedIn(to: .cursor), "Should be logged out after logout")
        XCTAssertTrue(spendingData.providersWithData.isEmpty, "Should have no spending data after logout")
        XCTAssertTrue(mockNotificationManager.resetAllNotificationStatesCalled)
    }

    // MARK: - Multi-Provider Tests

    func testRefreshAllProviders_WithMultipleProviders() async {
        // Configure mock for Cursor
        mockApiClient.teamInfoToReturn = ProviderTeamInfo(id: 1, name: "Cursor Team", provider: .cursor)
        mockApiClient.userInfoToReturn = ProviderUserInfo(email: "user@cursor.com", teamId: 1, provider: .cursor)
        mockApiClient.monthlyInvoiceToReturn = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "Cursor usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)

        // Enable Cursor provider
        ProviderRegistry.shared.enableProvider(.cursor)

        // Simulate login
        mockLoginManager._test_setLoginState(true, for: .cursor)

        // Test refreshing all providers
        await orchestrator.refreshAllProviders(showSyncedMessage: false)

        // Wait for completion
        var attempts = 0
        while spendingData.providersWithData.isEmpty, attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        XCTAssertTrue(spendingData.providersWithData.contains(.cursor), "Should have data for Cursor")
        XCTAssertTrue(mockApiClient.fetchTeamInfoCallCount >= 1)
        XCTAssertTrue(mockApiClient.fetchUserInfoCallCount >= 1)
        XCTAssertTrue(mockApiClient.fetchMonthlyInvoiceCallCount >= 1)
    }

    func testCurrencyConversion_UpdatesSpendingData() async {
        // Setup spending data
        mockApiClient.monthlyInvoiceToReturn = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 10000, description: "Usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.85]

        // Add some data
        await orchestrator.refreshData(for: .cursor, showSyncedMessage: false)

        // Wait for data
        var attempts = 0
        while spendingData.providersWithData.isEmpty, attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            attempts += 1
        }

        // Change currency
        orchestrator.updateCurrency(to: "EUR")

        // Wait for currency update
        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(currencyData.selectedCode, "EUR")
        XCTAssertEqual(currencyData.selectedSymbol, "€")

        if let cursorData = spendingData.getSpendingData(for: .cursor) {
            XCTAssertEqual(cursorData.currentSpendingUSD ?? 0, 100.0, accuracy: 0.01)
            // Display spending should be converted to EUR
            XCTAssertNotNil(cursorData.displaySpending)
        }
    }
}

