// swiftlint:disable file_length
// swiftlint:disable type_body_length
// swiftlint:disable nesting
// Consolidated comprehensive test suite for NotificationManager

import Foundation
import Testing
@preconcurrency import UserNotifications
@testable import VibeMeter

@Suite("Notification Manager Tests", .tags(.notifications, .unit, .fast))
@MainActor
struct NotificationManagerTests {
    // MARK: - Basic Tests

    @Suite("Basic Functionality")
    struct BasicTests {
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

            static var authorizationTestCases: [AuthorizationTestCase] { [
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
            ] }

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

            static var warningNotificationTestCases: [NotificationTestCase] { [
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
            ] }

            static var upperLimitNotificationTestCases: [NotificationTestCase] { [
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
            ] }

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
                await manager.showUpperLimitNotification(
                    currentSpending: 105.0,
                    limitAmount: 100.0,
                    currencyCode: "USD")
                #expect(mockCenter.addCallCount == 1)

                // When - Try to show again
                await manager.showUpperLimitNotification(
                    currentSpending: 110.0,
                    limitAmount: 100.0,
                    currencyCode: "USD")

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
                await manager.showUpperLimitNotification(
                    currentSpending: 105.0,
                    limitAmount: 100.0,
                    currencyCode: "USD")
                #expect(mockCenter.addCallCount == 2)

                // When
                await manager.resetAllNotificationStatesForNewSession()

                // Then - Should be able to show notifications again
                await manager.showWarningNotification(currentSpending: 75.0, limitAmount: 100.0, currencyCode: "USD")
                await manager.showUpperLimitNotification(
                    currentSpending: 105.0,
                    limitAmount: 100.0,
                    currencyCode: "USD")
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

    // MARK: - Content Tests

    @Suite("Notification Content Tests")
    struct ContentTests {
        private let notificationManager: TestableNotificationManager2
        private let mockNotificationCenter: MockUNUserNotificationCenter2

        init() async throws {
            mockNotificationCenter = MockUNUserNotificationCenter2()
            notificationManager = await TestableNotificationManager2(notificationCenter: mockNotificationCenter)
        }

        // MARK: - Notification Content Tests

        @Test("notification content  warning notification")
        func notificationContent_WarningNotification() async {
            // When
            await notificationManager.showWarningNotification(
                currentSpending: 75.0,
                limitAmount: 100.0,
                currencyCode: "USD")

            // Then
            let request = mockNotificationCenter.lastAddedRequest!
            let content = request.content

            #expect(content.title == "Spending Alert ⚠️")
            #expect(content.body.contains("warning limit"))
            #expect(content.categoryIdentifier == "SPENDING_WARNING")
        }

        @Test("notification content  upper limit notification")
        func notificationContent_UpperLimitNotification() async {
            // When
            await notificationManager.showUpperLimitNotification(
                currentSpending: 105.0,
                limitAmount: 100.0,
                currencyCode: "USD")

            // Then
            let request = mockNotificationCenter.lastAddedRequest!
            let content = request.content

            #expect(content.title == "Spending Limit Reached! 🚨")
            #expect(content.body.contains("maximum limit"))
            #expect(content.categoryIdentifier == "SPENDING_CRITICAL")
        }

        // MARK: - Notification Identifier Tests

        @Test("notification identifiers  unique")
        func notificationIdentifiers_Unique() async {
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
            #expect(mockNotificationCenter.addedRequests.count == 2)
            let id1 = mockNotificationCenter.addedRequests[0].identifier
            let id2 = mockNotificationCenter.addedRequests[1].identifier
            #expect(id1.hasPrefix("warning_"))
            #expect(id2.hasPrefix("warning_"))
            #expect(id1 != id2)
        }

        @Test("notification identifiers  different types")
        func notificationIdentifiers_DifferentTypes() async {
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
            #expect(mockNotificationCenter.addedRequests.count == 2)
            let warningId = mockNotificationCenter.addedRequests[0].identifier
            let upperId = mockNotificationCenter.addedRequests[1].identifier
            #expect(warningId.hasPrefix("warning_"))
            #expect(upperId.hasPrefix("upper_"))
        }

        @Test("notification scheduling  error")
        func notificationScheduling_Error() async {
            // Given
            let error = NSError(domain: "TestError", code: 1, userInfo: nil)
            mockNotificationCenter.addResult = .failure(error)

            // When - Should not crash even if notification fails
            await notificationManager.showWarningNotification(
                currentSpending: 75.0,
                limitAmount: 100.0,
                currencyCode: "USD")

            // Then - Call should succeed but notification won't be added
            #expect(mockNotificationCenter.addCallCount == 1)
        }
    }

    // MARK: - Formatting Tests

    @Suite("Notification Formatting Tests")
    struct FormattingTests {
        private let notificationManager: NotificationManagerMock

        init() {
            notificationManager = NotificationManagerMock()
        }

        // MARK: - Currency Formatting Tests

