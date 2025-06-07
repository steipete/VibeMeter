// swiftlint:disable file_length
// swiftlint:disable type_body_length
// swiftlint:disable nesting
import Foundation
import Testing
@testable import VibeMeter

@Suite("Exchange Rate Manager Tests", .tags(.currency))
@MainActor
struct ExchangeRateManagerTests {
    private let mockURLSession: MockURLSession
    private let exchangeRateManager: ExchangeRateManager

    init() {
        self.mockURLSession = MockURLSession()
        self.exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
    }

    // MARK: - Conversion Tests

    @Suite("Conversion Tests", .tags(.unit))
    struct ConversionTests {
        private let mockURLSession: MockURLSession
        private let exchangeRateManager: ExchangeRateManager

        init() {
            self.mockURLSession = MockURLSession()
            self.exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
        }

        struct ConversionTestCase: Sendable {
            let amount: Double
            let from: String
            let to: String
            let rates: [String: Double]
            let expected: Double?
            let description: String
            let tolerance: Double

            init(
                _ amount: Double,
                from: String,
                to: String,
                rates: [String: Double],
                expected: Double?,
                _ description: String,
                tolerance: Double = 0.01) {
                self.amount = amount
                self.from = from
                self.to = to
                self.rates = rates
                self.expected = expected
                self.description = description
                self.tolerance = tolerance
            }
        }

        @Test("Currency conversions", arguments: [
            // Same currency
            ConversionTestCase(
                100.0,
                from: "USD",
                to: "USD",
                rates: ["EUR": 0.92],
                expected: 100.0,
                "same currency returns original"),

            // USD to other currencies
            ConversionTestCase(100.0, from: "USD", to: "EUR", rates: ["EUR": 0.92], expected: 92.0, "USD to EUR"),
            ConversionTestCase(100.0, from: "USD", to: "GBP", rates: ["GBP": 0.82], expected: 82.0, "USD to GBP"),

            // Other currencies to USD
            ConversionTestCase(92.0, from: "EUR", to: "USD", rates: ["EUR": 0.92], expected: 100.0, "EUR to USD"),

            // Cross currency conversion
            ConversionTestCase(
                92.0,
                from: "EUR",
                to: "GBP",
                rates: ["EUR": 0.92, "GBP": 0.82],
                expected: 82.0,
                "EUR to GBP via USD"),
        ])
        func currencyConversions(testCase: ConversionTestCase) {
            // When
            let result = exchangeRateManager.convert(
                testCase.amount,
                from: testCase.from,
                to: testCase.to,
                rates: testCase.rates)

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

        @Test("Invalid conversions return nil", arguments: [
            // Missing currencies
            ConversionTestCase(
                100.0,
                from: "GBP",
                to: "EUR",
                rates: ["EUR": 0.92],
                expected: nil,
                "missing source currency"),
            ConversionTestCase(
                100.0,
                from: "EUR",
                to: "GBP",
                rates: ["EUR": 0.92],
                expected: nil,
                "missing target currency"),

            // Invalid rates
            ConversionTestCase(
                100.0,
                from: "EUR",
                to: "GBP",
                rates: ["EUR": 0.0, "GBP": 0.82],
                expected: nil,
                "zero source rate"),
            ConversionTestCase(100.0, from: "EUR", to: "USD", rates: ["EUR": -0.92], expected: nil, "negative rate"),
        ])
        func invalidConversions(testCase: ConversionTestCase) {
            // When
            let result = exchangeRateManager.convert(
                testCase.amount,
                from: testCase.from,
                to: testCase.to,
                rates: testCase.rates)

            // Then
            #expect(result == nil)
        }

        @Test("Edge case conversions", arguments: [
            (Double.greatestFiniteMagnitude / 2, "very large number"),
            (Double.leastNormalMagnitude, "very small number")
        ])
        func edgeCaseConversions(amount: Double, description _: String) {
            // Given
            let rates = ["EUR": 0.92]

            // When
            let result = exchangeRateManager.convert(amount, from: "USD", to: "EUR", rates: rates)

            // Then
            #expect(result != nil)
        }

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
                "NZD": 1.4,
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

    // MARK: - Edge Cases Tests

    @Suite("Edge Cases Tests", .tags(.edgeCase))
    struct EdgeCasesTests {
        private let mockURLSession: MockURLSession
        private let exchangeRateManager: ExchangeRateManager

        init() {
            self.mockURLSession = MockURLSession()
            self.exchangeRateManager = ExchangeRateManager(urlSession: mockURLSession)
        }

        @Test("get exchange rates empty rates response")
        func getExchangeRates_EmptyRatesResponse() async {
            // Given
            let mockRatesData = Data("""
            {
                "base": "USD",
                "date": "2023-12-01",
                "rates": {}
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
            #expect(rates.isEmpty == true)
        }

        @Test("get exchange rates malformed HTTP response")
        func getExchangeRates_MalformedHTTPResponse() async {
            // Given
            let mockRatesData = Data()
            mockURLSession.nextData = mockRatesData
            mockURLSession.nextResponse = URLResponse() // Not HTTPURLResponse

            // When
            let rates = await exchangeRateManager.getExchangeRates()

            // Then
            #expect(rates == exchangeRateManager.fallbackRates)
        }
    }

    // MARK: - Network Tests

    @Suite("Network Tests", .tags(.network, .integration, .slow))
    struct NetworkTests {
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

        @Test("Exchange rate fetching success", arguments: [
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
        ])
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

        @Test("Invalid data handling", arguments: [
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
        ])
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
}
