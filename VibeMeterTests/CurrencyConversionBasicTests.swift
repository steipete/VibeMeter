import Foundation
@testable import VibeMeter
import Testing

@Suite("Currency Conversion Basic Tests")
@MainActor
struct CurrencyConversionBasicTests {
    // MARK: - Currency Conversion Tests

    @Test("convert with valid rate performs correct conversion")
    func convertWithValidRatePerformsCorrectConversion() {
        // Given
        let amount = 100.0
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(result - 85.0) < 0.01)
    }

    @Test("convert zero amount returns zero")
    func convertZeroAmountReturnsZero() {
        // Given
        let amount = 0.0
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(result == 0.0)
    }

    @Test("convert with rate of one returns same amount")
    func convertWithRateOfOneReturnsSameAmount() {
        // Given
        let amount = 100.0
        let rate = 1.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(result == amount)
    }

    @Test("convert negative amount with valid rate")
    func convertNegativeAmountWithValidRate() {
        // Given
        let amount = -100.0
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(result - (-85.0)) < 0.01)
    }

    @Test("convert very large amount")
    func convertVeryLargeAmount() {
        // Given
        let amount = 1_000_000.0
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(result - 850_000.0) < 0.01)
    }

    @Test("convert very small amount")
    func convertVerySmallAmount() {
        // Given
        let amount = 0.01
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(result - 0.0085) < 0.0001)
    }

    // MARK: - Format Currency Tests

    @Test("format currency with USD shows dollar sign")
    func formatCurrencyWithUSDShowsDollarSign() {
        // Given
        let amount = 99.99
        let currencyCode = "USD"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "$99.99")
    }

    @Test("format currency with EUR shows euro sign")
    func formatCurrencyWithEURShowsEuroSign() {
        // Given
        let amount = 99.99
        let currencyCode = "EUR"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "€99.99")
    }

    @Test("format currency with GBP shows pound sign")
    func formatCurrencyWithGBPShowsPoundSign() {
        // Given
        let amount = 99.99
        let currencyCode = "GBP"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "£99.99")
    }

    @Test("format currency rounds to two decimal places")
    func formatCurrencyRoundsToTwoDecimalPlaces() {
        // Given
        let amount = 99.999
        let currencyCode = "USD"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "$100.00")
    }

    @Test("format currency with zero shows correct format")
    func formatCurrencyWithZeroShowsCorrectFormat() {
        // Given
        let amount = 0.0
        let currencyCode = "USD"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "$0.00")
    }

    @Test("format currency with negative amount")
    func formatCurrencyWithNegativeAmount() {
        // Given
        let amount = -99.99
        let currencyCode = "USD"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        // Formatter might show as -$99.99 or ($99.99) depending on locale
        #expect(formatted.contains("99.99"))
    }

    @Test("format currency with unknown currency code uses code as prefix")
    func formatCurrencyWithUnknownCurrencyCodeUsesCodeAsPrefix() {
        // Given
        let amount = 99.99
        let currencyCode = "XXX"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "XXX 99.99")
    }

    @Test("format currency with JPY shows yen sign")
    func formatCurrencyWithJPYShowsYenSign() {
        // Given
        let amount = 1000.0
        let currencyCode = "JPY"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "¥1,000")
    }

    @Test("format currency with very large amount")
    func formatCurrencyWithVeryLargeAmount() {
        // Given
        let amount = 1_234_567.89
        let currencyCode = "USD"

        // When
        let formatted = CurrencyConversionHelper.formatCurrency(
            amount: amount,
            currencyCode: currencyCode
        )

        // Then
        #expect(formatted == "$1,234,567.89")
    }
}