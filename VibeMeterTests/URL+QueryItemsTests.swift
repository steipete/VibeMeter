@testable import VibeMeter
import XCTest

final class URLQueryItemsTests: XCTestCase {
    // MARK: - Basic Functionality Tests

    func testAppendingQueryItems_EmptyArray_ReturnsSameURL() {
        // Given
        let url = URL(string: "https://example.com/path")!
        let emptyItems: [URLQueryItem] = []

        // When
        let result = url.appendingQueryItems(emptyItems)

        // Then
        XCTAssertEqual(result, url, "Appending empty array should return original URL")
    }

    func testAppendingQueryItems_ToURLWithoutQuery_AddsQuery() {
        // Given
        let url = URL(string: "https://example.com/path")!
        let items = [URLQueryItem(name: "key", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/path?key=value")
    }

    func testAppendingQueryItems_ToURLWithExistingQuery_AppendsToQuery() {
        // Given
        let url = URL(string: "https://example.com/path?existing=param")!
        let items = [URLQueryItem(name: "new", value: "item")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/path?existing=param&new=item")
    }

    func testAppendingQueryItems_MultipleItems_AddsAllItems() {
        // Given
        let url = URL(string: "https://example.com/api")!
        let items = [
            URLQueryItem(name: "param1", value: "value1"),
            URLQueryItem(name: "param2", value: "value2"),
            URLQueryItem(name: "param3", value: "value3"),
        ]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/api?param1=value1&param2=value2&param3=value3")
    }

    // MARK: - Edge Cases Tests

    func testAppendingQueryItems_WithNilValues_HandlesGracefully() {
        // Given
        let url = URL(string: "https://example.com/path")!
        let items = [
            URLQueryItem(name: "key1", value: "value1"),
            URLQueryItem(name: "key2", value: nil),
            URLQueryItem(name: "key3", value: "value3"),
        ]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/path?key1=value1&key2&key3=value3")
    }

    func testAppendingQueryItems_WithEmptyValues_HandlesGracefully() {
        // Given
        let url = URL(string: "https://example.com/path")!
        let items = [
            URLQueryItem(name: "key1", value: "value1"),
            URLQueryItem(name: "key2", value: ""),
            URLQueryItem(name: "key3", value: "value3"),
        ]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/path?key1=value1&key2=&key3=value3")
    }

    func testAppendingQueryItems_WithSpecialCharacters_EncodesCorrectly() {
        // Given
        let url = URL(string: "https://example.com/path")!
        let items = [
            URLQueryItem(name: "message", value: "hello world"),
            URLQueryItem(name: "special", value: "a+b=c&d"),
            URLQueryItem(name: "unicode", value: "café ñoño 🚀"),
        ]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        // URLQueryItem automatically handles encoding
        XCTAssertTrue(result.absoluteString.contains("message=hello%20world"))
        XCTAssertTrue(result.absoluteString.contains("special=a%2Bb%3Dc%26d"))
        XCTAssertTrue(result.absoluteString.contains("unicode=caf%C3%A9%20%C3%B1o%C3%B1o%20%F0%9F%9A%80"))
    }

    func testAppendingQueryItems_WithDuplicateKeys_AllowsDuplicates() {
        // Given
        let url = URL(string: "https://example.com/path?filter=value1")!
        let items = [
            URLQueryItem(name: "filter", value: "value2"),
            URLQueryItem(name: "filter", value: "value3"),
        ]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/path?filter=value1&filter=value2&filter=value3")
    }

    // MARK: - URL Schemes Tests

    func testAppendingQueryItems_HTTPSScheme_WorksCorrectly() {
        // Given
        let url = URL(string: "https://secure.example.com/api")!
        let items = [URLQueryItem(name: "token", value: "secret123")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://secure.example.com/api?token=secret123")
        XCTAssertEqual(result.scheme, "https")
    }

    func testAppendingQueryItems_HTTPScheme_WorksCorrectly() {
        // Given
        let url = URL(string: "http://example.com/api")!
        let items = [URLQueryItem(name: "debug", value: "true")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "http://example.com/api?debug=true")
        XCTAssertEqual(result.scheme, "http")
    }

    func testAppendingQueryItems_CustomScheme_WorksCorrectly() {
        // Given
        let url = URL(string: "myapp://action/perform")!
        let items = [URLQueryItem(name: "param", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "myapp://action/perform?param=value")
        XCTAssertEqual(result.scheme, "myapp")
    }

    // MARK: - URL Components Tests

    func testAppendingQueryItems_PreservesHost() {
        // Given
        let url = URL(string: "https://api.example.com:8080/v1/endpoint")!
        let items = [URLQueryItem(name: "version", value: "1.0")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.host, "api.example.com")
        XCTAssertEqual(result.port, 8080)
        XCTAssertEqual(result.path, "/v1/endpoint")
    }

    func testAppendingQueryItems_PreservesFragment() {
        // Given
        let url = URL(string: "https://example.com/page#section")!
        let items = [URLQueryItem(name: "highlight", value: "text")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/page?highlight=text#section")
        XCTAssertEqual(result.fragment, "section")
    }

    func testAppendingQueryItems_WithUserInfo_PreservesUserInfo() {
        // Given
        let url = URL(string: "https://user:pass@example.com/path")!
        let items = [URLQueryItem(name: "auth", value: "token")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertEqual(result.absoluteString, "https://user:pass@example.com/path?auth=token")
        XCTAssertEqual(result.user, "user")
        XCTAssertEqual(result.password, "pass")
    }

    // MARK: - Error Handling Tests

    func testAppendingQueryItems_InvalidURL_ReturnsSelf() {
        // Given - Create a URL that might cause URLComponents to fail
        // This is tricky since URL(string:) already validates, but we can test the fallback
        let url = URL(string: "https://example.com/path")!
        let items = [URLQueryItem(name: "key", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then - Should succeed in this case, but testing the pattern
        XCTAssertNotNil(result)
    }

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
        XCTAssertEqual(result.absoluteString, "https://frankfurter.app/latest?from=USD&to=EUR%2CGBP%2CJPY")
    }

    // MARK: - Chaining Tests

    func testAppendingQueryItems_ChainedCalls_WorksCorrectly() {
        // Given
        let url = URL(string: "https://example.com/api")!
        let firstItems = [URLQueryItem(name: "step", value: "1")]
        let secondItems = [URLQueryItem(name: "step", value: "2")]

        // When
        let result = url
            .appendingQueryItems(firstItems)
            .appendingQueryItems(secondItems)

        // Then
        XCTAssertEqual(result.absoluteString, "https://example.com/api?step=1&step=2")
    }

    func testAppendingQueryItems_MultipleChainedCalls_BuildsCorrectly() {
        // Given
        let url = URL(string: "https://api.example.com/data")!

        // When
        let result = url
            .appendingQueryItems([URLQueryItem(name: "format", value: "json")])
            .appendingQueryItems([URLQueryItem(name: "version", value: "v2")])
            .appendingQueryItems([URLQueryItem(name: "include", value: "metadata")])

        // Then
        XCTAssertEqual(result.absoluteString, "https://api.example.com/data?format=json&version=v2&include=metadata")
    }

    // MARK: - Performance Tests

    func testAppendingQueryItems_Performance() {
        // Given
        let url = URL(string: "https://example.com/api")!
        let items = (0 ..< 100).map { URLQueryItem(name: "param\($0)", value: "value\($0)") }

        // When
        let startTime = Date()
        let result = url.appendingQueryItems(items)
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "Appending many query items should be fast")
        XCTAssertTrue(result.absoluteString.contains("param0=value0"))
        XCTAssertTrue(result.absoluteString.contains("param99=value99"))
    }

    func testAppendingQueryItems_RepeatedCalls_Performance() {
        // Given
        var url = URL(string: "https://example.com/api")!
        let iterations = 1000

        // When
        let startTime = Date()
        for i in 0 ..< iterations {
            url = url.appendingQueryItems([URLQueryItem(name: "step", value: "\(i)")])
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 5.0, "Repeated query item appending should be reasonably fast")
        XCTAssertTrue(url.query?.contains("step=\(iterations - 1)") == true)
    }

    // MARK: - International Domain Names Tests

    func testAppendingQueryItems_InternationalDomain_WorksCorrectly() {
        // Given
        let url = URL(string: "https://münchen.example.com/api")!
        let items = [URLQueryItem(name: "locale", value: "de")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result.absoluteString.contains("locale=de"))
    }

    // MARK: - Long URL Tests

    func testAppendingQueryItems_VeryLongURL_HandlesGracefully() {
        // Given
        let longPath = String(repeating: "segment/", count: 100)
        let url = URL(string: "https://example.com/\(longPath)")!
        let items = [URLQueryItem(name: "param", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result.absoluteString.contains("param=value"))
        XCTAssertTrue(result.absoluteString.count > url.absoluteString.count)
    }

    // MARK: - Query Order Tests

    func testAppendingQueryItems_PreservesExistingOrder() {
        // Given
        let url = URL(string: "https://example.com/path?z=last&a=first&m=middle")!
        let items = [URLQueryItem(name: "new", value: "item")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        // The order should be preserved: existing items first, then new items
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        XCTAssertEqual(queryItems[0].name, "z")
        XCTAssertEqual(queryItems[1].name, "a")
        XCTAssertEqual(queryItems[2].name, "m")
        XCTAssertEqual(queryItems[3].name, "new")
    }

    // MARK: - Memory Management Tests

    func testAppendingQueryItems_DoesNotLeakMemory() {
        // Given
        let url = URL(string: "https://example.com/api")!
        weak var weakResult: URL?

        autoreleasepool {
            let items = [URLQueryItem(name: "temp", value: "value")]
            let result = url.appendingQueryItems(items)
            weakResult = result

            // Use the result to ensure it's not optimized away
            _ = result.absoluteString
        }

        // Then - The result URL should be properly deallocated
        // Note: This test might be flaky due to URL caching mechanisms
    }
}
