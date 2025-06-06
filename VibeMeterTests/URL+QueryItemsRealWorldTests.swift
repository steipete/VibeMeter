import Foundation
@testable import VibeMeter
import Testing

@Suite("URLQueryItemsRealWorldTests")
struct URLQueryItemsRealWorldTests {
    // MARK: - Real-World Usage Tests

    @Test("appending query items api endpoint with authentication")
    func appendingQueryItems_APIEndpoint_WithAuthentication() {
        // Given - Simulating API endpoint construction
        let baseURL = URL(string: "https://api.cursor.sh/v1/invoices")!
        let authItems = [
            URLQueryItem(name: "api_key", value: "sk_test_123456"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "offset", value: "0"),
        ]

        // When
        let result = baseURL.appendingQueryItems(authItems)

        // Then
        #expect(
            result.absoluteString == "https://api.cursor.sh/v1/invoices?api_key=sk_test_123456&limit=50&offset=0")
    }

    @Test("appending query items search endpoint with filters")
    func appendingQueryItems_SearchEndpoint_WithFilters() {
        // Given - Simulating search with multiple filters
        let searchURL = URL(string: "https://api.example.com/search?q=swift")!
        let filters = [
            URLQueryItem(name: "category", value: "programming"),
            URLQueryItem(name: "sort", value: "relevance"),
            URLQueryItem(name: "page", value: "1"),
        ]

        // When
        let result = searchURL.appendingQueryItems(filters)

        // Then
        #expect(
            result.absoluteString == "https://api.example.com/search?q=swift&category=programming&sort=relevance&page=1")
    }

    @Test("appending query items exchange rate api with currency codes")
    func appendingQueryItems_ExchangeRateAPI_WithCurrencyCodes() {
        // Given - Simulating exchange rate API call
        let baseURL = URL(string: "https://frankfurter.app/latest")!
        let currencyItems = [
            URLQueryItem(name: "from", value: "USD"),
            URLQueryItem(name: "to", value: "EUR,GBP,JPY"),
        ]

        // When
        let result = baseURL.appendingQueryItems(currencyItems)

        // Then
        #expect(result.absoluteString == "https://frankfurter.app/latest?from=USD&to=EUR%2CGBP%2CJPY")
    }
}
