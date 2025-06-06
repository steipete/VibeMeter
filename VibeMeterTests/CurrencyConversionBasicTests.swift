import Foundation
import Testing
@testable import VibeMeter

@Suite("Currency Conversion Basic Tests")
struct CurrencyConversionBasicTests {
    
    // MARK: - Parameterized Conversion Tests
    
    struct ConversionTestCase: Sendable {
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
    }
    
    static let conversionTestCases: [ConversionTestCase] = [
        ConversionTestCase(100.0, rate: 0.85, expected: 85.0, "USD to EUR conversion"),
        ConversionTestCase(0.0, rate: 0.85, expected: 0.0, "zero amount conversion"),
        ConversionTestCase(100.0, rate: 1.0, expected: 100.0, "same currency conversion"),
        ConversionTestCase(-100.0, rate: 0.85, expected: -85.0, "negative amount conversion"),
        ConversionTestCase(1_000_000.0, rate: 0.85, expected: 850_000.0, "large amount conversion"),
        ConversionTestCase(0.01, rate: 0.85, expected: 0.0085, "small amount conversion"),
        ConversionTestCase(999.99, rate: 1.2345, expected: 1234.488, "precision conversion")
    ]
    
    @Test("Currency conversion calculations", arguments: conversionTestCases)
    @MainActor
    func conversionCalculations(testCase: ConversionTestCase) {
        // When
        let result = CurrencyConversionHelper.convert(amount: testCase.amount, rate: testCase.rate)
        
        // Then
        let tolerance = testCase.expected.magnitude < 1.0 ? 0.0001 : 0.01
        #expect(abs(result - testCase.expected) < tolerance)
    }
    
    // MARK: - Edge Case Tests
    
    @Test("Invalid rate handling", arguments: [nil, 0.0, -1.0, .infinity, .nan])
    @MainActor
    func invalidRateHandling(invalidRate: Double?) {
        // When
        let result = CurrencyConversionHelper.convert(amount: 100.0, rate: invalidRate)
        
        // Then - Should return original amount for invalid rates
        #expect(result == 100.0)
    }
    
    // MARK: - Currency Formatting Tests
    
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
        FormattingTestCase(1234567.89, symbol: "¥", expected: "¥1,234,567.89", "JPY very large amount"),
        FormattingTestCase(0.0, symbol: "$", expected: "$0", "zero amount"),
        FormattingTestCase(-50.25, symbol: "$", expected: "$-50.25", "negative amount")
    ]
    
    @Test("Currency formatting", arguments: formattingTestCases)
    @MainActor
    func currencyFormatting(testCase: FormattingTestCase) {
        // When
        let result = CurrencyConversionHelper.formatAmount(testCase.amount, currencySymbol: testCase.symbol)
        
        // Then
        #expect(result.contains(testCase.symbol))
        #expect(result.contains(String(format: "%.2f", abs(testCase.amount)).replacingOccurrences(of: ".00", with: "")))
    }
    
    // MARK: - Locale-Specific Formatting Tests
    
    @Test("Locale-specific formatting", arguments: [
        (Locale(identifier: "en_US"), "$", "US formatting"),
        (Locale(identifier: "de_DE"), "€", "German formatting"),
        (Locale(identifier: "ja_JP"), "¥", "Japanese formatting")
    ])
    @MainActor
    func localeSpecificFormatting(locale: Locale, symbol: String, description: String) {
        // Given
        let amount = 1234.56
        
        // When
        let result = CurrencyConversionHelper.formatAmount(amount, currencySymbol: symbol, locale: locale)
        
        // Then
        #expect(result.contains(symbol))
        #expect(!result.isEmpty)
    }
    
    // MARK: - Monthly Limit Calculation Tests
    
    @Test("Monthly limit calculation", arguments: [
        (1200.0, 100.0, "standard yearly limit"),
        (0.0, 0.0, "zero limit"),
        (600.0, 50.0, "mid-range limit"),
        (2400.0, 200.0, "high limit")
    ])
    @MainActor
    func monthlyLimitCalculation(yearlyLimit: Double, expectedMonthly: Double, description: String) {
        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)
        
        // Then
        #expect(abs(result - expectedMonthly) < 0.01)
    }
    
    // MARK: - Performance Tests
    
    @Test("Conversion performance", .timeLimit(.minutes(1)))
    @MainActor
    func conversionPerformance() {
        // Given
        let iterations = 10_000
        
        // When/Then - Should complete within time limit
        for i in 0..<iterations {
            let amount = Double(i)
            let rate = 0.85
            _ = CurrencyConversionHelper.convert(amount: amount, rate: rate)
        }
    }
}