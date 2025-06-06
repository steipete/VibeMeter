import Foundation
@testable import VibeMeter
import Testing

@Suite("ExchangeRateManagerNetworkTests")
struct ExchangeRateManagerNetworkTests {
    private let mockURLSession: MockURLSession
    private let exchangeRateManager: ExchangeRateManager
    
    init() {
        self.mockURLSession = MockURLSession()
        self.exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
    }
    
    // MARK: - Exchange Rate Fetching Tests

    @Test("get exchange rates success")
    func getExchangeRates_Success() async {
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
        #expect(rates["EUR"] == 0.92)
        #expect(rates["JPY"] == 149.50)
    }

    @Test("get exchange rates network error returns fallback rates")
    func getExchangeRates_NetworkError_ReturnsFallbackRates() async {
        // Given
        mockURLSession.nextError = NSError(domain: "NetworkError", code: -1009, userInfo: nil)

        // When
        let rates = await exchangeRateManager.getExchangeRates()

        // Then
        #expect(rates == exchangeRateManager.fallbackRates)
    }

    @Test("get exchange rates http error returns fallback rates")
    func getExchangeRates_HTTPError_ReturnsFallbackRates() async {
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
        #expect(rates == exchangeRateManager.fallbackRates)
    }

    func getExchangeRates_InvalidJSON_ReturnsFallbackRates() async {
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
        #expect(rates == exchangeRateManager.fallbackRates)
    }

    func getExchangeRates_CachingBehavior() async {
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
        #expect(mockURLSession.dataTaskCallCount == 1)

        // When - Second call immediately after (within cache window)
        let secondRates = await exchangeRateManager.getExchangeRates()

        // Then - Should use cache, no additional network request
        #expect(mockURLSession.dataTaskCallCount == 1)
    }

    // MARK: - API Request Configuration Tests

    @Test("api request correct url")
    func aPIRequest_CorrectURL() async {
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

        #expect(components.scheme == "https")
        #expect(components.path == "/latest")
        let queryItems = components.queryItems ?? []
        #expect(queryItems.contains { $0.name == "symbols" } == true)
        if let symbolsItem = queryItems.first(where: { $0.name == "symbols" }) {
            let symbols = symbolsItem.value?.components(separatedBy: ",") ?? []
            #expect(symbols.contains("EUR"))
            #expect(symbols.contains("USD") == false)
        }
    }

    func aPIRequest_CachePolicy() async {
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
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
    }
}
