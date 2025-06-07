import Foundation
import Testing
@testable import VibeMeter

@Suite("CurrencyFormattingTests", .tags(.currency, .unit, .fast))
@MainActor
struct CurrencyFormattingTests {
    // MARK: - Test Data Types

    struct FormattingTestCase: CustomTestStringConvertible {
        let amount: Double
        let currencySymbol: String
        let localeIdentifier: String
        let expected: String
        let description: String

        var locale: Locale { Locale(identifier: localeIdentifier) }

        var testDescription: String {
            "\(currencySymbol)\(amount) (\(localeIdentifier)) → \(expected)"
        }
    }

    // MARK: - Amount Formatting Tests

    @Test("Basic amount formatting", arguments: [
        FormattingTestCase(
            amount: 123.45,
            currencySymbol: "$",
            localeIdentifier: "en_US",
            expected: "$123.45",
            description: "Basic formatting"),
        FormattingTestCase(
            amount: 100.0,
            currencySymbol: "€",
            localeIdentifier: "en_US",
            expected: "€100",
            description: "Whole number"),
        FormattingTestCase(
            amount: 42.5,
            currencySymbol: "£",
            localeIdentifier: "en_US",
            expected: "£42.5",
            description: "One decimal place"),
        FormattingTestCase(
            amount: 1_234_567.89,
            currencySymbol: "$",
            localeIdentifier: "en_US",
            expected: "$1,234,567.89",
            description: "Large number with separators"),
        FormattingTestCase(
            amount: 0.01,
            currencySymbol: "¢",
            localeIdentifier: "en_US",
            expected: "¢0.01",
            description: "Small decimal"),
        FormattingTestCase(
            amount: 0.0,
            currencySymbol: "$",
            localeIdentifier: "en_US",
            expected: "$0",
            description: "Zero amount"),
        FormattingTestCase(
            amount: -25.50,
            currencySymbol: "$",
            localeIdentifier: "en_US",
            expected: "$-25.5",
            description: "Negative amount"),
    ])
    func formatAmount(testCase: FormattingTestCase) {
        let result = CurrencyConversionHelper.formatAmount(
            testCase.amount,
            currencySymbol: testCase.currencySymbol,
            locale: testCase.locale)
        #expect(result == testCase.expected)
    }

    @Test("Locale-specific formatting", arguments: [
        FormattingTestCase(
            amount: 1234.56,
            currencySymbol: "€",
            localeIdentifier: "en_US",
            expected: "€1,234.56",
            description: "US format"),
        FormattingTestCase(
            amount: 1234.56,
            currencySymbol: "€",
            localeIdentifier: "de_DE",
            expected: "€1.234,56",
            description: "German format"),
        FormattingTestCase(
            amount: 1234.56,
            currencySymbol: "€",
            localeIdentifier: "fr_FR",
            expected: "€1\u{202F}234,56",
            description: "French format")
    ])
    func formatAmountWithLocale(testCase: FormattingTestCase) {
        let result = CurrencyConversionHelper.formatAmount(
            testCase.amount,
            currencySymbol: testCase.currencySymbol,
            locale: testCase.locale)
        #expect(result == testCase.expected)
    }

    @Test("Currency symbol handling", arguments: [
        FormattingTestCase(
            amount: 100.0,
            currencySymbol: "",
            localeIdentifier: "en_US",
            expected: "100",
            description: "Empty currency symbol"),
        FormattingTestCase(
            amount: 50.0,
            currencySymbol: "USD",
            localeIdentifier: "en_US",
            expected: "USD50",
            description: "Long currency symbol")
    ])
    func formatAmountWithSymbol(testCase: FormattingTestCase) {
        let result = CurrencyConversionHelper.formatAmount(
            testCase.amount,
            currencySymbol: testCase.currencySymbol,
            locale: testCase.locale)
        #expect(result == testCase.expected)
    }

    @Test("Special currency symbols", arguments: ["¥", "₹", "₩", "₽", "₪", "₦", "₨"])
    func formatAmountWithSpecialSymbol(symbol: String) {
        let amount = 100.0
        let locale = Locale(identifier: "en_US")

        let result = CurrencyConversionHelper.formatAmount(
            amount,
            currencySymbol: symbol,
            locale: locale)

        #expect(result.hasPrefix(symbol))
    }

    // MARK: - Precision and Rounding Tests

    struct RoundingTestCase: CustomTestStringConvertible {
        let amount: Double
        let expected: String
        let description: String

        var testDescription: String {
            "\(amount) → \(expected) (\(description))"
        }
    }

    @Test("Rounding behavior", arguments: [
        RoundingTestCase(amount: 123.456, expected: "$123.46", description: "Round up"),
        RoundingTestCase(amount: 123.454, expected: "$123.45", description: "Round down"),
        RoundingTestCase(amount: 123.455, expected: "$123.46", description: "Round half up"),
        RoundingTestCase(amount: 0.996, expected: "$1", description: "Round to whole number"),
        RoundingTestCase(amount: 0.004, expected: "$0", description: "Round to zero"),
    ])
    func formatAmountRounding(testCase: RoundingTestCase) {
        let result = CurrencyConversionHelper.formatAmount(
            testCase.amount,
            currencySymbol: "$",
            locale: Locale(identifier: "en_US"))
        #expect(result == testCase.expected)
    }

    @Test("Edge case handling", arguments: [
        FormattingTestCase(
            amount: 999_999_999.99,
            currencySymbol: "$",
            localeIdentifier: "en_US",
            expected: "$999,999,999.99",
            description: "Very large number"),
        FormattingTestCase(
            amount: Double.infinity,
            currencySymbol: "$",
            localeIdentifier: "en_US",
            expected: "$∞",
            description: "Infinity"),
        FormattingTestCase(
            amount: -Double.infinity,
            currencySymbol: "$",
            localeIdentifier: "en_US",
            expected: "$-∞",
            description: "Negative infinity")
    ])
    func formatAmountEdgeCases(testCase: FormattingTestCase) {
        let result = CurrencyConversionHelper.formatAmount(
            testCase.amount,
            currencySymbol: testCase.currencySymbol,
            locale: testCase.locale)
        #expect(result == testCase.expected)
    }
}
