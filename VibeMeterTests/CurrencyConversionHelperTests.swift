@testable import VibeMeter
import XCTest

@MainActor
final class CurrencyConversionHelperTests: XCTestCase {
    // MARK: - Currency Conversion Tests

    func testConvert_WithValidRate_PerformsCorrectConversion() {
        // Given
        let amount = 100.0
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 85.0, accuracy: 0.001, "Should convert 100 * 0.85 = 85")
    }

    func testConvert_WithNilRate_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate: Double? = nil

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, amount, "Should return original amount when rate is nil")
    }

    func testConvert_WithZeroRate_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate = 0.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, amount, "Should return original amount when rate is zero")
    }

    func testConvert_WithNegativeRate_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate = -0.5

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, amount, "Should return original amount when rate is negative")
    }

    func testConvert_WithVerySmallRate_PerformsConversion() {
        // Given
        let amount = 100.0
        let rate = 0.001

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 0.1, accuracy: 0.001, "Should handle very small rates")
    }

    func testConvert_WithVeryLargeRate_PerformsConversion() {
        // Given
        let amount = 1.0
        let rate = 1000.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 1000.0, accuracy: 0.001, "Should handle very large rates")
    }

    func testConvert_WithZeroAmount_ReturnsZero() {
        // Given
        let amount = 0.0
        let rate = 1.5

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 0.0, "Should return zero when amount is zero")
    }

    func testConvert_WithNegativeAmount_HandlesCorrectly() {
        // Given
        let amount = -50.0
        let rate = 2.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, -100.0, accuracy: 0.001, "Should handle negative amounts correctly")
    }

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
            (Locale(identifier: "fr_FR"), "€1 234,56"), // French format
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

    // MARK: - Monthly Limit Calculation Tests

    func testCalculateMonthlyLimit_BasicCalculation() {
        // Given
        let yearlyLimit = 1200.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 100.0, accuracy: 0.001, "Should calculate monthly limit as yearly/12")
    }

    func testCalculateMonthlyLimit_ZeroYearlyLimit() {
        // Given
        let yearlyLimit = 0.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 0.0, "Should handle zero yearly limit")
    }

    func testCalculateMonthlyLimit_NegativeYearlyLimit() {
        // Given
        let yearlyLimit = -1200.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, -100.0, accuracy: 0.001, "Should handle negative yearly limit")
    }

    func testCalculateMonthlyLimit_FractionalYearlyLimit() {
        // Given
        let yearlyLimit = 100.5

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 8.375, accuracy: 0.001, "Should handle fractional yearly limits")
    }

    func testCalculateMonthlyLimit_VeryLargeYearlyLimit() {
        // Given
        let yearlyLimit = 1_000_000.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 83333.333333333333, accuracy: 0.001, "Should handle very large yearly limits")
    }

    func testCalculateMonthlyLimit_VerySmallYearlyLimit() {
        // Given
        let yearlyLimit = 0.12

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 0.01, accuracy: 0.001, "Should handle very small yearly limits")
    }

    func testCalculateMonthlyLimit_WithDifferentCalendar() {
        // Given
        let yearlyLimit = 1200.0
        let islamicCalendar = Calendar(identifier: .islamicCivil)

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit, using: islamicCalendar)

        // Then
        // The calculation should still be /12 regardless of calendar
        XCTAssertEqual(result, 100.0, accuracy: 0.001, "Should use same calculation regardless of calendar type")
    }

    // MARK: - Edge Cases and Error Handling

    func testConvert_WithInfiniteValues() {
        // Given
        let amount = 100.0
        let infiniteRate = Double.infinity

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: infiniteRate)

        // Then
        // Should handle infinity gracefully (returns original amount due to guard)
        XCTAssertEqual(result, amount, "Should handle infinite rate gracefully")
    }

    func testConvert_WithNaNValues() {
        // Given
        let amount = 100.0
        let nanRate = Double.nan

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: nanRate)

        // Then
        XCTAssertEqual(result, amount, "Should handle NaN rate gracefully")
    }

    func testFormatAmount_WithInfiniteAmount() {
        // Given
        let infiniteAmount = Double.infinity
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(
            infiniteAmount,
            currencySymbol: currencySymbol,
            locale: locale)

        // Then
        // Should have some representation (formatter should handle this)
        XCTAssertFalse(result.isEmpty, "Should handle infinite amount")
        XCTAssertTrue(result.hasPrefix("$"), "Should still include currency symbol")
    }

    func testFormatAmount_WithNaNAmount() {
        // Given
        let nanAmount = Double.nan
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(nanAmount, currencySymbol: currencySymbol, locale: locale)

        // Then
        // Should have some representation (formatter should handle this)
        XCTAssertFalse(result.isEmpty, "Should handle NaN amount")
        XCTAssertTrue(result.hasPrefix("$"), "Should still include currency symbol")
    }

    // MARK: - Performance Tests

    func testConvert_Performance() {
        // Given
        let iterations = 100_000
        let amount = 123.45
        let rate = 0.85

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            _ = CurrencyConversionHelper.convert(amount: amount, rate: rate)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "Currency conversion should be fast")
    }

    func testFormatAmount_Performance() {
        // Given
        let iterations = 10000
        let amount = 1234.56
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            _ = CurrencyConversionHelper.formatAmount(amount, currencySymbol: currencySymbol, locale: locale)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 2.0, "Amount formatting should be reasonably fast")
    }

    // MARK: - MainActor Tests

    func testCurrencyConversionHelper_IsMainActor() {
        // Then - CurrencyConversionHelper is marked with @MainActor attribute
        // This test ensures the class exists and can be accessed on MainActor
        XCTAssertNotNil(CurrencyConversionHelper.self)
    }

    func testConcurrentAccess_MainActorSafety() async {
        // Given
        let taskCount = 20

        // When - Perform concurrent operations on MainActor
        await withTaskGroup(of: Bool.self) { group in
            for i in 0 ..< taskCount {
                group.addTask { @MainActor in
                    let amount = Double(i * 10)
                    let rate = 0.85
                    let converted = CurrencyConversionHelper.convert(amount: amount, rate: rate)
                    let formatted = CurrencyConversionHelper.formatAmount(converted, currencySymbol: "$")
                    let monthly = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: amount)

                    return converted == amount * rate && !formatted.isEmpty && monthly == amount / 12.0
                }
            }

            // Collect results
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            // Then
            XCTAssertEqual(results.count, taskCount, "All tasks should complete")
            XCTAssertTrue(results.allSatisfy(\.self), "All concurrent operations should succeed")
        }
    }
}
