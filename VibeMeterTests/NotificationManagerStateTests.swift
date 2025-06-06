import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import VibeMeter

@Suite("NotificationManagerStateTests", .tags(.notifications, .unit))
@MainActor
struct NotificationManagerStateTests {
    private let notificationManager: TestableNotificationManager
    private let mockNotificationCenter: MockUNUserNotificationCenter

    init() async throws {
        mockNotificationCenter = MockUNUserNotificationCenter()
        notificationManager = TestableNotificationManager(notificationCenter: mockNotificationCenter)
    }

    // MARK: - Notification State Reset Tests

    @Test("reset notification state if below warning reset")
    func resetNotificationStateIfBelow_WarningReset() async {
        // Given - Show warning notification first
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        #expect(mockNotificationCenter.addCallCount == 1)

        // When - Reset when spending is below warning limit
        await notificationManager.resetNotificationStateIfBelow(
            limitType: .warning,
            currentSpendingUSD: 50.0,
            warningLimitUSD: 75.0,
            upperLimitUSD: 100.0)

        // Then - Should be able to show warning notification again
        await notificationManager.showWarningNotification(
            currentSpending: 76.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        #expect(mockNotificationCenter.addCallCount == 2)
    }

    @Test("reset notification state if below warning not reset")
    func resetNotificationStateIfBelow_WarningNotReset() async {
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

        #expect(mockNotificationCenter.addCallCount == 1)
    }

    @Test("reset notification state if below upper limit reset")
    func resetNotificationStateIfBelow_UpperLimitReset() async {
        // Given - Show upper limit notification first
        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        #expect(mockNotificationCenter.addCallCount == 1)

        // When - Reset when spending is below upper limit
        await notificationManager.resetNotificationStateIfBelow(
            limitType: .upper,
            currentSpendingUSD: 90.0,
            warningLimitUSD: 75.0,
            upperLimitUSD: 100.0)

        // Then - Should be able to show upper limit notification again
        await notificationManager.showUpperLimitNotification(
            currentSpending: 101.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        #expect(mockNotificationCenter.addCallCount == 2)
    }

    @Test("reset notification state if below upper limit not reset")
    func resetNotificationStateIfBelow_UpperLimitNotReset() async {
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

        #expect(mockNotificationCenter.addCallCount == 1)
    }

    @Test("reset all notification states for new session")
    func resetAllNotificationStatesForNewSession() async {
        // Given - Show both types of notifications
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        #expect(mockNotificationCenter.addCallCount == 2)

        // When - Reset all notification states
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

        #expect(mockNotificationCenter.addCallCount == 4)
    }
}

// MARK: - Test Support Classes

@MainActor
private final class TestableNotificationManager: NotificationManagerProtocol {
    private let notificationCenter: MockUNUserNotificationCenter
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

    func showWarningNotification(currentSpending _: Double, limitAmount _: Double, currencyCode _: String) async {
        guard !warningNotificationShown else { return }

        let content = UNMutableNotificationContent()
        content.title = "Spending Alert ⚠️"
        content.body = "You've reached your warning limit"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)

        try? await notificationCenter.add(request)
        warningNotificationShown = true
    }

    func showUpperLimitNotification(currentSpending _: Double, limitAmount _: Double, currencyCode _: String) async {
        guard !upperLimitNotificationShown else { return }

        let content = UNMutableNotificationContent()
        content.title = "Spending Limit Reached! 🚨"
        content.body = "You've exceeded your maximum limit!"
        content.sound = .defaultCritical

        let request = UNNotificationRequest(
            identifier: "upper_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)

        try? await notificationCenter.add(request)
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
        content.body = "Another instance of Vibe Meter is already running."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "instance_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)

        try? await notificationCenter.add(request)
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
        addedRequests.append(request)

        switch addResult {
        case .success:
            break
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
