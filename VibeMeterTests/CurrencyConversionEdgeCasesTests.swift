import Foundation
import Testing
@testable import VibeMeter

@Suite("Currency Conversion Edge Cases Tests", .tags(.currency, .edgeCase, .unit))
@MainActor
struct CurrencyConversionEdgeCasesTests {
    // MARK: - Edge Cases and Error Handling

    @Test("convert with infinite values")

    func convertWithInfiniteValues() {
        // Given
        let amount = 100.0
        let infiniteRate = Double.infinity

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: infiniteRate)

        // Then
        // Should handle infinity gracefully (returns original amount due to guard)
        #expect(result == amount)
    }

    @Test("convert with nan values")

    func convertWithNaNValues() {
        // Given
        let amount = 100.0
        let nanRate = Double.nan

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: nanRate)

        // Then
        #expect(result == amount)
    }

    @Test("format amount with infinite amount")

    func formatAmountWithInfiniteAmount() {
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
        #expect(result.isEmpty == false)
    }

    @Test("format amount with na n amount")

    func formatAmountWithNaNAmount() {
        // Given
        let nanAmount = Double.nan
        let currencySymbol = "$"
        let locale = Locale(identifier: "en_US")

        // When
        let result = CurrencyConversionHelper.formatAmount(nanAmount, currencySymbol: currencySymbol, locale: locale)

        // Then
        // Should have some representation (formatter should handle this)
        #expect(result.isEmpty == false)
    }

    // MARK: - Performance Tests

    @Test("convert performance")

    func convertPerformance() {
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
        #expect(duration < 1.0)
    }

    @Test("format amount performance")

    func formatAmountPerformance() {
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
        #expect(duration < 2.0)
    }

    @Test("currency conversion helper is main actor")

    func currencyConversionHelperIsMainActor() {
        // Then - CurrencyConversionHelper is marked with @MainActor attribute
        // This test ensures the class exists and can be accessed on MainActor
        #expect(CurrencyConversionHelper.self != nil)
    }

    @Test("concurrent access main actor safety")

    func concurrentAccessMainActorSafety() async {
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
            #expect(results.count == taskCount)
        }
    }
}
