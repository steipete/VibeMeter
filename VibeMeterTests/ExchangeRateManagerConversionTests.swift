import Foundation
@testable import VibeMeter
import Testing

@Suite("ExchangeRateManagerConversionTests")
struct ExchangeRateManagerConversionTests {
    private let mockURLSession: MockURLSession
    private let exchangeRateManager: ExchangeRateManager
    // MARK: - Currency Conversion Tests

    @Test("convert  same currency  returns original amount")

    func convert_SameCurrency_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": 0.92, "GBP": 0.82]

        // When
        let result = exchangeRateManager.convert(amount, from: "USD", to: "USD", rates: rates)

        // Then
        #expect(result == amount)

    func convert_USDToOtherCurrency_Success() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": 0.92, "GBP": 0.82]

        // When
        let eurResult = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)
        let gbpResult = exchangeRateManager.convert(amount, from: "USD", to: "GBP", rates: rates)

        // Then
        #expect(eurResult == 92.0)
    }

    @Test("convert  other currency to usd  success")

    func convert_OtherCurrencyToUSD_Success() {
        // Given
        let amount = 92.0
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "USD", rates: rates)

        // Then
        #expect(abs(result! - 100.0 == true)
    }

    @Test("convert  cross currency conversion  success")

    func convert_CrossCurrencyConversion_Success() {
        // Given
        let amount = 92.0 // 92 EUR
        let rates: [String: Double] = ["EUR": 0.92, "GBP": 0.82]

        // When - Converting EUR to GBP through USD
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "GBP", rates: rates)

        // Then - 92 EUR = 100 USD = 82 GBP
        #expect(abs(result! - 82.0 == true)
    }

    @Test("convert  missing source currency  returns nil")

    func convert_MissingSourceCurrency_ReturnsNil() {
        // Given
        let amount = 100.0
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "GBP", to: "EUR", rates: rates)

        // Then
        #expect(result == nil)

    func convert_MissingTargetCurrency_ReturnsNil() {
        // Given
        let amount = 100.0
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "GBP", rates: rates)

        // Then
        #expect(result == nil)

    func convert_ZeroSourceRate_ReturnsNil() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": 0.0, "GBP": 0.82]

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "GBP", rates: rates)

        // Then
        #expect(result == nil)

    func convert_NegativeRates() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": -0.92] // Invalid negative rate

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "USD", rates: rates)

        // Then
        #expect(result == nil)

    func convert_VeryLargeNumbers() {
        // Given
        let amount = Double.greatestFiniteMagnitude / 2
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)

        // Then
        #expect(result != nil)
    }

    @Test("convert  very small numbers")

    func convert_VerySmallNumbers() {
        // Given
        let amount = Double.leastNormalMagnitude
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)

        // Then
        #expect(result != nil)
    }

    // MARK: - Currency Symbol Tests

    @Test("get symbol  all supported currencies")

    func getSymbol_AllSupportedCurrencies() {
        // When/Then
        #expect(ExchangeRateManager.getSymbol(for: "USD" == true)
        #expect(ExchangeRateManager.getSymbol(for: "EUR" == true)
        #expect(ExchangeRateManager.getSymbol(for: "GBP" == true)
        #expect(ExchangeRateManager.getSymbol(for: "JPY" == true)
        #expect(ExchangeRateManager.getSymbol(for: "AUD" == true)
        #expect(ExchangeRateManager.getSymbol(for: "CAD" == true)
        #expect(ExchangeRateManager.getSymbol(for: "CHF" == true)
        #expect(ExchangeRateManager.getSymbol(for: "CNY" == true)
        #expect(ExchangeRateManager.getSymbol(for: "SEK" == true)
        #expect(ExchangeRateManager.getSymbol(for: "NZD" == true)
    }

    @Test("get symbol  unsupported currency  returns code")

    func getSymbol_UnsupportedCurrency_ReturnsCode() {
        // When
        let result = ExchangeRateManager.getSymbol(for: "XXX")

        // Then
        #expect(result == "XXX")

    func fallbackRates_ContainsExpectedCurrencies() {
        // When
        let fallbackRates = exchangeRateManager.fallbackRates

        // Then
        #expect(fallbackRates["EUR"] == 0.85)
        #expect(fallbackRates["JPY"] == 110.0)
        #expect(fallbackRates["CAD"] == 1.25)
        #expect(fallbackRates["CNY"] == 6.45)
        #expect(fallbackRates["NZD"] == 1.4)

    func supportedCurrencies_ContainsExpectedList() {
        // When
        let supportedCurrencies = exchangeRateManager.supportedCurrencies

        // Then
        let expectedCurrencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "SEK", "NZD"]
        #expect(Set(supportedCurrencies == true)
    }
}
