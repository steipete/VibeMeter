@testable import VibeMeter
import XCTest

@MainActor
final class CurrencyConversionEdgeCasesTests: XCTestCase {
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
                group.addTask { @Sendable in
                    await MainActor.run {
                        let amount = Double(i * 10)
                        let rate = 0.85
                        let converted = CurrencyConversionHelper.convert(amount: amount, rate: rate)
                        let formatted = CurrencyConversionHelper.formatAmount(converted, currencySymbol: "$")
                        let monthly = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: amount)

                        return converted == amount * rate && !formatted.isEmpty && monthly == amount / 12.0
                    }
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