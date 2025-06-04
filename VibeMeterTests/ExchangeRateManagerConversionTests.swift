import Foundation
@testable import VibeMeter
import XCTest

final class ExchangeRateManagerConversionTests: XCTestCase {
    private var mockURLSession: MockURLSession!
    private var exchangeRateManager: ExchangeRateManager!

    override func setUp() {
        super.setUp()
        mockURLSession = MockURLSession()
        exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
    }

    override func tearDown() {
        mockURLSession = nil
        exchangeRateManager = nil
        super.tearDown()
    }

    // MARK: - Currency Conversion Tests

    func testConvert_SameCurrency_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": 0.92, "GBP": 0.82]

        // When
        let result = exchangeRateManager.convert(amount, from: "USD", to: "USD", rates: rates)

        // Then
        XCTAssertEqual(result, amount)
    }

    func testConvert_USDToOtherCurrency_Success() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": 0.92, "GBP": 0.82]

        // When
        let eurResult = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)
        let gbpResult = exchangeRateManager.convert(amount, from: "USD", to: "GBP", rates: rates)

        // Then
        XCTAssertEqual(eurResult, 92.0)
        XCTAssertEqual(gbpResult, 82.0)
    }

    func testConvert_OtherCurrencyToUSD_Success() {
        // Given
        let amount = 92.0
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "USD", rates: rates)

        // Then
        XCTAssertEqual(result!, 100.0, accuracy: 0.01)
    }

    func testConvert_CrossCurrencyConversion_Success() {
        // Given
        let amount = 92.0 // 92 EUR
        let rates: [String: Double] = ["EUR": 0.92, "GBP": 0.82]

        // When - Converting EUR to GBP through USD
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "GBP", rates: rates)

        // Then - 92 EUR = 100 USD = 82 GBP
        XCTAssertEqual(result!, 82.0, accuracy: 0.01)
    }

    func testConvert_MissingSourceCurrency_ReturnsNil() {
        // Given
        let amount = 100.0
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "GBP", to: "EUR", rates: rates)

        // Then
        XCTAssertNil(result)
    }

    func testConvert_MissingTargetCurrency_ReturnsNil() {
        // Given
        let amount = 100.0
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "GBP", rates: rates)

        // Then
        XCTAssertNil(result)
    }

    func testConvert_ZeroSourceRate_ReturnsNil() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": 0.0, "GBP": 0.82]

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "GBP", rates: rates)

        // Then
        XCTAssertNil(result)
    }

    func testConvert_NegativeRates() {
        // Given
        let amount = 100.0
        let rates: [String: Double] = ["EUR": -0.92] // Invalid negative rate

        // When
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "USD", rates: rates)

        // Then
        XCTAssertNil(result) // Should fail validation
    }

    func testConvert_VeryLargeNumbers() {
        // Given
        let amount = Double.greatestFiniteMagnitude / 2
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isFinite)
    }

    func testConvert_VerySmallNumbers() {
        // Given
        let amount = Double.leastNormalMagnitude
        let rates = ["EUR": 0.92]

        // When
        let result = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result! >= 0)
    }

    // MARK: - Currency Symbol Tests

    func testGetSymbol_AllSupportedCurrencies() {
        // When/Then
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "USD"), "$")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "EUR"), "€")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "GBP"), "£")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "JPY"), "¥")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "AUD"), "A$")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "CAD"), "C$")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "CHF"), "CHF")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "CNY"), "¥")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "SEK"), "kr")
        XCTAssertEqual(ExchangeRateManager.getSymbol(for: "NZD"), "NZ$")
    }

    func testGetSymbol_UnsupportedCurrency_ReturnsCode() {
        // When
        let result = ExchangeRateManager.getSymbol(for: "XXX")

        // Then
        XCTAssertEqual(result, "XXX")
    }

    // MARK: - Fallback Rates Tests

    func testFallbackRates_ContainsExpectedCurrencies() {
        // When
        let fallbackRates = exchangeRateManager.fallbackRates

        // Then
        XCTAssertEqual(fallbackRates["EUR"], 0.85)
        XCTAssertEqual(fallbackRates["GBP"], 0.73)
        XCTAssertEqual(fallbackRates["JPY"], 110.0)
        XCTAssertEqual(fallbackRates["AUD"], 1.35)
        XCTAssertEqual(fallbackRates["CAD"], 1.25)
        XCTAssertEqual(fallbackRates["CHF"], 0.92)
        XCTAssertEqual(fallbackRates["CNY"], 6.45)
        XCTAssertEqual(fallbackRates["SEK"], 8.8)
        XCTAssertEqual(fallbackRates["NZD"], 1.4)
    }

    // MARK: - Supported Currencies Tests

    func testSupportedCurrencies_ContainsExpectedList() {
        // When
        let supportedCurrencies = exchangeRateManager.supportedCurrencies

        // Then
        let expectedCurrencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "SEK", "NZD"]
        XCTAssertEqual(Set(supportedCurrencies), Set(expectedCurrencies))
    }
}
