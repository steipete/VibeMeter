import Foundation
@preconcurrency import UserNotifications
@testable import VibeMeter
import XCTest

@MainActor
final class NotificationManagerContentTests: XCTestCase {
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

    // MARK: - Notification Content Tests

    func testNotificationContent_WarningNotification() async {
        // When
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then
        let request = mockNotificationCenter.lastAddedRequest!
        let content = request.content

        XCTAssertEqual(content.title, "Spending Alert ⚠️")
        XCTAssertTrue(content.body.contains("You've reached"))
        XCTAssertTrue(content.body.contains("warning limit"))
        XCTAssertEqual(content.sound, .default)
        XCTAssertEqual(content.categoryIdentifier, "SPENDING_WARNING")
        XCTAssertNotEqual(content.interruptionLevel, .critical)
    }

    func testNotificationContent_UpperLimitNotification() async {
        // When
        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then
        let request = mockNotificationCenter.lastAddedRequest!
        let content = request.content

        XCTAssertEqual(content.title, "Spending Limit Reached! 🚨")
        XCTAssertTrue(content.body.contains("You've exceeded"))
        XCTAssertTrue(content.body.contains("maximum limit"))
        XCTAssertEqual(content.sound, .defaultCritical)
        XCTAssertEqual(content.categoryIdentifier, "SPENDING_CRITICAL")
        XCTAssertEqual(content.interruptionLevel, .critical)
    }

    // MARK: - Notification Identifier Tests

    func testNotificationIdentifiers_Unique() async {
        // When - Show multiple notifications
        await notificationManager.resetAllNotificationStatesForNewSession()
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        await notificationManager.resetAllNotificationStatesForNewSession()
        await notificationManager.showWarningNotification(
            currentSpending: 76.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then - Identifiers should be unique
        XCTAssertEqual(mockNotificationCenter.addedRequests.count, 2)
        let id1 = mockNotificationCenter.addedRequests[0].identifier
        let id2 = mockNotificationCenter.addedRequests[1].identifier

        XCTAssertNotEqual(id1, id2)
        XCTAssertTrue(id1.hasPrefix("warning_"))
        XCTAssertTrue(id2.hasPrefix("warning_"))
    }

    func testNotificationIdentifiers_DifferentTypes() async {
        // When
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then
        XCTAssertEqual(mockNotificationCenter.addedRequests.count, 2)
        let warningId = mockNotificationCenter.addedRequests[0].identifier
        let upperId = mockNotificationCenter.addedRequests[1].identifier

        XCTAssertTrue(warningId.hasPrefix("warning_"))
        XCTAssertTrue(upperId.hasPrefix("upper_"))
    }

    // MARK: - Error Handling Tests

    func testNotificationScheduling_Error() async {
        // Given
        let error = NSError(domain: "TestError", code: 1, userInfo: nil)
        mockNotificationCenter.addResult = .failure(error)

        // When - Should not crash even if notification fails
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then - Call should succeed but notification won't be added
        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)
        XCTAssertTrue(mockNotificationCenter.addedRequests.isEmpty)
    }
}

// MARK: - TestableNotificationManager

private final class TestableNotificationManager: NotificationManagerProtocol, @unchecked Sendable {
    private let notificationCenter: MockUNUserNotificationCenter

    // Track which notifications have been shown
    private var warningNotificationShown = false
    private var upperLimitNotificationShown = false

    init(notificationCenter: MockUNUserNotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        guard !warningNotificationShown else { return }

        let symbol = ExchangeRateManager.getSymbol(for: currencyCode)
        let precision = .number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US"))
        let spendingFormatted = "\(symbol)\(currentSpending.formatted(precision))"
        let limitFormatted = "\(symbol)\(limitAmount.formatted(precision))"

        let content = UNMutableNotificationContent()
        content.title = "Spending Alert ⚠️"
        content.body = "You've reached \(spendingFormatted) of your \(limitFormatted) warning limit"
        content.sound = .default
        content.categoryIdentifier = "SPENDING_WARNING"

        let request = UNNotificationRequest(
            identifier: "warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)

        try? await Task { @MainActor in
            try await notificationCenter.add(request)
        }.value
        warningNotificationShown = true
    }

    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        guard !upperLimitNotificationShown else { return }

        let symbol = ExchangeRateManager.getSymbol(for: currencyCode)
        let precision = .number.precision(.fractionLength(2)).locale(Locale(identifier: "en_US"))
        let spendingFormatted = "\(symbol)\(currentSpending.formatted(precision))"
        let limitFormatted = "\(symbol)\(limitAmount.formatted(precision))"

        let content = UNMutableNotificationContent()
        content.title = "Spending Limit Reached! 🚨"
        content.body = "You've exceeded your maximum limit! Current: \(spendingFormatted), Limit: \(limitFormatted)"
        content.sound = .defaultCritical
        content.categoryIdentifier = "SPENDING_CRITICAL"
        content.interruptionLevel = .critical

        let request = UNNotificationRequest(
            identifier: "upper_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)

        try? await Task { @MainActor in
            try await notificationCenter.add(request)
        }.value
        upperLimitNotificationShown = true
    }

    func resetNotificationStateIfBelow(
        limitType: NotificationLimitType,
        currentSpendingUSD: Double,
        warningLimitUSD: Double,
        upperLimitUSD: Double) async {
        switch limitType {
        case .warning:
            if currentSpendingUSD < warningLimitUSD, warningNotificationShown {
                warningNotificationShown = false
            }
        case .upper:
            if currentSpendingUSD < upperLimitUSD, upperLimitNotificationShown {
                upperLimitNotificationShown = false
            }
        }
    }

    func resetAllNotificationStatesForNewSession() async {
        warningNotificationShown = false
        upperLimitNotificationShown = false
    }

    func showInstanceAlreadyRunningNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Vibe Meter Already Running"
        content
            .body =
            "Another instance of Vibe Meter is already running. The existing instance has been brought to the front."
        content.sound = .default
        content.categoryIdentifier = "APP_INSTANCE"

        let request = UNNotificationRequest(
            identifier: "instance_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)

        try? await Task { @MainActor in
            try await notificationCenter.add(request)
        }.value
    }
}

// MARK: - MockUNUserNotificationCenter

private class MockUNUserNotificationCenter: @unchecked Sendable {
    var authorizationResult: Result<Bool, Error> = .success(true)
    var addResult: Result<Void, Error> = .success(())

    var requestAuthorizationCallCount = 0
    var addCallCount = 0

    var lastRequestedOptions: UNAuthorizationOptions?
    var lastAddedRequest: UNNotificationRequest?
    var addedRequests: [UNNotificationRequest] = []

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCallCount += 1
        lastRequestedOptions = options

        switch authorizationResult {
        case let .success(granted):
            return granted
        case let .failure(error):
            throw error
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        addCallCount += 1
        lastAddedRequest = request

        switch addResult {
        case .success:
            addedRequests.append(request)
        case let .failure(error):
            throw error
        }
    }

    func reset() {
        requestAuthorizationCallCount = 0
        addCallCount = 0
        lastRequestedOptions = nil
        lastAddedRequest = nil
        addedRequests.removeAll()
        authorizationResult = .success(true)
        addResult = .success(())
    }
}
