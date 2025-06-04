@testable import VibeMeter
import XCTest

@MainActor
final class CurrencyFormattingTests: XCTestCase {
    // MARK: - Amount Formatting Tests

    func testFormatAmount_BasicFormatting_ReturnsFormattedString() {
        // Given
        let amount = 123.45
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "$123.45", "Should format basic amount correctly")
    }

    func testFormatAmount_WholeNumber_DoesNotShowUnnecessaryDecimals() {
        // Given
        let amount = 100.0
        let currencySymbol = "€"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "€100", "Should not show unnecessary decimals for whole numbers")
    }

    func testFormatAmount_OneDecimalPlace_ShowsCorrectly() {
        // Given
        let amount = 42.5
        let currencySymbol = "£"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "£42.5", "Should show one decimal place correctly")
    }

    func testFormatAmount_LargeNumber_FormatsWithSeparators() {
        // Given
        let amount = 1_234_567.89
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "$1,234,567.89", "Should format large numbers with thousand separators")
    }

    func testFormatAmount_SmallDecimal_HandlesCorrectly() {
        // Given
        let amount = 0.01
        let currencySymbol = "¢"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "¢0.01", "Should handle small decimal amounts correctly")
    }

    func testFormatAmount_ZeroAmount_FormatsCorrectly() {
        // Given
        let amount = 0.0
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "$0", "Should format zero amount correctly")
    }

    func testFormatAmount_NegativeAmount_ShowsNegativeSign() {
        // Given
        let amount = -25.50
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "$-25.5", "Should handle negative amounts correctly")
    }

    func testFormatAmount_DifferentLocales_RespectsLocalFormatting() {
        // Given
        let amount = 1234.56
        let currencySymbol = "€"

        // Test different locales
        let testCases = [
            (Locale(identifier: "en_US"), "€1,234.56"), // US format
            (Locale(identifier: "de_DE"), "€1.234,56"), // German format
            (Locale(identifier: "fr_FR"), "€1\u{202F}234,56"), // French format (narrow no-break space)
        ]

        for (locale, expectedFormat) in testCases {
            // When
            let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

            // Then
            XCTAssertEqual(result, expectedFormat, "Should respect \(locale.identifier) formatting")
        }
    }

    func testFormatAmount_EmptyCurrencySymbol_HandlesGracefully() {
        // Given
        let amount = 100.0
        let currencySymbol = ""
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "100", "Should handle empty currency symbol gracefully")
    }

    func testFormatAmount_LongCurrencySymbol_HandlesCorrectly() {
        // Given
        let amount = 50.0
        let currencySymbol = "USD"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "USD50", "Should handle long currency symbols correctly")
    }

    func testFormatAmount_SpecialCurrencySymbols_HandlesCorrectly() {
        // Given
        let amount = 100.0
        let specialSymbols = ["¥", "₹", "₩", "₽", "₪", "₦", "₨"]
        let locale = Locale(identifier: "en_US")

        for symbol in specialSymbols {
            // When
            let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: symbol, locale: locale)

            // Then
            XCTAssertTrue(result.hasPrefix(symbol), "Should handle special currency symbol: \(symbol)")
            XCTAssertTrue(result.contains("100"), "Should contain the formatted amount")
        }
    }

    // MARK: - Precision and Rounding Tests

    func testFormatAmount_RoundingBehavior() {
        // Given
        let testCases = [
            (123.456, "$123.46"), // Round up
            (123.454, "$123.45"), // Round down
            (123.455, "$123.46"), // Round half up (banker's rounding)
            (0.996, "$1"), // Round to whole number
            (0.004, "$0"), // Round to zero
        ]
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        for (amount, expected) in testCases {
            // When
            let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

            // Then
            XCTAssertEqual(result, expected, "Should handle rounding correctly for \(amount)")
        }
    }

    func testFormatAmount_VeryLargeNumbers_HandlesCorrectly() {
        // Given
        let amount = 999_999_999.99
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        XCTAssertEqual(result, "$999,999,999.99", "Should handle very large numbers correctly")
    }
}
