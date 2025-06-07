import Foundation
import Testing
@testable import VibeMeter

@Suite("Exchange Rate Manager - Conversion Tests", .tags(.currency, .unit))
struct ExchangeRateManagerConversionTests {
    private let mockURLSession: MockURLSession
    private let exchangeRateManager: ExchangeRateManager

    init() {
        self.mockURLSession = MockURLSession()
        self.exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
    }

    // MARK: - Currency Conversion Tests

    struct ConversionTestCase: Sendable {
        let amount: Double
        let from: String
        let to: String
        let rates: [String: Double]
        let expected: Double?
        let description: String
        let tolerance: Double
        
        init(_ amount: Double, from: String, to: String, rates: [String: Double], expected: Double?, _ description: String, tolerance: Double = 0.01) {
            self.amount = amount
            self.from = from
            self.to = to
            self.rates = rates
            self.expected = expected
            self.description = description
            self.tolerance = tolerance
        }
    }
    
    static let conversionTestCases: [ConversionTestCase] = [
        // Same currency
        ConversionTestCase(100.0, from: "USD", to: "USD", rates: ["EUR": 0.92], expected: 100.0, "same currency returns original"),
        
        // USD to other currencies
        ConversionTestCase(100.0, from: "USD", to: "EUR", rates: ["EUR": 0.92], expected: 92.0, "USD to EUR"),
        ConversionTestCase(100.0, from: "USD", to: "GBP", rates: ["GBP": 0.82], expected: 82.0, "USD to GBP"),
        
        // Other currencies to USD
        ConversionTestCase(92.0, from: "EUR", to: "USD", rates: ["EUR": 0.92], expected: 100.0, "EUR to USD"),
        
        // Cross currency conversion
        ConversionTestCase(92.0, from: "EUR", to: "GBP", rates: ["EUR": 0.92, "GBP": 0.82], expected: 82.0, "EUR to GBP via USD")
    ]
    
    @Test("Currency conversions", arguments: conversionTestCases)
    func currencyConversions(testCase: ConversionTestCase) {
        // When
        let result = exchangeRateManager.convert(testCase.amount, from: testCase.from, to: testCase.to, rates: testCase.rates)
        
        // Then
        if let expected = testCase.expected {
            #expect(result != nil)
            if let result {
                #expect(abs(result - expected) < testCase.tolerance)
            }
        } else {
            #expect(result == nil)
        }
    }

    static let invalidConversionCases: [ConversionTestCase] = [
        // Missing currencies
        ConversionTestCase(100.0, from: "GBP", to: "EUR", rates: ["EUR": 0.92], expected: nil, "missing source currency"),
        ConversionTestCase(100.0, from: "EUR", to: "GBP", rates: ["EUR": 0.92], expected: nil, "missing target currency"),
        
        // Invalid rates
        ConversionTestCase(100.0, from: "EUR", to: "GBP", rates: ["EUR": 0.0, "GBP": 0.82], expected: nil, "zero source rate"),
        ConversionTestCase(100.0, from: "EUR", to: "USD", rates: ["EUR": -0.92], expected: nil, "negative rate")
    ]
    
    @Test("Invalid conversions return nil", arguments: invalidConversionCases)
    func invalidConversions(testCase: ConversionTestCase) {
        // When
        let result = exchangeRateManager.convert(testCase.amount, from: testCase.from, to: testCase.to, rates: testCase.rates)
        
        // Then
        #expect(result == nil)
    }
    
    @Test("Edge case conversions", arguments: [
        (Double.greatestFiniteMagnitude / 2, "very large number"),
        (Double.leastNormalMagnitude, "very small number")
    ])
    func edgeCaseConversions(amount: Double, description: String) {
        // Given
        let rates = ["EUR": 0.92]
        
        // When
        let result = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)
        
        // Then
        #expect(result != nil)
    }

    // MARK: - Currency Symbol Tests

    @Test("Currency symbols", arguments: [
        ("USD", "$"),
        ("EUR", "€"),
        ("GBP", "£"),
        ("JPY", "¥"),
        ("AUD", "A$"),
        ("CAD", "C$"),
        ("CHF", "CHF"),
        ("CNY", "¥"),
        ("SEK", "kr"),
        ("NZD", "NZ$")
    ])
    func currencySymbols(code: String, expectedSymbol: String) {
        // When
        let symbol = ExchangeRateManager.getSymbol(for: code)
        
        // Then
        #expect(symbol == expectedSymbol)
    }

    @Test("get symbol unsupported currency returns code")
    func getSymbol_UnsupportedCurrency_ReturnsCode() {
        // When
        let result = ExchangeRateManager.getSymbol(for: "XXX")

        // Then
        #expect(result == "XXX")
    }

    @Test("Fallback rates contain expected currencies")
    func fallbackRatesContainExpectedCurrencies() {
        // When
        let fallbackRates = exchangeRateManager.fallbackRates
        
        // Then
        let expectedRates: [String: Double] = [
            "EUR": 0.85,
            "JPY": 110.0,
            "CAD": 1.25,
            "CNY": 6.45,
            "NZD": 1.4
        ]
        
        for (currency, rate) in expectedRates {
            #expect(fallbackRates[currency] == rate)
        }
    }

    @Test("Supported currencies list")
    func supportedCurrenciesList() {
        // When
        let supportedCurrencies = exchangeRateManager.supportedCurrencies
        
        // Then
        let expectedCurrencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "SEK", "NZD"]
        #expect(Set(supportedCurrencies) == Set(expectedCurrencies))
    }
}
