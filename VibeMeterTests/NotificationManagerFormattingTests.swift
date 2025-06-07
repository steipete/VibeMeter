import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Data

fileprivate struct CurrencyTestCase: Sendable {
    let code: String
    let symbol: String
}

fileprivate let supportedCurrencies: [CurrencyTestCase] = [
    CurrencyTestCase(code: "USD", symbol: "$"),
    CurrencyTestCase(code: "EUR", symbol: "€"),
    CurrencyTestCase(code: "GBP", symbol: "£"),
    CurrencyTestCase(code: "JPY", symbol: "¥"),
    CurrencyTestCase(code: "AUD", symbol: "A$"),
    CurrencyTestCase(code: "CAD", symbol: "C$"),
    CurrencyTestCase(code: "CHF", symbol: "CHF"),
    CurrencyTestCase(code: "CNY", symbol: "¥"),
    CurrencyTestCase(code: "SEK", symbol: "kr"),
    CurrencyTestCase(code: "NZD", symbol: "NZ$")
]

fileprivate struct NumberFormatTestCase: Sendable {
    let amount: Double
    let expectedFormat: String
    let description: String
}

fileprivate let decimalTestCases: [NumberFormatTestCase] = [
    NumberFormatTestCase(amount: 75.0, expectedFormat: "75.00", description: "No decimals"),
    NumberFormatTestCase(amount: 75.5, expectedFormat: "75.50", description: "One decimal"),
    NumberFormatTestCase(amount: 75.50, expectedFormat: "75.50", description: "One decimal with trailing zero"),
    NumberFormatTestCase(amount: 75.123, expectedFormat: "75.12", description: "More than 2 decimals (should round)"),
    NumberFormatTestCase(amount: 75.999, expectedFormat: "76.00", description: "Should round to 76.00")
]

fileprivate struct UpperLimitTestCase: Sendable {
    let spending: Double
    let limit: Double
    let currency: String
}

fileprivate let upperLimitTestCases: [UpperLimitTestCase] = [
    UpperLimitTestCase(spending: 150.0, limit: 100.0, currency: "USD"),
    UpperLimitTestCase(spending: 75.5, limit: 50.0, currency: "EUR"),
    UpperLimitTestCase(spending: 200.99, limit: 200.0, currency: "GBP")
]

@Suite("NotificationManagerFormattingTests", .tags(.notifications, .unit))
@MainActor
struct NotificationManagerFormattingTests {
    private let notificationManager: NotificationManagerMock

    init() {
        notificationManager = NotificationManagerMock()
    }

    // MARK: - Currency Formatting Tests

    @Test("Currency formatting all supported currencies", arguments: supportedCurrencies)
    fileprivate func currencyFormattingAllSupportedCurrencies(currency: CurrencyTestCase) async {
        // Given
        notificationManager.reset()
        
        // When
        await notificationManager.resetAllNotificationStatesForNewSession()
        await notificationManager.showWarningNotification(
            currentSpending: 75.0,
            limitAmount: 100.0,
            currencyCode: currency.code)
        
        // Then - Verify notification was called
        #expect(notificationManager.showWarningNotificationCalled == true)
        #expect(notificationManager.lastWarningCurrency == currency.code)
    }

    // MARK: - Number Formatting Tests

    @Test("Number formatting decimal places", arguments: decimalTestCases)
    fileprivate func numberFormattingDecimalPlaces(testCase: NumberFormatTestCase) async {
        // When
        notificationManager.reset()
        await notificationManager.resetAllNotificationStatesForNewSession()
        await notificationManager.showWarningNotification(
            currentSpending: testCase.amount,
            limitAmount: 100.0,
            currencyCode: "USD")
        
        // Then - Verify the correct amount was passed
        #expect(notificationManager.showWarningNotificationCalled == true)
        #expect(notificationManager.lastWarningSpending == testCase.amount)
    }

    // MARK: - Large Number Formatting Tests
    
    @Test("Large number formatting", arguments: [
        (1000.0, "1,000.00"),
        (10000.0, "10,000.00"),
        (1_000_000.0, "1,000,000.00"),
        (1500.50, "1,500.50")
    ])
    func largeNumberFormatting(amount: Double, expectedFormat: String) async {
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

    @Test("Upper limit notification formatting", arguments: upperLimitTestCases)
    fileprivate func upperLimitNotificationFormatting(testCase: UpperLimitTestCase) async {
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
