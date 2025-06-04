import Foundation
@testable import VibeMeter
import XCTest

final class ExchangeRateManagerNetworkTests: XCTestCase {
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
        let mockRatesData = Data("""
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {
                "EUR": 0.92,
                "GBP": 0.82,
                "JPY": 149.50
            }
        }
        """.utf8)

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
        let invalidJSON = Data("invalid json".utf8)
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
        let mockRatesData = Data("""
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {
                "EUR": 0.92,
                "GBP": 0.82
            }
        }
        """.utf8)

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

    // MARK: - API Request Configuration Tests

    func testAPIRequest_CorrectURL() async {
        // Given
        let mockRatesData = Data("""
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {"EUR": 0.92}
        }
        """.utf8)

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
        let mockRatesData = Data("""
        {
            "base": "USD",
            "date": "2023-12-01",
            "rates": {"EUR": 0.92}
        }
        """.utf8)

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
}
