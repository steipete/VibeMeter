import Combine
@testable import VibeMeter
import XCTest

@MainActor
class DataCoordinatorNotificationTests: XCTestCase {
    var dataCoordinator: RealDataCoordinator!

    // Mocks for all dependencies
    var mockLoginManager: LoginManager!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockApiClient: CursorAPIClientMock!
    var mockNotificationManager: NotificationManagerMock!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.DataCoordinatorNotificationTests"
    private var cancellables: Set<AnyCancellable>!

    override func setUpWithError() throws {
        try super.setUpWithError()
        cancellables = []

        testUserDefaults = UserDefaults(suiteName: testSuiteName)
        testUserDefaults.removePersistentDomain(forName: testSuiteName)

        // 1. Setup mock SettingsManager (as it's used by other mocks too)
        SettingsManager._test_setSharedInstance(userDefaults: testUserDefaults)
        mockSettingsManager = SettingsManager.shared

        // 2. Setup other mocks
        mockExchangeRateManager = ExchangeRateManagerMock()
        mockApiClient = CursorAPIClientMock()
        mockNotificationManager = NotificationManagerMock()

        let keychainMockForLoginManager = KeychainServiceMock()
        let apiClientForLoginManager = CursorAPIClient(session: MockURLSession(), settingsManager: mockSettingsManager)

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
        keychainMockForLoginManager.reset()
    }

    override func tearDownWithError() throws {
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
        try super.tearDownWithError()
    }

    // MARK: - Notification Tests

    func testSpendingExceedsWarningLimit_TriggersWarningNotification() async {
        _ = mockLoginManager.keychainService.saveToken("test-token")
        dataCoordinator.isLoggedIn = true
        mockSettingsManager.warningLimitUSD = 100.0
        mockSettingsManager.upperLimitUSD = 1000.0
        dataCoordinator.currentSpendingUSD = 105.0
        mockSettingsManager.selectedCurrencyCode = "USD"
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0]

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        XCTAssertTrue(mockNotificationManager.showWarningNotificationCalled)
        XCTAssertEqual(mockNotificationManager.lastWarningSpending, 105.0)
        XCTAssertEqual(mockNotificationManager.lastWarningCurrency, "USD")
        XCTAssertFalse(mockNotificationManager.showUpperLimitNotificationCalled)
    }

    func testSpendingExceedsUpperLimit_TriggersUpperNotification() async {
        _ = mockLoginManager.keychainService.saveToken("test-token")
        dataCoordinator.isLoggedIn = true
        mockSettingsManager.warningLimitUSD = 100.0
        mockSettingsManager.upperLimitUSD = 200.0
        dataCoordinator.currentSpendingUSD = 210.0
        mockSettingsManager.selectedCurrencyCode = "EUR"
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.9]

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        XCTAssertTrue(
            mockNotificationManager.showWarningNotificationCalled,
            "Warning should also be called if upper is met and warning is lower"
        )
        XCTAssertTrue(mockNotificationManager.showUpperLimitNotificationCalled)
        XCTAssertEqual(mockNotificationManager.lastUpperLimitSpending, 210.0 * 0.9, accuracy: 0.01)
        XCTAssertEqual(mockNotificationManager.lastUpperLimitCurrency, "EUR")
    }

    func testSpendingBelowLimits_ResetsNotificationStates() async {
        _ = mockLoginManager.keychainService.saveToken("test-token")
        dataCoordinator.isLoggedIn = true
        mockSettingsManager.warningLimitUSD = 100.0
        mockSettingsManager.upperLimitUSD = 200.0
        dataCoordinator.currentSpendingUSD = 50.0

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        XCTAssertTrue(
            mockNotificationManager.resetNotificationStateIfBelowCalled,
            "resetNotificationStateIfBelow should be called"
        )
        XCTAssertFalse(mockNotificationManager.showWarningNotificationCalled)
        XCTAssertFalse(mockNotificationManager.showUpperLimitNotificationCalled)
    }

    // MARK: - Timer tests

    func testRefreshIntervalChange_ResetsTimer() {
        _ = mockLoginManager.keychainService.saveToken("test-token")
        dataCoordinator.isLoggedIn = true

        let initialInterval = mockSettingsManager.refreshIntervalMinutes
        XCTAssertNotNil(dataCoordinator.refreshTimer, "Timer should be configured if logged in.")
        let oldTimer = dataCoordinator.refreshTimer

        mockSettingsManager.refreshIntervalMinutes = initialInterval + 1

        // Short delay for Combine pipeline to call setupRefreshTimer
        let expectation = XCTestExpectation(description: "Wait for timer to be potentially reconfigured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertNotEqual(
                self.dataCoordinator.refreshTimer,
                oldTimer,
                "Timer should be a new instance after interval change"
            )
            XCTAssertTrue(self.dataCoordinator.refreshTimer?.isValid ?? false, "New timer should be valid")
            XCTAssertEqual(self.dataCoordinator.refreshTimer?.timeInterval, TimeInterval((initialInterval + 1) * 60))
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.5)
    }
}

// Helper extension for DataCoordinator to access internal timer for test validation
#if DEBUG
    extension RealDataCoordinator {
        var refreshTimerInstance: Timer? {
            refreshTimer
        }
    }
#endif
