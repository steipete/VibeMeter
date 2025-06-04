import Foundation
@preconcurrency import UserNotifications
@testable import VibeMeter
import XCTest

@MainActor
final class NotificationManagerBasicTests: XCTestCase {
    private var notificationManager: TestableNotificationManager!
    private var mockNotificationCenter: MockUNUserNotificationCenter!

    override func setUp() async throws {
        await MainActor.run { super.setUp() }
        mockNotificationCenter = MockUNUserNotificationCenter()
        notificationManager = TestableNotificationManager(notificationCenter: mockNotificationCenter)
    }

    override func tearDown() async throws {
        notificationManager = nil
        mockNotificationCenter = nil
        await MainActor.run { super.tearDown() }
    }

    // MARK: - Authorization Tests

    func testRequestAuthorization_Success() async {
        // Given
        mockNotificationCenter.authorizationResult = .success(true)

        // When
        let result = await notificationManager.requestAuthorization()

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationCallCount, 1)
        XCTAssertEqual(mockNotificationCenter.lastRequestedOptions, [.alert, .sound, .badge])
    }

    func testRequestAuthorization_Denied() async {
        // Given
        mockNotificationCenter.authorizationResult = .success(false)

        // When
        let result = await notificationManager.requestAuthorization()

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationCallCount, 1)
    }

    func testRequestAuthorization_Error() async {
        // Given
        let error = NSError(domain: "TestError", code: 1, userInfo: nil)
        mockNotificationCenter.authorizationResult = .failure(error)

        // When
        let result = await notificationManager.requestAuthorization()

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(mockNotificationCenter.requestAuthorizationCallCount, 1)
    }

    // MARK: - Warning Notification Tests

    func testShowWarningNotification_FirstTime() async {
        // Given
        let currentSpending = 75.50
        let limitAmount = 100.0
        let currencyCode = "USD"

        // When
        await notificationManager.showWarningNotification(
            currentSpending: currentSpending,
            limitAmount: limitAmount,
            currencyCode: currencyCode)

        // Then
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)

        let request = mockNotificationCenter.lastAddedRequest!
        XCTAssertTrue(request.identifier.hasPrefix("warning_"))
        XCTAssertEqual(request.content.title, "Spending Alert ⚠️")
        XCTAssertTrue(request.content.body.contains("$75.50"))
        XCTAssertTrue(request.content.body.contains("$100.00"))
        XCTAssertEqual(request.content.categoryIdentifier, "SPENDING_WARNING")
        XCTAssertNil(request.trigger) // Immediate notification
    }

    func testShowWarningNotification_DifferentCurrency() async {
        // Given
        let currentSpending = 82.30
        let limitAmount = 100.0
        let currencyCode = "EUR"

        // When
        await notificationManager.showWarningNotification(
            currentSpending: currentSpending,
            limitAmount: limitAmount,
            currencyCode: currencyCode)

        // Then
        let request = mockNotificationCenter.lastAddedRequest!
        XCTAssertTrue(request.content.body.contains("€82.30"))
        XCTAssertTrue(request.content.body.contains("€100.00"))
    }

    func testShowWarningNotification_AlreadyShown() async {
        // Given - Show notification once
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)

        // When - Try to show again
        await notificationManager.showWarningNotification(
            currentSpending: 80.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then - Should not trigger another notification
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1) // Still 1
    }

    // MARK: - Upper Limit Notification Tests

    func testShowUpperLimitNotification_FirstTime() async {
        // Given
        let currentSpending = 105.75
        let limitAmount = 100.0
        let currencyCode = "USD"

        // When
        await notificationManager.showUpperLimitNotification(
            currentSpending: currentSpending,
            limitAmount: limitAmount,
            currencyCode: currencyCode)

        // Then
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)

        let request = mockNotificationCenter.lastAddedRequest!
        XCTAssertTrue(request.identifier.hasPrefix("upper_"))
        XCTAssertEqual(request.content.title, "Spending Limit Reached! 🚨")
        XCTAssertTrue(request.content.body.contains("$105.75"))
        XCTAssertTrue(request.content.body.contains("$100.00"))
        XCTAssertEqual(request.content.categoryIdentifier, "SPENDING_CRITICAL")
        XCTAssertEqual(request.content.interruptionLevel, .critical)
    }

    func testShowUpperLimitNotification_AlreadyShown() async {
        // Given - Show notification once
        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)

        // When - Try to show again
        await notificationManager.showUpperLimitNotification(
            currentSpending: 110.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then - Should not trigger another notification
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1) // Still 1
    }
}

// MARK: - TestableNotificationManager

private final class TestableNotificationManager: NSObject, NotificationManagerProtocol {
    let notificationCenter: MockUNUserNotificationCenter
    
    init(notificationCenter: MockUNUserNotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init()
    }
    
    func requestAuthorization() async -> Bool {
        true // Mock implementation
    }
    
    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        // Mock implementation
    }
    
    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        // Mock implementation
    }
    
    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double) async {
        // Mock implementation
    }
    
    func resetAllNotificationStatesForNewSession() async {
        // Mock implementation
    }
    
    func showInstanceAlreadyRunningNotification() async {
        // Mock implementation
    }
}

// MARK: - MockUNUserNotificationCenter

private final class MockUNUserNotificationCenter {
    var authorizationResult: Result<Bool, Error> = .success(true)
    var requestAuthorizationCallCount = 0
    var lastRequestedOptions: UNAuthorizationOptions?

    var addCallCount = 0
    var lastAddedRequest: UNNotificationRequest?
    
    init() {
        // Custom init for testing
    }

    func requestAuthorization(
        options: UNAuthorizationOptions,
        completionHandler: @escaping (Bool, Error?) -> Void
    ) {
        requestAuthorizationCallCount += 1
        lastRequestedOptions = options

        switch authorizationResult {
        case let .success(granted):
            completionHandler(granted, nil)
        case let .failure(error):
            completionHandler(false, error)
        }
    }

    func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)?) {
        addCallCount += 1
        lastAddedRequest = request
        completionHandler?(nil)
    }
}