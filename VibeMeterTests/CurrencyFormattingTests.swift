@testable import VibeMeter
import Testing

@Suite("CurrencyFormattingTests")
@MainActor
struct CurrencyFormattingTests {
    // MARK: - Amount Formatting Tests

    @Test("format amount  basic formatting  returns formatted string")

    func formatAmount_BasicFormatting_ReturnsFormattedString() {
        // Given
        let amount = 123.45
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "$123.45")
    }

    @Test("format amount whole number does not show unnecessary decimals")
    func formatAmount_WholeNumber_DoesNotShowUnnecessaryDecimals() {
        // Given
        let amount = 100.0
        let currencySymbol = "€"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "€100")
    }

    @Test("format amount one decimal place shows correctly")
    func formatAmount_OneDecimalPlace_ShowsCorrectly() {
        // Given
        let amount = 42.5
        let currencySymbol = "£"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "£42.5")
    }

    @Test("format amount large number formats with separators")
    func formatAmount_LargeNumber_FormatsWithSeparators() {
        // Given
        let amount = 1_234_567.89
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "$1,234,567.89")
    }

    @Test("format amount small decimal handles correctly")
    func formatAmount_SmallDecimal_HandlesCorrectly() {
        // Given
        let amount = 0.01
        let currencySymbol = "¢"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "¢0.01")
    }

    @Test("format amount zero amount formats correctly")
    func formatAmount_ZeroAmount_FormatsCorrectly() {
        // Given
        let amount = 0.0
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "$0")
    }

    @Test("format amount negative amount shows negative sign")
    func formatAmount_NegativeAmount_ShowsNegativeSign() {
        // Given
        let amount = -25.50
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "$-25.5")
    }

    @Test("format amount different locales respects local formatting")
    func formatAmount_DifferentLocales_RespectsLocalFormatting() {
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
            #expect(result == expectedFormat)
        }
    }

    @Test("format amount  empty currency symbol  handles gracefully")

    func formatAmount_EmptyCurrencySymbol_HandlesGracefully() {
        // Given
        let amount = 100.0
        let currencySymbol = ""
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "100")
    }

    @Test("format amount long currency symbol handles correctly")
    func formatAmount_LongCurrencySymbol_HandlesCorrectly() {
        // Given
        let amount = 50.0
        let currencySymbol = "USD"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "USD50")
    }

    @Test("format amount special currency symbols handles correctly")
    func formatAmount_SpecialCurrencySymbols_HandlesCorrectly() {
        // Given
        let amount = 100.0
        let specialSymbols = ["¥", "₹", "₩", "₽", "₪", "₦", "₨"]
        let locale = Locale(identifier: "en_US")

        for symbol in specialSymbols {
            // When
            let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: symbol, locale: locale)

            // Then
            #expect(result.hasPrefix(symbol) == true)
        }
    }

    // MARK: - Precision and Rounding Tests

    @Test("format amount  rounding behavior")

    func formatAmount_RoundingBehavior() {
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
            #expect(result == expected)
        }
    }

    @Test("format amount  very large numbers  handles correctly")

    func formatAmount_VeryLargeNumbers_HandlesCorrectly() {
        // Given
        let amount = 999_999_999.99
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)

        // Then
        #expect(result == "$999,999,999.99")
    }
}
