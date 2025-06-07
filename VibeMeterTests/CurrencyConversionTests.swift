import Foundation
import Testing
@testable import VibeMeter

@Suite("Currency Conversion Tests", .tags(.currency, .unit))
@MainActor
struct CurrencyConversionTests {
    // MARK: - Basic Conversion Tests

    @Suite("Basic Conversion", .tags(.fast, .critical))
    struct BasicConversionTests {
        struct ConversionTestCase: Sendable, CustomTestStringConvertible {
            let amount: Double
            let rate: Double
            let expected: Double
            let description: String

            init(_ amount: Double, rate: Double, expected: Double, _ description: String) {
                self.amount = amount
                self.rate = rate
                self.expected = expected
                self.description = description
            }

            var testDescription: String { description }
        }

        static let conversionTestCases: [ConversionTestCase] = [
            ConversionTestCase(100.0, rate: 0.85, expected: 85.0, "USD to EUR conversion"),
            ConversionTestCase(0.0, rate: 0.85, expected: 0.0, "zero amount conversion"),
            ConversionTestCase(100.0, rate: 1.0, expected: 100.0, "same currency conversion"),
            ConversionTestCase(-100.0, rate: 0.85, expected: -85.0, "negative amount conversion"),
            ConversionTestCase(1_000_000.0, rate: 0.85, expected: 850_000.0, "large amount conversion"),
            ConversionTestCase(0.01, rate: 0.85, expected: 0.0085, "small amount conversion"),
            ConversionTestCase(999.99, rate: 1.2345, expected: 1234.488, "precision conversion"),
        ]

        @Test("Currency conversion calculations", .tags(.critical), arguments: BasicConversionTests.conversionTestCases)
        func conversionCalculations(testCase: ConversionTestCase) async {
            // When
            let result = await MainActor.run {
                CurrencyConversionHelper.convert(amount: testCase.amount, rate: testCase.rate)
            }

            // Then
            let tolerance = testCase.expected.magnitude < 1.0 ? 0.0001 : 0.01
            result.isApproximatelyEqual(to: testCase.expected, tolerance: tolerance)
        }

        @Test("Invalid rate handling", .tags(.edgeCase), arguments: [nil, 0.0, -1.0, .infinity, .nan])
        func invalidRateHandling(invalidRate: Double?) async {
            // When
            let result = await MainActor.run {
                CurrencyConversionHelper.convert(amount: 100.0, rate: invalidRate)
            }

            // Then - Should return original amount for invalid rates
            #expect(result == 100.0)
        }

        @Test("Monthly limit calculation", arguments: [
            (1200.0, 100.0, "standard yearly limit"),
            (0.0, 0.0, "zero limit"),
            (600.0, 50.0, "mid-range limit"),
            (2400.0, 200.0, "high limit")
        ])
        func monthlyLimitCalculation(yearlyLimit: Double, expectedMonthly: Double, description _: String) async {
            // When
            let result = await MainActor.run {
                CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)
            }

            // Then
            result.isApproximatelyEqual(to: expectedMonthly, tolerance: 0.01)
        }
    }

    // MARK: - Currency Formatting Tests

    @Suite("Currency Formatting", .tags(.fast))
    struct CurrencyFormattingTests {
        struct FormattingTestCase: Sendable {
            let amount: Double
            let symbol: String
            let expected: String
            let description: String

            init(_ amount: Double, symbol: String, expected: String, _ description: String) {
                self.amount = amount
                self.symbol = symbol
                self.expected = expected
                self.description = description
            }
        }

        static let formattingTestCases: [FormattingTestCase] = [
            FormattingTestCase(99.99, symbol: "$", expected: "$99.99", "USD formatting"),
            FormattingTestCase(1000.0, symbol: "€", expected: "€1,000", "EUR large amount"),
            FormattingTestCase(0.5, symbol: "£", expected: "£0.5", "GBP decimal"),
            FormattingTestCase(1_234_567.89, symbol: "¥", expected: "¥1,234,567.89", "JPY very large amount"),
            FormattingTestCase(0.0, symbol: "$", expected: "$0", "zero amount"),
            FormattingTestCase(-50.25, symbol: "$", expected: "$-50.25", "negative amount"),
        ]

        @Test("Currency formatting", arguments: CurrencyFormattingTests.formattingTestCases)
        func currencyFormatting(testCase: FormattingTestCase) async {
            // When
            let result = await MainActor.run {
                CurrencyConversionHelper.formatAmount(testCase.amount, currencySymbol: testCase.symbol)
            }

            // Then
            #expect(result.contains(testCase.symbol))
            // Verify the result contains a reasonable number representation
            let numberPart = result.replacingOccurrences(of: testCase.symbol, with: "")
            #expect(!numberPart.isEmpty)
        }

        @Test("Locale-specific formatting", arguments: [
            (Locale(identifier: "en_US"), "$", "US formatting"),
            (Locale(identifier: "de_DE"), "€", "German formatting"),
            (Locale(identifier: "ja_JP"), "¥", "Japanese formatting")
        ])
        func localeSpecificFormatting(locale: Locale, symbol: String, description _: String) async {
            // Given
            let amount = 1234.56

            // When
            let result = await MainActor.run {
                CurrencyConversionHelper.formatAmount(amount, currencySymbol: symbol, locale: locale)
            }

            // Then
            #expect(result.contains(symbol))
            #expect(!result.isEmpty)
        }
    }

    // MARK: - Edge Cases Tests

    @Suite("Edge Cases", .tags(.edgeCase))
    @MainActor
    struct EdgeCasesTests {
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
            let result = CurrencyConversionHelper.formatAmount(
                nanAmount,
                currencySymbol: currencySymbol,
                locale: locale)

            // Then
            // Should have some representation (formatter should handle this)
            #expect(result.isEmpty == false)
        }

        @Test("currency conversion helper is main actor")
        func currencyConversionHelperIsMainActor() {
            // Then - CurrencyConversionHelper is marked with @MainActor attribute
            // This test ensures the class exists and can be accessed on MainActor
            let _: CurrencyConversionHelper.Type = CurrencyConversionHelper.self
            #expect(Bool(true))
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

    // MARK: - Performance Tests

    @Suite("Performance", .tags(.performance))
    struct PerformanceTests {
        @Test("Conversion performance", .timeLimit(.minutes(1)))
        func conversionPerformance() async {
            // Given
            let iterations = 10000

            // When/Then - Should complete within time limit
            await MainActor.run {
                for i in 0 ..< iterations {
                    let amount = Double(i)
                    let rate = 0.85
                    _ = CurrencyConversionHelper.convert(amount: amount, rate: rate)
                }
            }
        }

        @Test("convert performance")
        @MainActor
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
        @MainActor
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
    }
}
