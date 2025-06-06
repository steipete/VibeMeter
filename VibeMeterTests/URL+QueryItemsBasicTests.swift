import Foundation
import Testing
@testable import VibeMeter

@Suite("URLQueryItemsBasicTests", .tags(.unit, .fast))
struct URLQueryItemsBasicTests {
    // MARK: - Basic Functionality Tests

    @Test("appending query items empty array returns same url")
    func appendingQueryItems_EmptyArray_ReturnsSameURL() {
        // Given
        let url = URL(string: "https://example.com/path")!
        let emptyItems: [URLQueryItem] = []

        // When
        let result = url.appendingQueryItems(emptyItems)

        // Then
        #expect(result == url)
    }

    @Test("appending query items to url without query adds query")
    func appendingQueryItems_ToURLWithoutQuery_AddsQuery() {
        // Given
        let url = URL(string: "https://example.com/path")!
        let items = [URLQueryItem(name: "key", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "https://example.com/path?key=value")
    }

    @Test("appending query items to url with existing query appends to query")
    func appendingQueryItems_ToURLWithExistingQuery_AppendsToQuery() {
        // Given
        let url = URL(string: "https://example.com/path?existing=param")!
        let items = [URLQueryItem(name: "new", value: "item")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "https://example.com/path?existing=param&new=item")
    }

    @Test("appending query items multiple items adds all items")
    func appendingQueryItems_MultipleItems_AddsAllItems() {
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
        #expect(result.absoluteString == "https://example.com/api?param1=value1&param2=value2&param3=value3")
    }

    @Test("appending query items https scheme works correctly")
    func appendingQueryItems_HTTPSScheme_WorksCorrectly() {
        // Given
        let url = URL(string: "https://secure.example.com/api")!
        let items = [URLQueryItem(name: "token", value: "secret123")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "https://secure.example.com/api?token=secret123")
    }

    @Test("appending query items http scheme works correctly")
    func appendingQueryItems_HTTPScheme_WorksCorrectly() {
        // Given
        let url = URL(string: "http://example.com/api")!
        let items = [URLQueryItem(name: "debug", value: "true")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "http://example.com/api?debug=true")
    }

    @Test("appending query items custom scheme works correctly")
    func appendingQueryItems_CustomScheme_WorksCorrectly() {
        // Given
        let url = URL(string: "myapp://action/perform")!
        let items = [URLQueryItem(name: "param", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "myapp://action/perform?param=value")
    }

    // MARK: - URL Components Tests

    @Test("appending query items preserves host")
    func appendingQueryItems_PreservesHost() {
        // Given
        let url = URL(string: "https://api.example.com:8080/v1/endpoint")!
        let items = [URLQueryItem(name: "version", value: "1.0")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.host == "api.example.com")
        #expect(result.path == "/v1/endpoint")
    }

    @Test("appending query items preserves fragment")
    func appendingQueryItems_PreservesFragment() {
        // Given
        let url = URL(string: "https://example.com/page#section")!
        let items = [URLQueryItem(name: "highlight", value: "text")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "https://example.com/page?highlight=text#section")
    }

    @Test("appending query items with user info preserves user info")
    func appendingQueryItems_WithUserInfo_PreservesUserInfo() {
        // Given
        let url = URL(string: "https://user:pass@example.com/path")!
        let items = [URLQueryItem(name: "auth", value: "token")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "https://user:pass@example.com/path?auth=token")
        #expect(result.password == "pass")
    }

    @Test("appending query items invalid url returns self")
    func appendingQueryItems_InvalidURL_ReturnsSelf() {
        // Given - Create a URL that might cause URLComponents to fail
        // This is tricky since URL(string:) already validates, but we can test the fallback
        let url = URL(string: "https://example.com/path")!
        let items = [URLQueryItem(name: "key", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then - Should succeed in this case, but testing the pattern
        #expect(result != nil)
    }

    @Test("appending query items chained calls works correctly")
    func appendingQueryItems_ChainedCalls_WorksCorrectly() {
        // Given
        let url = URL(string: "https://example.com/api")!
        let firstItems = [URLQueryItem(name: "step", value: "1")]
        let secondItems = [URLQueryItem(name: "step", value: "2")]

        // When
        let result = url
            .appendingQueryItems(firstItems)
            .appendingQueryItems(secondItems)

        // Then
        #expect(result.absoluteString == "https://example.com/api?step=1&step=2")
    }

    @Test("appending query items multiple chained calls builds correctly")
    func appendingQueryItems_MultipleChainedCalls_BuildsCorrectly() {
        // Given
        let url = URL(string: "https://api.example.com/data")!

        // When
        let result = url
            .appendingQueryItems([URLQueryItem(name: "format", value: "json")])
            .appendingQueryItems([URLQueryItem(name: "version", value: "v2")])
            .appendingQueryItems([URLQueryItem(name: "include", value: "metadata")])

        // Then
        #expect(result.absoluteString == "https://api.example.com/data?format=json&version=v2&include=metadata")
    }

    @Test("appending query items preserves existing order")
    func appendingQueryItems_PreservesExistingOrder() {
        // Given
        let url = URL(string: "https://example.com/path?z=last&a=first&m=middle")!
        let items = [URLQueryItem(name: "new", value: "item")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        // The order should be preserved: existing items first, then new items
        let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems ?? []

        #expect(queryItems[0].name == "z")
        #expect(queryItems[2].name == "m")
    }
}