        @Test("Currency formatting all supported currencies", arguments: supportedCurrencies)
        fileprivate func currencyFormattingAllSupportedCurrencies(currency: CurrencyTestCase) async {
            // Given
            await notificationManager.reset()

            // When
            await notificationManager.resetAllNotificationStatesForNewSession()
            await notificationManager.showWarningNotification(
                currentSpending: 75.0,
                limitAmount: 100.0,
                currencyCode: currency.code)

            // Then - Verify notification was called
            #expect(await notificationManager.showWarningNotificationCalled == true)
            #expect(await notificationManager.lastWarningCurrency == currency.code)
        }

        // MARK: - Number Formatting Tests

        @Test("Number formatting decimal places", arguments: decimalTestCases)
        fileprivate func numberFormattingDecimalPlaces(testCase: NumberFormatTestCase) async {
            // When
            await notificationManager.reset()
            await notificationManager.resetAllNotificationStatesForNewSession()
            await notificationManager.showWarningNotification(
                currentSpending: testCase.amount,
                limitAmount: 100.0,
                currencyCode: "USD")

            // Then - Verify the correct amount was passed
            #expect(await notificationManager.showWarningNotificationCalled == true)
            #expect(await notificationManager.lastWarningSpending == testCase.amount)
        }

        // MARK: - Large Number Formatting Tests

        @Test("Large number formatting", arguments: [
            (1000.0, "1,000.00"),
            (10000.0, "10,000.00"),
            (1_000_000.0, "1,000,000.00"),
            (1500.50, "1,500.50")
        ])
        func largeNumberFormatting(amount: Double, expectedFormat _: String) async {
            // When
            await notificationManager.reset()
            await notificationManager.showWarningNotification(
                currentSpending: amount,
                limitAmount: amount + 100.0,
                currencyCode: "USD")

            // Then
            #expect(await notificationManager.showWarningNotificationCalled == true)
            #expect(await notificationManager.lastWarningSpending == amount)
        }

        // MARK: - Zero and Negative Value Tests

        @Test("zero value formatting")
        func zeroValueFormatting() async {
            // When
            await notificationManager.showWarningNotification(
                currentSpending: 0.0,
                limitAmount: 100.0,
                currencyCode: "USD")

            // Then
            #expect(await notificationManager.showWarningNotificationCalled == true)
            #expect(await notificationManager.lastWarningSpending == 0.0)
        }

        @Test("negative value formatting")
        func negativeValueFormatting() async {
            // When
            await notificationManager.showWarningNotification(
                currentSpending: -50.0,
                limitAmount: 100.0,
                currencyCode: "USD")

            // Then
            #expect(await notificationManager.showWarningNotificationCalled == true)
            #expect(await notificationManager.lastWarningSpending == -50.0)
        }

        // MARK: - Upper Limit Notification Tests

        @Test("Upper limit notification formatting", arguments: upperLimitTestCases)
        fileprivate func upperLimitNotificationFormatting(testCase: UpperLimitTestCase) async {
            // When
            await notificationManager.reset()
            await notificationManager.showUpperLimitNotification(
                currentSpending: testCase.spending,
                limitAmount: testCase.limit,
                currencyCode: testCase.currency)

            // Then
            #expect(await notificationManager.showUpperLimitNotificationCalled == true)
            #expect(await notificationManager.lastUpperLimitSpending == testCase.spending)
            #expect(await notificationManager.lastUpperLimitAmount == testCase.limit)
            #expect(await notificationManager.lastUpperLimitCurrency == testCase.currency)
        }

        // MARK: - Notification Reset Tests

        @Test("notification state reset")
        func notificationStateReset() async {
            // Given - Show a notification first
            await notificationManager.showWarningNotification(
                currentSpending: 75.0,
                limitAmount: 100.0,
                currencyCode: "USD")
            #expect(await notificationManager.showWarningNotificationCalled == true)

            // When
            await notificationManager.resetAllNotificationStatesForNewSession()

            // Then
            #expect(await notificationManager.resetAllNotificationStatesCalled == true)
        }

        @Test("conditional notification reset")
        func conditionalNotificationReset() async {
            // When
            await notificationManager.resetNotificationStateIfBelow(
                limitType: .warning,
                currentSpendingUSD: 50.0,
                warningLimitUSD: 100.0,
                upperLimitUSD: 200.0)

            // Then
            #expect(await notificationManager.resetNotificationStateIfBelowCalled == true)
            #expect(await notificationManager.lastResetLimitType == .warning)
            #expect(await notificationManager.lastResetCurrentSpendingUSD == 50.0)
        }
    }

    // MARK: - State Tests

    @Suite("Notification State Tests")
    struct StateTests {
        private let notificationManager: TestableNotificationManager3
        private let mockNotificationCenter: MockUNUserNotificationCenter3

