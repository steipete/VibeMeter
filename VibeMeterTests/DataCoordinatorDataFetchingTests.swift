import Combine
@testable import VibeMeter
import XCTest

@MainActor
class DataCoordinatorDataFetchingTests: XCTestCase, @unchecked Sendable {
    var dataCoordinator: RealDataCoordinator!

    // Mocks for all dependencies
    var mockLoginManager: LoginManager!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockApiClient: CursorAPIClientMock!
    var mockNotificationManager: NotificationManagerMock!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.DataCoordinatorDataFetchingTests"
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
        let apiClientForLoginManager = CursorAPIClient.__init(session: MockURLSession(), settingsManager: mockSettingsManager)
        mockLoginManager = LoginManager(
            settingsManager: mockSettingsManager,
            apiClient: apiClientForLoginManager,
            keychainService: keychainMockForLoginManager,
            webViewFactory: { MockWebView() }
        )
        // 3. Initialize DataCoordinator with all mocks
        dataCoordinator = RealDataCoordinator(
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

    // MARK: - Data Fetching Tests (forceRefreshData)

    func testForceRefreshData_SuccessfulFetch_UpdatesPublishedProperties() async {
        // Arrange: Logged in state
        _ = keychainMockForLoginManager.saveToken("test-token")
        dataCoordinator.isLoggedIn = true

        mockApiClient.teamInfoToReturn = (111, "RefreshedTeam")
        mockApiClient.userInfoToReturn = .init(email: "refreshed@example.com", teamId: nil)
        mockApiClient.monthlyInvoiceToReturn = .init(items: [.init(cents: 54321, description: "new usage")], pricingDescription: nil)
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "JPY": 150.0]
        mockSettingsManager.selectedCurrencyCode = "JPY"

        // Act
        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        // Assert
        XCTAssertEqual(dataCoordinator.teamName, "RefreshedTeam")
        XCTAssertEqual(dataCoordinator.userEmail, "refreshed@example.com")
        XCTAssertEqual(dataCoordinator.currentSpendingUSD, 543.21)
        XCTAssertEqual(dataCoordinator.currentSpendingConverted!, 543.21 * 150.0, accuracy: 0.01)
        XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "¥")
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "¥81481.50 / ¥30000.00")
        XCTAssertTrue(mockApiClient.fetchTeamInfoCallCount >= 1)
    }

    func testForceRefreshData_ApiUnauthorizedError_HandlesLogout() async {
        var logoutTriggered = false

        // Arrange: Logged in state
        _ = keychainMockForLoginManager.saveToken("expired-token")
        dataCoordinator.isLoggedIn = true

        mockApiClient.teamInfoError = CursorAPIClient.APIError.unauthorized

        mockLoginManager.onLoginFailure = { _ in logoutTriggered = true }

        // Act
        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        // Assert
        XCTAssertTrue(logoutTriggered, "LoginManager's onLoginFailure should be triggered on unauthorized")
        XCTAssertFalse(dataCoordinator.isLoggedIn, "Should be logged out after unauthorized error")
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "Login Required")
        XCTAssertEqual(dataCoordinator.lastErrorMessage, "Session expired. Please log in.")
        XCTAssertNil(keychainMockForLoginManager.getToken(), "Token should be cleared by LoginManager.logOut()")
    }

    func testForceRefreshData_TeamNotFoundError_UpdatesUIAppropriately() async {
        _ = keychainMockForLoginManager.saveToken("test-token")
        dataCoordinator.isLoggedIn = true

        mockApiClient.teamInfoError = CursorAPIClient.APIError.noTeamFound

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        XCTAssertTrue(dataCoordinator.isLoggedIn, "Still logged in technically, but team fetch failed")
        XCTAssertTrue(dataCoordinator.teamIdFetchFailed)
        XCTAssertNil(dataCoordinator.currentSpendingUSD)
        XCTAssertNil(dataCoordinator.currentSpendingConverted)
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "Error (No Team)")
        XCTAssertEqual(dataCoordinator.lastErrorMessage, "Hmm, can't find your team vibe right now. 😕 Try a refresh?")
    }

    func testForceRefreshData_GenericNetworkError_UpdatesUIAppropriately() async {
        _ = keychainMockForLoginManager.saveToken("test-token")
        dataCoordinator.isLoggedIn = true

        let networkError = CursorAPIClient.APIError.networkError(.init(message: "No internet", statusCode: nil))
        mockApiClient.teamInfoError = networkError

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        XCTAssertTrue(dataCoordinator.isLoggedIn, "Still logged in, but data fetch failed")
        XCTAssertFalse(dataCoordinator.teamIdFetchFailed, "teamIdFetchFailed should be false for generic network error")
        XCTAssertNil(dataCoordinator.currentSpendingUSD)
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "Error")
        XCTAssertTrue(dataCoordinator.lastErrorMessage?.starts(with: "Error fetching data:") ?? false)
    }
}
