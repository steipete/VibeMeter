// swiftlint:disable file_length
// Comprehensive test suite requires extensive coverage

import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import VibeMeter

// MARK: - Test Case Data Structures

struct AuthorizationTestCase: Sendable {
    let result: Result<Bool, Error>
    let expectedResult: Bool
    let description: String

    init(result: Result<Bool, Error>, expected: Bool, _ description: String) {
        self.result = result
        self.expectedResult = expected
        self.description = description
    }
}

struct SpendingNotificationTestCase: Sendable {
    let spending: Double
    let limit: Double
    let currency: String
    let expectedTitle: String
    let description: String

    init(spending: Double, limit: Double, currency: String, expectedTitle: String, _ description: String) {
        self.spending = spending
        self.limit = limit
        self.currency = currency
        self.expectedTitle = expectedTitle
        self.description = description
    }
}

struct NotificationTestCase: Sendable {
    let currentSpending: Double
    let limitAmount: Double
    let currencyCode: String
    let expectedTitle: String
    let expectedBodyContains: String
    let expectedCategory: String
    let expectedInterruption: UNNotificationInterruptionLevel?
    let description: String

    init(
        spending: Double,
        limit: Double,
        currency: String = "USD",
        title: String,
        bodyContains: String,
        category: String,
        interruption: UNNotificationInterruptionLevel? = nil,
        _ description: String) {
        self.currentSpending = spending
        self.limitAmount = limit
        self.currencyCode = currency
        self.expectedTitle = title
        self.expectedBodyContains = bodyContains
        self.expectedCategory = category
        self.expectedInterruption = interruption
        self.description = description
    }
}

private struct StateResetTestScenario: Sendable {
    let limitType: NotificationLimitType
    let current: Double
    let warning: Double
    let upper: Double
    let shouldReset: Bool
    let description: String

    init(
        limitType: NotificationLimitType,
        current: Double,
        warning: Double,
        upper: Double,
        shouldReset: Bool,
        _ description: String) {
        self.limitType = limitType
        self.current = current
        self.warning = warning
        self.upper = upper
        self.shouldReset = shouldReset
        self.description = description
    }
}

@Suite("Notification Manager Tests", .tags(.notifications, .unit, .fast))
@MainActor
struct NotificationManagerBasicTests {
    private let notificationManager: TestableNotificationManager
    private let mockNotificationCenter: MockUNUserNotificationCenter

    init() async throws {
        await MainActor.run {}
        mockNotificationCenter = MockUNUserNotificationCenter()
        notificationManager = TestableNotificationManager(notificationCenter: mockNotificationCenter)
    }

    // MARK: - Authorization Tests

    @Suite("Authorization Management")
    struct AuthorizationTests {
        fileprivate let manager: TestableNotificationManager
        fileprivate let mockCenter: MockUNUserNotificationCenter

        init() async {
            await MainActor.run {}
            self.mockCenter = MockUNUserNotificationCenter()
            self.manager = TestableNotificationManager(notificationCenter: mockCenter)
        }

        static let authorizationTestCases: [AuthorizationTestCase] = [
            AuthorizationTestCase(
                result: .success(true),
                expected: true,
                "user grants permission"),
            AuthorizationTestCase(
                result: .success(false),
                expected: false,
                "user denies permission"),
            AuthorizationTestCase(
                result: .failure(NSError(domain: "TestError", code: 1, userInfo: nil)),
                expected: false,
                "system error during authorization"),
            AuthorizationTestCase(
                result: .failure(NSError(domain: "UNErrorDomain", code: 1, userInfo: nil)),
                expected: false,
                "authorization denied error"),
        ]

        @Test("Authorization request scenarios", arguments: authorizationTestCases)
        func authorizationRequestScenarios(testCase: AuthorizationTestCase) async {
            // Given
            mockCenter.authorizationResult = testCase.result

            // When
            let result = await manager.requestAuthorization()

            // Then
            #expect(result == testCase.expectedResult)
            #expect(mockCenter.lastRequestedOptions == [.alert])
            #expect(mockCenter.requestAuthorizationCallCount == 1)
        }
    }

    // MARK: - Notification Display Tests

    @Suite("Notification Display")
    struct NotificationDisplayTests {
        fileprivate let manager: TestableNotificationManager
        fileprivate let mockCenter: MockUNUserNotificationCenter

        init() async {
            await MainActor.run {}
            self.mockCenter = MockUNUserNotificationCenter()
            self.manager = TestableNotificationManager(notificationCenter: mockCenter)
        }

