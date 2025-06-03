import Combine
@testable import VibeMeter
import XCTest

@MainActor
class DataCoordinatorCurrencyTests: XCTestCase, @unchecked Sendable {
    var dataCoordinator: DataCoordinator!

    // Mocks for all dependencies
    var mockLoginManager: LoginManagerMock!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockApiClient: CursorAPIClientMock!
    var mockNotificationManager: NotificationManagerMock!

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.DataCoordinatorCurrencyTests"
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
            // 3. Initialize DataCoordinator with all mocks
            dataCoordinator = DataCoordinator(
                loginManager: mockLoginManager,
                settingsManager: mockSettingsManager,
                exchangeRateManager: mockExchangeRateManager,
                apiClient: mockApiClient,
                notificationManager: mockNotificationManager)
            // Reset mocks to a clean state before each test
            mockSettingsManager.selectedCurrencyCode = "USD"
            mockSettingsManager.warningLimitUSD = 200.0
            mockSettingsManager.upperLimitUSD = 1000.0
            mockSettingsManager.refreshIntervalMinutes = 5
            mockSettingsManager.clearUserSessionData()
            mockExchangeRateManager.reset()
            mockApiClient.reset()
            mockNotificationManager.reset()
            mockLoginManager.reset()
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

    // MARK: - Currency Conversion & Display Tests

    func testCurrencyChange_UpdatesConvertedValuesAndSymbol() async {
        mockLoginManager.simulateLogin(withToken: "test-token")

        // Configure mock API to return $100 worth of items (10000 cents)
        mockApiClient.monthlyInvoiceToReturn = MonthlyInvoice(
            items: [
                InvoiceItem(cents: 10000, description: "Mock Pro Usage for test"),
            ],
            pricingDescription: nil)

        mockSettingsManager.warningLimitUSD = 50.0
        mockSettingsManager.upperLimitUSD = 150.0

        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.9, "GBP": 0.8]

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        XCTAssertEqual(dataCoordinator.selectedCurrencyCode, "USD")
        XCTAssertEqual(dataCoordinator.currentSpendingConverted, 100.0)
        XCTAssertEqual(dataCoordinator.warningLimitConverted, 50.0)
        XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "$")

        // Act: Change currency in SettingsManager (which DataCoordinator observes)
        mockSettingsManager.selectedCurrencyCode = "EUR"

        // Allow sink block to execute
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Assert
        XCTAssertEqual(dataCoordinator.selectedCurrencyCode, "EUR")
        XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "€")
        XCTAssertEqual(dataCoordinator.currentSpendingConverted!, 100.0 * 0.9, accuracy: 0.01)
        XCTAssertEqual(dataCoordinator.warningLimitConverted!, 50.0 * 0.9, accuracy: 0.01)
        XCTAssertEqual(dataCoordinator.upperLimitConverted!, 150.0 * 0.9, accuracy: 0.01)
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "€90.00")
    }

    func testExchangeRatesUnavailable_DisplaysInUSD() async {
        mockLoginManager.simulateLogin(withToken: "test-token")

        // Configure mock API to return $120 worth of items (12000 cents)
        mockApiClient.monthlyInvoiceToReturn = MonthlyInvoice(
            items: [
                InvoiceItem(cents: 12000, description: "Mock Pro Usage for exchange test"),
            ],
            pricingDescription: nil)

        mockSettingsManager.warningLimitUSD = 80.0
        mockSettingsManager.selectedCurrencyCode = "EUR"

        mockExchangeRateManager.ratesToReturn = nil
        mockExchangeRateManager.errorToReturn = NSError(domain: "test", code: 1)

        await dataCoordinator.forceRefreshData(showSyncedMessage: false)

        XCTAssertFalse(dataCoordinator.exchangeRatesAvailable)
        XCTAssertEqual(dataCoordinator.selectedCurrencyCode, "EUR")
        XCTAssertEqual(dataCoordinator.selectedCurrencySymbol, "€")
        // 120 USD * 0.9 (fallback EUR rate) = 108 EUR
        XCTAssertEqual(dataCoordinator.currentSpendingConverted ?? 0, 108.0, accuracy: 0.01)
        // 80 USD * 0.9 = 72 EUR
        XCTAssertEqual(dataCoordinator.warningLimitConverted ?? 0, 72.0, accuracy: 0.01)
        XCTAssertEqual(dataCoordinator.menuBarDisplayText, "€108.00")
        // No error message is set when using fallback rates
        XCTAssertNil(dataCoordinator.lastErrorMessage)
    }
}
