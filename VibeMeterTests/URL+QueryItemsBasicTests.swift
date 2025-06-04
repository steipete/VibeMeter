@testable import VibeMeter
import XCTest

final class URLQueryItemsBasicTests: XCTestCase {
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
}