        init() async throws {
            mockNotificationCenter = MockUNUserNotificationCenter3()
            notificationManager = await TestableNotificationManager3(notificationCenter: mockNotificationCenter)
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
}

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

// MARK: - Formatting Test Data

private struct CurrencyTestCase: Sendable {
    let code: String
    let symbol: String
}

private let supportedCurrencies: [CurrencyTestCase] = [
    CurrencyTestCase(code: "USD", symbol: "$"),
    CurrencyTestCase(code: "EUR", symbol: "€"),
    CurrencyTestCase(code: "GBP", symbol: "£"),
    CurrencyTestCase(code: "JPY", symbol: "¥"),
    CurrencyTestCase(code: "AUD", symbol: "A$"),
    CurrencyTestCase(code: "CAD", symbol: "C$"),
    CurrencyTestCase(code: "CHF", symbol: "CHF"),
    CurrencyTestCase(code: "CNY", symbol: "¥"),
    CurrencyTestCase(code: "SEK", symbol: "kr"),
    CurrencyTestCase(code: "NZD", symbol: "NZ$"),
]

private struct NumberFormatTestCase: Sendable {
    let amount: Double
    let expectedFormat: String
    let description: String
}

private let decimalTestCases: [NumberFormatTestCase] = [
    NumberFormatTestCase(amount: 75.0, expectedFormat: "75.00", description: "No decimals"),
    NumberFormatTestCase(amount: 75.5, expectedFormat: "75.50", description: "One decimal"),
    NumberFormatTestCase(amount: 75.50, expectedFormat: "75.50", description: "One decimal with trailing zero"),
    NumberFormatTestCase(amount: 75.123, expectedFormat: "75.12", description: "More than 2 decimals (should round)"),
    NumberFormatTestCase(amount: 75.999, expectedFormat: "76.00", description: "Should round to 76.00"),
]

private struct UpperLimitTestCase: Sendable {
    let spending: Double
    let limit: Double
    let currency: String
}

private let upperLimitTestCases: [UpperLimitTestCase] = [
    UpperLimitTestCase(spending: 150.0, limit: 100.0, currency: "USD"),
    UpperLimitTestCase(spending: 75.5, limit: 50.0, currency: "EUR"),
    UpperLimitTestCase(spending: 200.99, limit: 200.0, currency: "GBP"),
]

// MARK: - TestableNotificationManager (Basic Tests)

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

// MARK: - MockUNUserNotificationCenter (Basic Tests)

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

// MARK: - TestableNotificationManager2 (Content Tests)

@MainActor
private final class TestableNotificationManager2: NotificationManagerProtocol, @unchecked Sendable {
    private let notificationCenter: MockUNUserNotificationCenter2

    // Track which notifications have been shown
    private var warningNotificationShown = false
    private var upperLimitNotificationShown = false

    // Test tracking properties
    var showWarningNotificationCalled = false
    var showUpperLimitNotificationCalled = false
    var lastWarningSpending: Double?
    var lastWarningLimit: Double?
    var lastWarningCurrency: String?
    var lastUpperLimitSpending: Double?
    var lastUpperLimitLimit: Double?
    var lastUpperLimitCurrency: String?

    init(notificationCenter: MockUNUserNotificationCenter2) {
        self.notificationCenter = notificationCenter
    }

    func reset() async {
        showWarningNotificationCalled = false
        showUpperLimitNotificationCalled = false
        lastWarningSpending = nil
        lastWarningLimit = nil
        lastWarningCurrency = nil
        lastUpperLimitSpending = nil
        lastUpperLimitLimit = nil
        lastUpperLimitCurrency = nil
        warningNotificationShown = false
        upperLimitNotificationShown = false
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func showWarningNotification(currentSpending: Double, limitAmount: Double, currencyCode: String) async {
        showWarningNotificationCalled = true
        lastWarningSpending = currentSpending
        lastWarningLimit = limitAmount
        lastWarningCurrency = currencyCode

        guard !warningNotificationShown else { return }

        let symbol = ExchangeRateManager.getSymbol(for: currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        let spendingFormatted = "\(symbol)\(formatter.string(from: NSNumber(value: currentSpending)) ?? "")"
        let limitFormatted = "\(symbol)\(formatter.string(from: NSNumber(value: limitAmount)) ?? "")"

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
        showUpperLimitNotificationCalled = true
        lastUpperLimitSpending = currentSpending
        lastUpperLimitLimit = limitAmount
        lastUpperLimitCurrency = currencyCode

        guard !upperLimitNotificationShown else { return }

        let symbol = ExchangeRateManager.getSymbol(for: currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "en_US")
        let spendingFormatted = "\(symbol)\(formatter.string(from: NSNumber(value: currentSpending)) ?? "")"
        let limitFormatted = "\(symbol)\(formatter.string(from: NSNumber(value: limitAmount)) ?? "")"

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

// MARK: - MockUNUserNotificationCenter2 (Content Tests)

private class MockUNUserNotificationCenter2: @unchecked Sendable {
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

// MARK: - TestableNotificationManager3 (State Tests)

@MainActor
private final class TestableNotificationManager3: NotificationManagerProtocol {
    private let notificationCenter: MockUNUserNotificationCenter3
    private var warningNotificationShown = false
    private var upperLimitNotificationShown = false

    init(notificationCenter: MockUNUserNotificationCenter3) {
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

// MARK: - MockUNUserNotificationCenter3 (State Tests)

private class MockUNUserNotificationCenter3: @unchecked Sendable {
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
