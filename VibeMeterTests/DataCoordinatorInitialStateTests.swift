import Combine
@testable import VibeMeter
import XCTest

@MainActor
class DataCoordinatorInitialStateTests: XCTestCase, @unchecked Sendable {
    var dataCoordinator: DataCoordinator!

    // Mocks for all dependencies
    var mockLoginManager: LoginManager!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockApiClient: CursorAPIClientMock!
    var mockNotificationManager: NotificationManagerMock!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.DataCoordinatorInitialStateTests"
    private var cancellables: Set<AnyCancellable>!
    private var keychainMockForLoginManager: KeychainServiceMock!

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
            keychainMockForLoginManager = KeychainServiceMock()
            let apiClientForLoginManager = CursorAPIClient(settingsManager: mockSettingsManager)
            mockLoginManager = LoginManager(
                settingsManager: mockSettingsManager,
                apiClient: apiClientForLoginManager,
                keychainService: keychainMockForLoginManager,
                webViewFactory: { MockWebView() }
            )
            // 3. Initialize DataCoordinator with all mocks
            dataCoordinator = DataCoordinator(
                loginManager: mockLoginManager,
                settingsManager: mockSettingsManager,
                exchangeRateManager: mockExchangeRateManager,
                apiClient: mockApiClient,
                notificationManager: mockNotificationManager
            )
            // Reset mocks to a clean state before each test
            mockSettingsManager.selectedCurrencyCode = "USD"
            mockSettingsManager.warningLimitUSD = 200.0
            mockSettingsManager.upperLimitUSD = 1000.0
            mockSettingsManager.refreshIntervalMinutes = 5
            mockSettingsManager.clearUserSessionData()
            mockExchangeRateManager.reset()
            mockApiClient.reset()
            mockNotificationManager.reset()
            keychainMockForLoginManager?.reset()
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
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "Login Required", "Menu bar text should show 'Login Required' when logged out")
        XCTAssertNil(dataCoordinator.userEmail)
        XCTAssertNil(dataCoordinator.currentSpendingConverted)
        XCTAssertNil(dataCoordinator.teamName)
        XCTAssertTrue(
            dataCoordinator.exchangeRatesAvailable,
            "Exchange rates should be assumed available initially or use fallback."
        )
    }

    func testInitialState_WhenLoggedIn_StartsDataRefresh() async {
        // Simulate logged-in state before DataCoordinator init by populating keychain
        let keychainMock = KeychainServiceMock()
        _ = keychainMock.saveToken("test-token")

        let apiClientForLoginManager = CursorAPIClient(settingsManager: mockSettingsManager)
        let loggedInLoginManager = LoginManager(
            settingsManager: mockSettingsManager,
            apiClient: apiClientForLoginManager,
            keychainService: keychainMock,
            webViewFactory: { MockWebView() }
        )

        // Expect API calls during init if logged in
        mockApiClient.teamInfoToReturn = TeamInfo(id: 1, name: "InitTeam")

        dataCoordinator = DataCoordinator(
            loginManager: loggedInLoginManager,
            settingsManager: mockSettingsManager,
            exchangeRateManager: mockExchangeRateManager,
            apiClient: mockApiClient,
            notificationManager: mockNotificationManager
        )

        // Wait a bit for async operations in init to complete
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(
            mockApiClient.fetchTeamInfoCallCount > 0,
            "fetchTeamInfo should be called if logged in on init"
        )
        XCTAssertTrue(mockApiClient.fetchUserInfoCallCount > 0, "fetchUserInfo should be called")
        XCTAssertTrue(mockApiClient.fetchMonthlyInvoiceCallCount > 0, "fetchMonthlyInvoice should be called")
        XCTAssertEqual(mockSettingsManager.teamName, "InitTeam")
    }

    // MARK: - Login Flow Tests

    func testLoginSuccess_RefreshesData_UpdatesState() async {
        var receivedMenuBarTexts: [String] = []
        let loginSuccessExpectation = XCTestExpectation(description: "Login successful and data updated")

        // Setup initial state: logged out
        XCTAssertFalse(dataCoordinator.isLoggedIn)

        // Configure mocks for successful login and data fetch
        mockApiClient.teamInfoToReturn = TeamInfo(id: 789, name: "LoginSuccessTeam")
        mockApiClient.userInfoToReturn = UserInfo(email: "success@example.com", teamId: nil)
        mockApiClient.monthlyInvoiceToReturn = MonthlyInvoice(items: [InvoiceItem(cents: 12345, description: "usage")], pricingDescription: nil)
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.9]
        mockSettingsManager.selectedCurrencyCode = "EUR"

        // Set up login state - LoginManager needs a token to report isLoggedIn = true
        _ = keychainMockForLoginManager.saveToken("test-token")

        // Observe menuBarDisplayText changes
        dataCoordinator.$menuBarDisplayText
            .sink { receivedMenuBarTexts.append($0) }
            .store(in: &cancellables)

        // Simulate LoginManager's onLoginSuccess callback being triggered
        mockLoginManager.onLoginSuccess?()

        // Wait for async operations within handleLoginStatusChange and forceRefreshData
        try? await Task.sleep(nanoseconds: 500_000_000)

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

        // Check menu bar text progression (can be fragile)
        XCTAssertTrue(receivedMenuBarTexts.contains("Vibe synced! ✨"))
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "€111.11")

        loginSuccessExpectation.fulfill()

        await fulfillment(of: [loginSuccessExpectation], timeout: 0.1)
    }

    func testLogout_ClearsUserData_UpdatesState() async {
        // Setup: Simulate logged-in state first
        _ = keychainMockForLoginManager.saveToken("test-token")
        mockApiClient.teamInfoToReturn = TeamInfo(id: 1, name: "Test Team")
        mockApiClient.userInfoToReturn = UserInfo(email: "test@example.com", teamId: nil)
        mockApiClient.monthlyInvoiceToReturn = MonthlyInvoice(items: [InvoiceItem(cents: 1000, description: "usage")], pricingDescription: nil)

        mockLoginManager.onLoginSuccess?()

        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(dataCoordinator.isLoggedIn, "Precondition: Should be logged in")

        // Act: Simulate LoginManager's onLoginFailure or equivalent logout signal
        mockLoginManager.onLoginFailure?(NSError(domain: "logout", code: 0))

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Assert
        XCTAssertFalse(dataCoordinator.isLoggedIn, "Should be logged out after logout event")
        XCTAssertNil(dataCoordinator.userEmail)
        XCTAssertNil(dataCoordinator.teamName)
        XCTAssertNil(dataCoordinator.currentSpendingUSD)
        XCTAssertNil(dataCoordinator.currentSpendingConverted)
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "Login Required")
        XCTAssertTrue(mockSettingsManager.teamId == nil, "TeamID should be cleared in UserDefaults by SettingsManager")
        XCTAssertTrue(mockNotificationManager.resetAllNotificationStatesCalled)
    }
}