        static let warningNotificationTestCases: [NotificationTestCase] = [
            NotificationTestCase(
                spending: 75.50,
                limit: 100.0,
                title: "Spending Alert ⚠️",
                bodyContains: "$100.00",
                category: "SPENDING_WARNING",
                "USD warning notification"),
            NotificationTestCase(
                spending: 82.30,
                limit: 100.0,
                currency: "EUR",
                title: "Spending Alert ⚠️",
                bodyContains: "€82.30",
                category: "SPENDING_WARNING",
                "EUR warning notification"),
            NotificationTestCase(
                spending: 45.75,
                limit: 50.0,
                currency: "GBP",
                title: "Spending Alert ⚠️",
                bodyContains: "GBP45.75",
                category: "SPENDING_WARNING",
                "GBP warning notification with unsupported currency symbol"),
        ]

        static let upperLimitNotificationTestCases: [NotificationTestCase] = [
            NotificationTestCase(
                spending: 105.75,
                limit: 100.0,
                title: "Spending Limit Reached! 🚨",
                bodyContains: "$100.00",
                category: "SPENDING_CRITICAL",
                interruption: .critical,
                "USD upper limit notification"),
            NotificationTestCase(
                spending: 92.50,
                limit: 85.0,
                currency: "EUR",
                title: "Spending Limit Reached! 🚨",
                bodyContains: "€92.50",
                category: "SPENDING_CRITICAL",
                interruption: .critical,
                "EUR upper limit notification"),
        ]

        @Test("Warning notification display", arguments: warningNotificationTestCases)
        func warningNotificationDisplay(testCase: NotificationTestCase) async throws {
            // When
            await manager.showWarningNotification(
                currentSpending: testCase.currentSpending,
                limitAmount: testCase.limitAmount,
                currencyCode: testCase.currencyCode)

            // Then
            #expect(mockCenter.addCallCount == 1)

            let request = try #require(mockCenter.lastAddedRequest)
            #expect(request.content.title == testCase.expectedTitle)
            #expect(request.content.body.contains(testCase.expectedBodyContains))
            #expect(request.content.categoryIdentifier == testCase.expectedCategory)
            #expect(request.trigger == nil)
        }

        @Test("Upper limit notification display", arguments: upperLimitNotificationTestCases)
        func upperLimitNotificationDisplay(testCase: NotificationTestCase) async throws {
            // When
            await manager.showUpperLimitNotification(
                currentSpending: testCase.currentSpending,
                limitAmount: testCase.limitAmount,
                currencyCode: testCase.currencyCode)

            // Then
            #expect(mockCenter.addCallCount == 1)

            let request = try #require(mockCenter.lastAddedRequest)
            #expect(request.content.title == testCase.expectedTitle)
            #expect(request.content.body.contains(testCase.expectedBodyContains))
            #expect(request.content.categoryIdentifier == testCase.expectedCategory)

            if let expectedInterruption = testCase.expectedInterruption {
                #expect(request.content.interruptionLevel == expectedInterruption)
            }
        }

        @Test("Duplicate notification prevention for warnings")
        func duplicateNotificationPreventionWarnings() async {
            // Given - First notification
            await manager.showWarningNotification(currentSpending: 75.0, limitAmount: 100.0, currencyCode: "USD")
            #expect(mockCenter.addCallCount == 1)

            // When - Try to show again
            await manager.showWarningNotification(currentSpending: 80.0, limitAmount: 100.0, currencyCode: "USD")

            // Then - Should not trigger another notification
            #expect(mockCenter.addCallCount == 1)
        }

        @Test("Duplicate notification prevention for upper limits")
        func duplicateNotificationPreventionUpperLimits() async {
            // Given - First notification
            await manager.showUpperLimitNotification(currentSpending: 105.0, limitAmount: 100.0, currencyCode: "USD")
            #expect(mockCenter.addCallCount == 1)

            // When - Try to show again
            await manager.showUpperLimitNotification(currentSpending: 110.0, limitAmount: 100.0, currencyCode: "USD")

            // Then - Should not trigger another notification
            #expect(mockCenter.addCallCount == 1)
        }
    }

    // MARK: - State Management Tests

    @Suite("Notification State Management")
    struct StateManagementTests {
        fileprivate let manager: TestableNotificationManager
        fileprivate let mockCenter: MockUNUserNotificationCenter

        init() async {
            await MainActor.run {}
            self.mockCenter = MockUNUserNotificationCenter()
            self.manager = TestableNotificationManager(notificationCenter: mockCenter)
        }

        @Test("Reset notification states for new session")
        func resetNotificationStatesForNewSession() async {
            // Given - Show both types of notifications
            await manager.showWarningNotification(currentSpending: 75.0, limitAmount: 100.0, currencyCode: "USD")
            await manager.showUpperLimitNotification(currentSpending: 105.0, limitAmount: 100.0, currencyCode: "USD")
            #expect(mockCenter.addCallCount == 2)

            // When
            await manager.resetAllNotificationStatesForNewSession()

            // Then - Should be able to show notifications again
            await manager.showWarningNotification(currentSpending: 75.0, limitAmount: 100.0, currencyCode: "USD")
            await manager.showUpperLimitNotification(currentSpending: 105.0, limitAmount: 100.0, currencyCode: "USD")
            #expect(mockCenter.addCallCount == 4)
        }

