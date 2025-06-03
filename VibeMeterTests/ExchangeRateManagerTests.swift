import Foundation
@testable import VibeMeter
import XCTest

@MainActor
final class ExchangeRateManagerTests: XCTestCase {
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

    // MARK: - Exchange Rate Fetching Tests

    func testGetExchangeRates_Success() async {
        // Given
        let mockRatesData = """
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {
                "EUR": 0.92,
                "GBP": 0.82,
                "JPY": 149.50
            }
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = mockResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        XCTAssertEqual(rates["EUR"], 0.92)
        XCTAssertEqual(rates["GBP"], 0.82)
        XCTAssertEqual(rates["JPY"], 149.50)
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 1)
    }

    func testGetExchangeRates_NetworkError_ReturnsFallbackRates() async {
        // Given
        mockURLSession.nextError = NSError(domain: "NetworkError", code: -1009, userInfo: nil)

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        XCTAssertEqual(rates, exchangeRateManager.fallbackRates)
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 1)
    }

    func testGetExchangeRates_HTTPError_ReturnsFallbackRates() async {
        // Given
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = Data()
        mockURLSession.nextResponse = mockResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        XCTAssertEqual(rates, exchangeRateManager.fallbackRates)
    }

    func testGetExchangeRates_InvalidJSON_ReturnsFallbackRates() async {
        // Given
        let invalidJSON = "invalid json".data(using: .utf8)!
        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = invalidJSON
        mockURLSession.nextResponse = mockResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        XCTAssertEqual(rates, exchangeRateManager.fallbackRates)
    }

    func testGetExchangeRates_CachingBehavior() async {
        // Given - First successful request
        let mockRatesData = """
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {
                "EUR": 0.92,
                "GBP": 0.82
            }
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = mockResponse

        // When - First call
        let firstRates = await exchangeRateManager.getExchangeRates()

        // Then - Should make network request
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 1)
        XCTAssertEqual(firstRates["EUR"], 0.92)

        // When - Second call immediately after (within cache window)
        let secondRates = await exchangeRateManager.getExchangeRates()

        // Then - Should use cache, no additional network request
        XCTAssertEqual(mockURLSession.dataTaskCallCount, 1) // Still 1
        XCTAssertEqual(secondRates["EUR"], 0.92)
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
        XCTAssertEqual(result, 100.0, accuracy: 0.01)
    }

    func testConvert_CrossCurrencyConversion_Success() {
        // Given
        let amount = 92.0 // 92 EUR
        let rates: [String: Double] = ["EUR": 0.92, "GBP": 0.82]

        // When - Converting EUR to GBP through USD
        let result = exchangeRateManager.convert(amount, from: "EUR", to: "GBP", rates: rates)

        // Then - 92 EUR = 100 USD = 82 GBP
        XCTAssertEqual(result, 82.0, accuracy: 0.01)
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

    // MARK: - API Request Configuration Tests

    func testAPIRequest_CorrectURL() async {
        // Given
        let mockRatesData = """
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {"EUR": 0.92}
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = mockResponse

        // When
        _ = await exchangeRateManager.getExchangeRates()

        // Then
        let request = mockURLSession.lastRequest!
        let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!

        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "api.frankfurter.app")
        XCTAssertEqual(components.path, "/latest")

        let queryItems = components.queryItems!
        XCTAssertTrue(queryItems.contains { $0.name == "base" && $0.value == "USD" })
        XCTAssertTrue(queryItems.contains { $0.name == "symbols" })

        // Check that symbols contains supported currencies (excluding USD)
        if let symbolsItem = queryItems.first(where: { $0.name == "symbols" }) {
            let symbols = symbolsItem.value?.components(separatedBy: ",") ?? []
            XCTAssertTrue(symbols.contains("EUR"))
            XCTAssertTrue(symbols.contains("GBP"))
            XCTAssertFalse(symbols.contains("USD")) // Base currency excluded
        }
    }

    func testAPIRequest_CachePolicy() async {
        // Given
        let mockRatesData = """
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {"EUR": 0.92}
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = mockResponse

        // When
        _ = await exchangeRateManager.getExchangeRates()

        // Then
        let request = mockURLSession.lastRequest!
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.timeoutInterval, 30)
    }

    // MARK: - Edge Cases and Error Scenarios

    func testGetExchangeRates_EmptyRatesResponse() async {
        // Given
        let mockRatesData = """
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {}
        }
        """.data(using: .utf8)!

        let mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.frankfurter.app/latest")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = mockResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        XCTAssertTrue(rates.isEmpty)
    }

    func testGetExchangeRates_MalformedHTTPResponse() async {
        // Given
        let mockRatesData = Data()
        mockURLSession.nextData = mockRatesData
        mockURLSession.nextResponse = URLResponse() // Not HTTPURLResponse

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        XCTAssertEqual(rates, exchangeRateManager.fallbackRates)
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

    // MARK: - Supported Currencies Tests

    func testSupportedCurrencies_ContainsExpectedList() {
        // When
        let supportedCurrencies = exchangeRateManager.supportedCurrencies

        // Then
        let expectedCurrencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "SEK", "NZD"]
        XCTAssertEqual(Set(supportedCurrencies), Set(expectedCurrencies))
    }
}
