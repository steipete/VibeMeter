import Combine
@testable import VibeMeter
import XCTest

@MainActor
class DataCoordinatorInitialStateTests: XCTestCase, @unchecked Sendable {
    var dataCoordinator: DataCoordinator!

    // Mocks for all dependencies
    var mockLoginManager: LoginManagerMock!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockApiClient: CursorAPIClientMock!
    var mockNotificationManager: NotificationManagerMock!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.DataCoordinatorInitialStateTests"
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: testSuiteName)
        suite?.removePersistentDomain(forName: testSuiteName)

        MainActor.assumeIsolated {
            cancellables = []
            testUserDefaults = suite
            // 1. Setup mock SettingsManager (as it's used by other mocks too)
            SettingsManager._test_setSharedInstance(userDefaults: testUserDefaults)
            mockSettingsManager = SettingsManager.shared
            // 2. Setup other mocks
            mockExchangeRateManager = ExchangeRateManagerMock()
            mockApiClient = CursorAPIClientMock()
            mockNotificationManager = NotificationManagerMock()
            mockLoginManager = LoginManagerMock()

            // Reset mocks to a clean state BEFORE creating DataCoordinator
            mockSettingsManager.selectedCurrencyCode = "USD"
            mockSettingsManager.warningLimitUSD = 200.0
            mockSettingsManager.upperLimitUSD = 1000.0
            mockSettingsManager.refreshIntervalMinutes = 5
            mockSettingsManager.clearUserSessionData()
            mockExchangeRateManager.reset()
            mockApiClient.reset()
            mockNotificationManager.reset()
            mockLoginManager.reset()

            // 3. Initialize DataCoordinator with all mocks (this sets up callbacks)
            dataCoordinator = DataCoordinator(
                loginManager: mockLoginManager,
                settingsManager: mockSettingsManager,
                exchangeRateManager: mockExchangeRateManager,
                apiClient: mockApiClient,
                notificationManager: mockNotificationManager)
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            dataCoordinator = nil
            mockLoginManager = nil
            mockSettingsManager = nil
            mockExchangeRateManager = nil
            mockApiClient = nil
            mockNotificationManager = nil
            SettingsManager._test_clearSharedInstance()
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            testUserDefaults = nil
            cancellables = nil
        }
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_WhenLoggedOut() {
        XCTAssertFalse(dataCoordinator.isLoggedIn, "Should be logged out initially")
        XCTAssertEqual(
            dataCoordinator.menuBarDisplayText,
            "",
            "Menu bar text should be empty when logged out")
        XCTAssertNil(dataCoordinator.userEmail)
        XCTAssertNil(dataCoordinator.currentSpendingConverted)
        XCTAssertNil(dataCoordinator.teamName)
        XCTAssertTrue(
            dataCoordinator.exchangeRatesAvailable,
            "Exchange rates should be assumed available initially or use fallback.")
    }

    func testInitialState_WhenLoggedIn_StartsDataRefresh() async {
        // Simulate logged-in state before DataCoordinator init
        let loggedInLoginManager = LoginManagerMock()
        loggedInLoginManager.simulateLogin(withToken: "test-token")

        // Expect API calls during init if logged in
        mockApiClient.teamInfoToReturn = TeamInfo(id: 1, name: "InitTeam")

        dataCoordinator = DataCoordinator(
            loginManager: loggedInLoginManager,
            settingsManager: mockSettingsManager,
            exchangeRateManager: mockExchangeRateManager,
            apiClient: mockApiClient,
            notificationManager: mockNotificationManager)

        // Wait a bit for async operations in init to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(
            mockApiClient.fetchTeamInfoCallCount > 0,
            "fetchTeamInfo should be called if logged in on init")
        XCTAssertTrue(mockApiClient.fetchUserInfoCallCount > 0, "fetchUserInfo should be called")
        XCTAssertTrue(mockApiClient.fetchMonthlyInvoiceCallCount > 0, "fetchMonthlyInvoice should be called")
        XCTAssertEqual(mockSettingsManager.teamName, "InitTeam")
    }

    // MARK: - Login Flow Tests

    func testLoginSuccess_RefreshesData_UpdatesState() async {
        var receivedMenuBarTexts: [String] = []

        // Setup initial state: logged out
        XCTAssertFalse(dataCoordinator.isLoggedIn)

        // Configure mocks for successful login and data fetch
        mockApiClient.teamInfoToReturn = TeamInfo(id: 789, name: "LoginSuccessTeam")
        mockApiClient.userInfoToReturn = UserInfo(email: "success@example.com", teamId: nil)
        mockApiClient.monthlyInvoiceToReturn = MonthlyInvoice(
            items: [InvoiceItem(cents: 12345, description: "usage")],
            pricingDescription: nil)
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.9]
        mockSettingsManager.selectedCurrencyCode = "EUR"

        // Observe menuBarDisplayText changes
        dataCoordinator.$menuBarDisplayText
            .sink { receivedMenuBarTexts.append($0) }
            .store(in: &cancellables)

        // Simulate login - this will trigger the onLoginSuccess callback automatically
        mockLoginManager.simulateLogin(withToken: "test-token")

        // Wait for async operations to complete with polling
        var attempts = 0
        while dataCoordinator.currentSpendingUSD == nil, attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }

        XCTAssertTrue(dataCoordinator.isLoggedIn, "DataCoordinator should be logged in")
        XCTAssertEqual(dataCoordinator.userEmail, "success@example.com")
        XCTAssertEqual(dataCoordinator.teamName, "LoginSuccessTeam")
        XCTAssertEqual(dataCoordinator.currentSpendingUSD, 123.45)
        XCTAssertEqual(dataCoordinator.currentSpendingConverted ?? 0, 123.45 * 0.9, accuracy: 0.01)
        XCTAssertEqual(dataCoordinator.selectedCurrencyCode, "EUR")
        XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "€")

        XCTAssertTrue(mockApiClient.fetchTeamInfoCallCount >= 1)
        XCTAssertTrue(mockApiClient.fetchUserInfoCallCount >= 1)
        XCTAssertTrue(mockApiClient.fetchMonthlyInvoiceCallCount >= 1)
        XCTAssertTrue(mockNotificationManager.resetAllNotificationStatesCalled)

        // Check final menu bar display shows spending amount
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "€111.11")
    }

    func testLogout_ClearsUserData_UpdatesState() async {
        // Setup: Mock data first
        mockApiClient.teamInfoToReturn = TeamInfo(id: 1, name: "Test Team")
        mockApiClient.userInfoToReturn = UserInfo(email: "test@example.com", teamId: nil)
        mockApiClient.monthlyInvoiceToReturn = MonthlyInvoice(
            items: [InvoiceItem(cents: 1000, description: "usage")],
            pricingDescription: nil)

        // Simulate logged-in state - this will trigger onLoginSuccess
        mockLoginManager.simulateLogin(withToken: "test-token")

        // Wait for login to complete
        var attempts = 0
        while dataCoordinator.currentSpendingUSD == nil, attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }

        XCTAssertTrue(dataCoordinator.isLoggedIn, "Precondition: Should be logged in")
        XCTAssertNotNil(dataCoordinator.userEmail, "Precondition: Should have user email")
        XCTAssertNotNil(dataCoordinator.teamName, "Precondition: Should have team name")

        // Act: Simulate logout
        mockLoginManager.logOut()

        // Wait for logout to complete
        attempts = 0
        while dataCoordinator.userEmail != nil, attempts < 20 {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            attempts += 1
        }

        // Assert
        XCTAssertFalse(dataCoordinator.isLoggedIn, "Should be logged out after logout event")
        XCTAssertNil(dataCoordinator.userEmail)
        XCTAssertNil(dataCoordinator.teamName)
        XCTAssertNil(dataCoordinator.currentSpendingUSD)
        XCTAssertNil(dataCoordinator.currentSpendingConverted)
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "")
        XCTAssertTrue(mockSettingsManager.teamId == nil, "TeamID should be cleared in UserDefaults by SettingsManager")
        XCTAssertTrue(mockNotificationManager.resetAllNotificationStatesCalled)
    }
}