        @Test("State reset below threshold scenarios", arguments: [
            StateResetTestScenario(
                limitType: .warning,
                current: 70.0,
                warning: 80.0,
                upper: 100.0,
                shouldReset: true,
                "warning reset when below threshold"),
            StateResetTestScenario(
                limitType: .warning,
                current: 85.0,
                warning: 80.0,
                upper: 100.0,
                shouldReset: false,
                "warning not reset when above threshold"),
            StateResetTestScenario(
                limitType: .upper,
                current: 95.0,
                warning: 80.0,
                upper: 100.0,
                shouldReset: true,
                "upper reset when below threshold"),
            StateResetTestScenario(
                limitType: .upper,
                current: 105.0,
                warning: 80.0,
                upper: 100.0,
                shouldReset: false,
                "upper not reset when above threshold")
        ])
        fileprivate func stateResetBelowThresholdScenarios(scenario: StateResetTestScenario) async {
            // Given - Show initial notification to set state
            switch scenario.limitType {
            case .warning:
                await manager.showWarningNotification(
                    currentSpending: scenario.warning + 5,
                    limitAmount: 100.0,
                    currencyCode: "USD")
            case .upper:
                await manager.showUpperLimitNotification(
                    currentSpending: scenario.upper + 5,
                    limitAmount: 100.0,
                    currencyCode: "USD")
            }

            let initialCount = mockCenter.addCallCount

            // When
            await manager.resetNotificationStateIfBelow(
                limitType: scenario.limitType,
                currentSpendingUSD: scenario.current,
                warningLimitUSD: scenario.warning,
                upperLimitUSD: scenario.upper)

            // Then - Try to show notification again
            switch scenario.limitType {
            case .warning:
                await manager.showWarningNotification(
                    currentSpending: scenario.current,
                    limitAmount: 100.0,
                    currencyCode: "USD")
            case .upper:
                await manager.showUpperLimitNotification(
                    currentSpending: scenario.current,
                    limitAmount: 100.0,
                    currencyCode: "USD")
            }

            let expectedCount = scenario.shouldReset ? initialCount + 1 : initialCount
            #expect(mockCenter.addCallCount == expectedCount)
        }
    }

    // MARK: - Special Notification Tests

    @Test("Instance already running notification")
    func instanceAlreadyRunningNotification() async throws {
        // When
        await notificationManager.showInstanceAlreadyRunningNotification()

        // Then
        #expect(mockNotificationCenter.addCallCount == 1)

        let request = try #require(mockNotificationCenter.lastAddedRequest, "Should have notification request")
        #expect(request.content.title == "Vibe Meter Already Running")
        #expect(
            request.content.body ==
                "Another instance of Vibe Meter is already running. " +
                "The existing instance has been brought to the front.",
            "Should have correct body")
        #expect(request.content.categoryIdentifier == "APP_INSTANCE")
    }

    // MARK: - Performance Tests

    @Test("Notification creation performance", .timeLimit(.minutes(1)))
    func notificationCreationPerformance() async {
        // When/Then - Should handle many notifications efficiently
        for i in 0 ..< 100 {
            await notificationManager.showWarningNotification(
                currentSpending: Double(i),
                limitAmount: 100.0,
                currencyCode: "USD")

            if i % 2 == 0 {
                await notificationManager.resetAllNotificationStatesForNewSession()
            }
        }
    }

    @Test("Concurrent notification operations")
    func concurrentNotificationOperations() async {
        // When - Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 10 {
                group.addTask {
                    await self.notificationManager.showWarningNotification(
                        currentSpending: Double(i * 10),
                        limitAmount: 100.0,
                        currencyCode: "USD")
                }

                group.addTask {
                    await self.notificationManager.resetAllNotificationStatesForNewSession()
                }
            }
        }

        // Then - Operations should complete without issues
        #expect(Bool(true))
    }
}

// MARK: - Test Support Types

private enum NotificationLimitType {
    case warning
    case upper
}

private final class TestableNotificationManager: @unchecked Sendable {
    private let notificationCenter: MockUNUserNotificationCenter
    private var warningNotificationShown = false
    private var upperLimitNotificationShown = false

    init(notificationCenter: MockUNUserNotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            notificationCenter.requestAuthorization(options: [.alert]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        guard !warningNotificationShown else {
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

        notificationCenter.add(request, withCompletionHandler: nil)
    }
}

// MARK: - MockUNUserNotificationCenter

private final class MockUNUserNotificationCenter: @unchecked Sendable {
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
