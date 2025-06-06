import Foundation
import Testing
@testable import VibeMeter

@Suite("Exchange Rate Manager Network Tests")
struct ExchangeRateManagerNetworkTests {
    private let mockURLSession: MockURLSession
    private let exchangeRateManager: ExchangeRateManager

    init() {
        self.mockURLSession = MockURLSession()
        self.exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
    }

    // MARK: - Test Data Helpers

    private static func createMockRatesData(base: String = "USD", rates: [String: Double]) -> Data {
        let ratesDict = rates.mapValues { $0 }
        let response = [
            "base": base,
            "date": "2023-12-01",
            "rates": ratesDict,
        ] as [String: Any]

        return try! JSONSerialization.data(withJSONObject: response)
    }

    private static func createMockResponse(statusCode: Int,
                                           url: String = "https://api.frankfurter.app/latest") -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil)!
    }

    // MARK: - Successful Response Tests

    struct ExchangeRateTestCase: Sendable {
        let rates: [String: Double]
        let expectedCurrency: String
        let expectedRate: Double
        let description: String

        init(rates: [String: Double], expecting currency: String, rate: Double, _ description: String) {
            self.rates = rates
            self.expectedCurrency = currency
            self.expectedRate = rate
            self.description = description
        }
    }

    static let successfulRateTestCases: [ExchangeRateTestCase] = [
        ExchangeRateTestCase(
            rates: ["EUR": 0.92, "GBP": 0.82, "JPY": 149.50],
            expecting: "EUR", rate: 0.92,
            "standard major currencies"),
        ExchangeRateTestCase(
            rates: ["CHF": 0.88, "CAD": 1.35, "AUD": 1.52],
            expecting: "CHF", rate: 0.88,
            "additional major currencies"),
        ExchangeRateTestCase(
            rates: ["SEK": 10.85, "NOK": 11.12, "DKK": 6.86],
            expecting: "SEK", rate: 10.85,
            "Nordic currencies"),
        ExchangeRateTestCase(
            rates: ["CNY": 7.24, "INR": 83.15, "KRW": 1315.45],
            expecting: "CNY", rate: 7.24,
            "Asian currencies"),
    ]

    @Test("Exchange rate fetching success", arguments: successfulRateTestCases)
    func exchangeRateFetchingSuccess(testCase: ExchangeRateTestCase) async throws {
        // Given
        let mockData = Self.createMockRatesData(rates: testCase.rates)
        let mockResponse = Self.createMockResponse(statusCode: 200)

        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = mockResponse

        // When
        let result = await exchangeRateManager.getExchangeRates()

        // Then
        #expect(result[testCase.expectedCurrency] == testCase.expectedRate,
                "Should contain correct rate for \(testCase.expectedCurrency): \(testCase.description)")
        #expect(result.count == testCase.rates.count,
                "Should return all rates: \(testCase.description)")
    }

    // MARK: - Error Response Tests

    @Test("Network error handling", arguments: [
        (statusCode: 404, description: "not found"),
        (statusCode: 500, description: "server error"),
        (statusCode: 503, description: "service unavailable"),
        (statusCode: 429, description: "rate limited"),
    ])
    func networkErrorHandling(statusCode: Int, description _: String) async {
        // Given
        let mockResponse = Self.createMockResponse(statusCode: statusCode)
        mockURLSession.nextData = Data()
        mockURLSession.nextResponse = mockResponse

        // When
        let result = await exchangeRateManager.getExchangeRates()

        // Then - Should return fallback rates when network fails
        #expect(!result.isEmpty)
        #expect(result.count == 9) // Should have fallback rates for all supported currencies except USD
    }

    // MARK: - Invalid Data Tests

    struct InvalidDataTestCase: Sendable {
        let data: Data
        let description: String

        init(jsonString: String, _ description: String) {
            self.data = Data(jsonString.utf8)
            self.description = description
        }

        init(data: Data, _ description: String) {
            self.data = data
            self.description = description
        }
    }

    static let invalidDataTestCases: [InvalidDataTestCase] = [
        InvalidDataTestCase(jsonString: "{invalid json", "malformed JSON"),
        InvalidDataTestCase(jsonString: "{}", "empty JSON object"),
        InvalidDataTestCase(jsonString: """
        {"base": "USD", "date": "2023-12-01"}
        """, "missing rates field"),
        InvalidDataTestCase(jsonString: """
        {"base": "USD", "rates": "not an object"}
        """, "rates field not an object"),
        InvalidDataTestCase(data: Data(), "empty data"),
        InvalidDataTestCase(jsonString: """
        {"base": "USD", "rates": {"EUR": "not a number"}}
        """, "invalid rate value"),
    ]

    @Test("Invalid data handling", arguments: invalidDataTestCases)
    func invalidDataHandling(testCase: InvalidDataTestCase) async {
        // Given
        let mockResponse = Self.createMockResponse(statusCode: 200)
        mockURLSession.nextData = testCase.data
        mockURLSession.nextResponse = mockResponse

        // When
        let result = await exchangeRateManager.getExchangeRates()

        // Then - Should return fallback rates when network fails
        #expect(!result.isEmpty)
        #expect(result.count == 9) // Should have fallback rates for all supported currencies except USD
    }

    // MARK: - Timeout and Network Failure Tests

    @Test("Network timeout handling")
    func networkTimeoutHandling() async {
        // Given
        mockURLSession.shouldSimulateTimeout = true

        // When
        let result = await exchangeRateManager.getExchangeRates()

        // Then - Should return fallback rates when network fails
        #expect(!result.isEmpty)
        #expect(result.count == 9) // Should have fallback rates for all supported currencies except USD
    }

    @Test("Network connection failure")
    func networkConnectionFailure() async {
        // Given
        mockURLSession.shouldSimulateNetworkError = true

        // When
        let result = await exchangeRateManager.getExchangeRates()

        // Then - Should return fallback rates when network fails
        #expect(!result.isEmpty)
        #expect(result.count == 9) // Should have fallback rates for all supported currencies except USD
    }

    // MARK: - Edge Case Tests

    @Test("Empty rates object")
    func emptyRatesObject() async {
        // Given
        let mockData = Self.createMockRatesData(rates: [:])
        let mockResponse = Self.createMockResponse(statusCode: 200)

        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = mockResponse

        // When
        let result = await exchangeRateManager.getExchangeRates()

        // Then - When API returns valid response with empty rates, return empty dict
        #expect(result.isEmpty)
    }

    @Test("Very large rates object", .timeLimit(.minutes(1)))
    func veryLargeRatesObject() async throws {
        // Given - Create a large rates object with 100 currencies
        var largeRates: [String: Double] = [:]
        for i in 1 ... 100 {
            largeRates["CUR\(i)"] = Double(i) * 0.1
        }

        let mockData = Self.createMockRatesData(rates: largeRates)
        let mockResponse = Self.createMockResponse(statusCode: 200)

        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = mockResponse

        // When
        let result = await exchangeRateManager.getExchangeRates()

        // Then
        #expect(result.count == 100)
        #expect(result["CUR50"] == 5.0)
    }

    // MARK: - URL Construction Tests

    @Test("API URL construction")
    func apiUrlConstruction() async {
        // Given
        let mockData = Self.createMockRatesData(rates: ["EUR": 0.85])
        let mockResponse = Self.createMockResponse(statusCode: 200)
        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = mockResponse

        // When the manager makes a request, verify URL is constructed correctly
        _ = await exchangeRateManager.getExchangeRates()

        // Then - Verify the URL was constructed correctly
        #expect(mockURLSession.lastRequest != nil)
        let url = mockURLSession.lastRequest?.url
        #expect(url?.absoluteString.contains("api.frankfurter.app/latest") == true)
        #expect(url?.absoluteString.contains("base=USD") == true)
    }

    // MARK: - Concurrent Request Tests

    @Test("Concurrent requests")
    func concurrentRequests() async {
        // Given
        let mockData = Self.createMockRatesData(rates: ["EUR": 0.92, "GBP": 0.82])
        let mockResponse = Self.createMockResponse(statusCode: 200)

        mockURLSession.nextData = mockData
        mockURLSession.nextResponse = mockResponse

        // When - Make multiple concurrent requests
        async let result1 = exchangeRateManager.getExchangeRates()
        async let result2 = exchangeRateManager.getExchangeRates()
        async let result3 = exchangeRateManager.getExchangeRates()

        let results = await [result1, result2, result3]

        // Then - All should succeed (though only one may actually execute due to caching/deduplication)
        for result in results {
            #expect(result["EUR"] != nil)
        }
    }
}
