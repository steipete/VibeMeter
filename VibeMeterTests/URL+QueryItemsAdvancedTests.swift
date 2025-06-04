@testable import VibeMeter
import XCTest

final class URLQueryItemsAdvancedTests: XCTestCase {
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
        XCTAssertTrue(result.absoluteString.contains("special=a+b%3Dc%26d")) // + is not encoded in query strings
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

    // MARK: - Memory Management Tests

    func testAppendingQueryItems_EfficientMemoryUsage() {
        // Given
        let url = URL(string: "https://example.com/api")!
        var results: [URL] = []

        // When - Create many URLs to test memory efficiency
        for i in 0 ..< 1000 {
            let items = [URLQueryItem(name: "index", value: "\(i)")]
            let result = url.appendingQueryItems(items)
            results.append(result)
        }

        // Then - Should create all URLs without issues
        XCTAssertEqual(results.count, 1000)
        XCTAssertEqual(results.first?.query, "index=0")
        XCTAssertEqual(results.last?.query, "index=999")
    }
}
