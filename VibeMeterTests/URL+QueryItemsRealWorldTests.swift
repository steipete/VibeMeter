@testable import VibeMeter
import XCTest

final class URLQueryItemsRealWorldTests: XCTestCase {
    // MARK: - Real-World Usage Tests

    func testAppendingQueryItems_APIEndpoint_WithAuthentication() {
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
        XCTAssertEqual(
            result.absoluteString,
            "https://api.cursor.sh/v1/invoices?api_key=sk_test_123456&limit=50&offset=0")
    }

    func testAppendingQueryItems_SearchEndpoint_WithFilters() {
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
        XCTAssertEqual(
            result.absoluteString,
            "https://api.example.com/search?q=swift&category=programming&sort=relevance&page=1")
    }

    func testAppendingQueryItems_ExchangeRateAPI_WithCurrencyCodes() {
        // Given - Simulating exchange rate API call
        let baseURL = URL(string: "https://frankfurter.app/latest")!
        let currencyItems = [
            URLQueryItem(name: "from", value: "USD"),
            URLQueryItem(name: "to", value: "EUR,GBP,JPY"),
        ]

        // When
        let result = baseURL.appendingQueryItems(currencyItems)

        // Then
        XCTAssertEqual(result.absoluteString, "https://frankfurter.app/latest?from=USD&to=EUR,GBP,JPY")
    }
}
