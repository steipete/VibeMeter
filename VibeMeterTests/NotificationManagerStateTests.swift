import Foundation
@preconcurrency import UserNotifications
@testable import VibeMeter
import XCTest

@MainActor
final class NotificationManagerStateTests: XCTestCase {
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

    // MARK: - Notification State Reset Tests

    func testResetNotificationStateIfBelow_WarningReset() async {
        // Given - Show warning notification first
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)

        // When - Reset when spending is below warning limit
        await notificationManager.resetNotificationStateIfBelow(
            limitType: .warning,
            currentSpendingUSD: 60.0,
            warningLimitUSD: 75.0,
            upperLimitUSD: 100.0)

        // Then - Should be able to show warning notification again
        await notificationManager.showWarningNotification(
            currentSpending: 76.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 2) // Should be 2 now
    }

    func testResetNotificationStateIfBelow_WarningNotReset() async {
        // Given - Show warning notification first
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // When - Don't reset when spending is still above warning limit
        await notificationManager.resetNotificationStateIfBelow(
            limitType: .warning,
            currentSpendingUSD: 80.0,
            warningLimitUSD: 75.0,
            upperLimitUSD: 100.0)

        // Then - Should not be able to show warning notification again
        await notificationManager.showWarningNotification(
            currentSpending: 81.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1) // Still 1
    }

    func testResetNotificationStateIfBelow_UpperLimitReset() async {
        // Given - Show upper limit notification first
        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1)

        // When - Reset when spending is below upper limit
        await notificationManager.resetNotificationStateIfBelow(
            limitType: .upper,
            currentSpendingUSD: 95.0,
            warningLimitUSD: 75.0,
            upperLimitUSD: 100.0)

        // Then - Should be able to show upper limit notification again
        await notificationManager.showUpperLimitNotification(
            currentSpending: 101.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 2) // Should be 2 now
    }

    func testResetNotificationStateIfBelow_UpperLimitNotReset() async {
        // Given - Show upper limit notification first
        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // When - Don't reset when spending is still above upper limit
        await notificationManager.resetNotificationStateIfBelow(
            limitType: .upper,
            currentSpendingUSD: 110.0,
            warningLimitUSD: 75.0,
            upperLimitUSD: 100.0)

        // Then - Should not be able to show upper limit notification again
        await notificationManager.showUpperLimitNotification(
            currentSpending: 115.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 1) // Still 1
    }

    // MARK: - Session Reset Tests

    func testResetAllNotificationStatesForNewSession() async {
        // Given - Show both types of notifications
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 2)

        // When - Reset all states for new session
        await notificationManager.resetAllNotificationStatesForNewSession()

        // Then - Should be able to show both notifications again
        await notificationManager.showWarningNotification(
            currentSpending: 76.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        await notificationManager.showUpperLimitNotification(
            currentSpending: 106.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        XCTAssertEqual(mockNotificationCenter.addCallCount, 4) // Should be 4 total
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
