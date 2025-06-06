import Foundation
@preconcurrency import UserNotifications
@testable import VibeMeter
import Testing

@Suite("NotificationManagerBasicTests")
@MainActor
struct NotificationManagerBasicTests {
    private let notificationManager: TestableNotificationManager
    private let mockNotificationCenter: MockUNUserNotificationCenter

    init() async throws {
        await MainActor.run {  }
        mockNotificationCenter = MockUNUserNotificationCenter()
        notificationManager = TestableNotificationManager(notificationCenter: mockNotificationCenter)
    }

    // MARK: - Authorization Tests

    @Test("request authorization success")
    func requestAuthorization_Success() async {
        // Given
        mockNotificationCenter.authorizationResult = .success(true)

        // When
        let result = await notificationManager.requestAuthorization()

        // Then
        #expect(result == true)
        #expect(mockNotificationCenter.lastRequestedOptions == [.alert])
    }

    @Test("request authorization denied")
    func requestAuthorization_Denied() async {
        // Given
        mockNotificationCenter.authorizationResult = .success(false)

        // When
        let result = await notificationManager.requestAuthorization()

        // Then
        #expect(result == false)
    }

    @Test("request authorization error")
    func requestAuthorization_Error() async {
        // Given
        let error = NSError(domain: "TestError", code: 1, userInfo: nil)
        mockNotificationCenter.authorizationResult = .failure(error)

        // When
        let result = await notificationManager.requestAuthorization()

        // Then
        #expect(result == false)
    }

    // MARK: - Warning Notification Tests

    @Test("show warning notification first time")
    func showWarningNotification_FirstTime() async {
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
        #expect(mockNotificationCenter.addCallCount == 1)
        let request = mockNotificationCenter.lastAddedRequest!
        #expect(request.content.title == "Spending Alert ⚠️")
        #expect(request.content.body.contains("$100.00"))
        #expect(request.trigger == nil)
    }

    @Test("show warning notification different currency")
    func showWarningNotification_DifferentCurrency() async {
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
        #expect(request.content.body.contains("€82.30"))
    }
    }

    @Test("show warning notification  already shown")

    func showWarningNotification_AlreadyShown() async {
        // Given - Show notification once
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        #expect(mockNotificationCenter.addCallCount == 1)

        // Then - Should not trigger another notification
        #expect(mockNotificationCenter.addCallCount == 1)

    func showUpperLimitNotification_FirstTime() async {
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
        #expect(mockNotificationCenter.addCallCount == 1)
        #expect(request.content.title == "Spending Limit Reached! 🚨")
        #expect(request.content.body.contains("$100.00")
        #expect(request.content.interruptionLevel == .critical)

    func showUpperLimitNotification_AlreadyShown() async {
        // Given - Show notification once
        await notificationManager.showUpperLimitNotification(
            currentSpending: 105.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        #expect(mockNotificationCenter.addCallCount == 1)

        // Then - Should not trigger another notification
        #expect(mockNotificationCenter.addCallCount == 1) {
        self.notificationCenter = notificationCenter
        super.init()
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        guard warningNotificationShown else {
            return
        }

        let symbol = currencyCode == "USD" ? "$" : (currencyCode == "EUR" ? "€" : currencyCode)
        let spendingFormatted = "\(symbol)\(String(format: "%.2f", currentSpending))"
        let limitFormatted = "\(symbol)\(String(format: "%.2f", limitAmount))"

        let content = UNMutableNotificationContent()
        content.title = "Spending Alert ⚠️"
        content.body = "You've reached \(spendingFormatted) of your \(limitFormatted) warning limit"
        content.sound = .default
        content.categoryIdentifier = "SPENDING_WARNING"

        let request = UNNotificationRequest(
            identifier: "warning_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil)

        notificationCenter.add(request, withCompletionHandler: nil)
        warningNotificationShown = true
    }

    func showUpperLimitNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        guard !upperLimitNotificationShown else {
            return
        }

        let symbol = currencyCode == "USD" ? "$" : (currencyCode == "EUR" ? "€" : currencyCode)
        let spendingFormatted = "\(symbol)\(String(format: "%.2f", currentSpending))"
        let limitFormatted = "\(symbol)\(String(format: "%.2f", limitAmount))"

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

        notificationCenter.add(request, withCompletionHandler: nil)
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

    @Test("reset all notification states for new session")

    func resetAllNotificationStatesForNewSession() async {
        warningNotificationShown = false
        upperLimitNotificationShown = false
    }

    @Test("show instance already running notification")

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

        notificationCenter.add(request, withCompletionHandler: nil)
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
        completionHandler: @escaping (Bool, Error?) -> Void) {
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
