import Combine
@testable import VibeMeter
import XCTest

class DataCoordinatorCurrencyTests: XCTestCase, @unchecked Sendable {
    var dataCoordinator: RealDataCoordinator!

    // Mocks for all dependencies
    var mockLoginManager: LoginManager!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockApiClient: CursorAPIClientMock!
    var mockNotificationManager: NotificationManagerMock!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.DataCoordinatorCurrencyTests"
    private var cancellables: Set<AnyCancellable>!
    private var keychainMockForLoginManager: KeychainServiceMock!

    override func setUp() {
        super.setUp()
        cancellables = []
        testUserDefaults = UserDefaults(suiteName: testSuiteName)
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        
        DispatchQueue.main.sync {
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
        DispatchQueue.main.sync {
            dataCoordinator = nil
            mockLoginManager = nil
            mockSettingsManager = nil
            mockExchangeRateManager = nil
            mockApiClient = nil
            mockNotificationManager = nil
            SettingsManager._test_clearSharedInstance()
        }
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        cancellables = nil
        super.tearDown()
    }

    // MARK: - Currency Conversion & Display Tests

    func testCurrencyChange_UpdatesConvertedValuesAndSymbol() async {
        DispatchQueue.main.sync {
            _ = keychainMockForLoginManager.saveToken("test-token")
            dataCoordinator.isLoggedIn = true
            dataCoordinator.currentSpendingUSD = 100.0
            mockSettingsManager.warningLimitUSD = 50.0
            mockSettingsManager.upperLimitUSD = 150.0

            mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.9, "GBP": 0.8]
        }
        
        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        DispatchQueue.main.sync {
            XCTAssertEqual(dataCoordinator.selectedCurrencyCode, "USD")
            XCTAssertEqual(dataCoordinator.currentSpendingConverted, 100.0)
            XCTAssertEqual(dataCoordinator.warningLimitConverted, 50.0)
            XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "$")

            // Act: Change currency in SettingsManager (which DataCoordinator observes)
            mockSettingsManager.selectedCurrencyCode = "EUR"
        }
        
        // Allow sink block to execute
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        DispatchQueue.main.sync {
            XCTAssertEqual(dataCoordinator.selectedCurrencyCode, "EUR")
            XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "€")
            XCTAssertEqual(dataCoordinator.currentSpendingConverted!, 100.0 * 0.9, accuracy: 0.01)
            XCTAssertEqual(dataCoordinator.warningLimitConverted!, 50.0 * 0.9, accuracy: 0.01)
            XCTAssertEqual(dataCoordinator.upperLimitConverted!, 150.0 * 0.9, accuracy: 0.01)
            XCTAssertEqual(dataCoordinator.menuBarDisplayText, "€90.00 / €45.00")
        }
    }

    func testExchangeRatesUnavailable_DisplaysInUSD() async {
        DispatchQueue.main.sync {
            _ = keychainMockForLoginManager.saveToken("test-token")
            dataCoordinator.isLoggedIn = true
            dataCoordinator.currentSpendingUSD = 120.0
            mockSettingsManager.warningLimitUSD = 80.0
            mockSettingsManager.selectedCurrencyCode = "EUR"

            mockExchangeRateManager.ratesToReturn = nil
            mockExchangeRateManager.errorToReturn = NSError(domain: "test", code: 1)
        }

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        DispatchQueue.main.sync {
            XCTAssertFalse(dataCoordinator.exchangeRatesAvailable)
            XCTAssertEqual(dataCoordinator.selectedCurrencyCode, "EUR")
            XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "$")
            XCTAssertEqual(dataCoordinator.currentSpendingConverted, 120.0)
            XCTAssertEqual(dataCoordinator.warningLimitConverted, 80.0)
            XCTAssertEqual(dataCoordinator.menuBarDisplayText, "$120.00 / $80.00")
            XCTAssertEqual(dataCoordinator.lastErrorMessage, "Rates MIA! Showing USD for now. ✨")
        }
    }
}
