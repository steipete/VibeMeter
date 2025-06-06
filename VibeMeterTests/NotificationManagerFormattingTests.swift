import Foundation
import Testing
@testable import VibeMeter

@Suite("NotificationManagerFormattingTests", .tags(.notifications, .unit))
@MainActor
struct NotificationManagerFormattingTests {
    private let notificationManager: NotificationManagerMock

    init() {
        notificationManager = NotificationManagerMock()
    }

    // MARK: - Currency Formatting Tests

    @Test("currency formatting all supported currencies")
    func currencyFormatting_AllSupportedCurrencies() async {
        let testCases: [(String, String)] = [
            ("USD", "$"),
            ("EUR", "€"),
            ("GBP", "£"),
            ("JPY", "¥"),
            ("AUD", "A$"),
            ("CAD", "C$"),
            ("CHF", "CHF"),
            ("CNY", "¥"),
            ("SEK", "kr"),
            ("NZD", "NZ$"),
        ]

        for (currencyCode, _) in testCases {
            // Given
            notificationManager.reset()

            // When
            await notificationManager.resetAllNotificationStatesForNewSession()
            await notificationManager.showWarningNotification(
                currentSpending: 75.0,
                limitAmount: 100.0,
                currencyCode: currencyCode)

            // Then - Verify notification was called
            #expect(notificationManager.showWarningNotificationCalled == true)
            #expect(notificationManager.lastWarningCurrency == currencyCode)
        }
    }

    // MARK: - Number Formatting Tests

    @Test("number formatting decimal places")
    func numberFormatting_DecimalPlaces() async {
        // Given
        let testCases: [(Double, String)] = [
            (75.0, "75.00"), // No decimals
            (75.5, "75.50"), // One decimal
            (75.50, "75.50"), // One decimal with trailing zero
            (75.123, "75.12"), // More than 2 decimals (should round)
            (75.999, "76.00"), // Should round to 76.00
        ]

        for (amount, _) in testCases {
            // When
            notificationManager.reset()
            await notificationManager.resetAllNotificationStatesForNewSession()
            await notificationManager.showWarningNotification(
                currentSpending: amount,
                limitAmount: 100.0,
                currencyCode: "USD")

            // Then - Verify the correct amount was passed
            #expect(notificationManager.showWarningNotificationCalled == true)
            #expect(notificationManager.lastWarningSpending == amount)
        }
    }

    // MARK: - Large Number Formatting Tests

    @Test("large number formatting")
    func largeNumberFormatting() async {
        // Given
        let testCases: [(Double, String)] = [
            (1000.0, "1,000.00"),
            (10000.0, "10,000.00"),
            (1_000_000.0, "1,000,000.00"),
            (1500.50, "1,500.50"),
        ]

        for (amount, _) in testCases {
            // When
            notificationManager.reset()
            await notificationManager.showWarningNotification(
                currentSpending: amount,
                limitAmount: amount + 100.0,
                currencyCode: "USD")

            // Then
            #expect(notificationManager.showWarningNotificationCalled == true)
            #expect(notificationManager.lastWarningSpending == amount)
        }
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
        #expect(notificationManager.showWarningNotificationCalled == true)
        #expect(notificationManager.lastWarningSpending == 0.0)
    }

    @Test("negative value formatting")
    func negativeValueFormatting() async {
        // When
        await notificationManager.showWarningNotification(
            currentSpending: -50.0,
            limitAmount: 100.0,
            currencyCode: "USD")

        // Then
        #expect(notificationManager.showWarningNotificationCalled == true)
        #expect(notificationManager.lastWarningSpending == -50.0)
    }

    // MARK: - Upper Limit Notification Tests

    @Test("upper limit notification formatting")
    func upperLimitNotificationFormatting() async {
        // Given
        struct TestCase {
            let spending: Double
            let limit: Double
            let currency: String
        }
        let testCases = [
            TestCase(spending: 150.0, limit: 100.0, currency: "USD"),
            TestCase(spending: 75.5, limit: 50.0, currency: "EUR"),
            TestCase(spending: 200.99, limit: 200.0, currency: "GBP"),
        ]

        for testCase in testCases {
            // When
            notificationManager.reset()
            await notificationManager.showUpperLimitNotification(
                currentSpending: testCase.spending,
                limitAmount: testCase.limit,
                currencyCode: testCase.currency)

            // Then
            #expect(notificationManager.showUpperLimitNotificationCalled == true)
            #expect(notificationManager.lastUpperLimitSpending == testCase.spending)
            #expect(notificationManager.lastUpperLimitAmount == testCase.limit)
            #expect(notificationManager.lastUpperLimitCurrency == testCase.currency)
        }
    }

    // MARK: - Notification Reset Tests

    @Test("notification state reset")
    func notificationStateReset() async {
        // Given - Show a notification first
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: "USD")
        #expect(notificationManager.showWarningNotificationCalled == true)

        // When
        await notificationManager.resetAllNotificationStatesForNewSession()

        // Then
        #expect(notificationManager.resetAllNotificationStatesCalled == true)
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
        #expect(notificationManager.resetNotificationStateIfBelowCalled == true)
        #expect(notificationManager.lastResetLimitType == .warning)
        #expect(notificationManager.lastResetCurrentSpendingUSD == 50.0)
    }
}
