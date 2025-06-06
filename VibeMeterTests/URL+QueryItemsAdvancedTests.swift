import Foundation
import Testing
@testable import VibeMeter

@Suite("URLQueryItemsAdvancedTests", .tags(.unit, .edgeCase))
struct URLQueryItemsAdvancedTests {
    // MARK: - Edge Cases Tests

    @Test("appending query items with nil values handles gracefully")
    func appendingQueryItems_WithNilValues_HandlesGracefully() {
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
        #expect(result.absoluteString == "https://example.com/path?key1=value1&key2&key3=value3")
    }

    @Test("appending query items with empty values handles gracefully")
    func appendingQueryItems_WithEmptyValues_HandlesGracefully() {
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
        #expect(result.absoluteString == "https://example.com/path?key1=value1&key2=&key3=value3")
    }

    @Test("appending query items with special characters encodes correctly")
    func appendingQueryItems_WithSpecialCharacters_EncodesCorrectly() {
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
        #expect(result.absoluteString.contains("message=hello%20world")) // + is not encoded in query strings
        #expect(result.absoluteString.contains("unicode=caf%C3%A9%20%C3%B1o%C3%B1o%20%F0%9F%9A%80"))
    }

    @Test("appending query items with duplicate keys allows duplicates")
    func appendingQueryItems_WithDuplicateKeys_AllowsDuplicates() {
        // Given
        let url = URL(string: "https://example.com/path?filter=value1")!
        let items = [
            URLQueryItem(name: "filter", value: "value2"),
            URLQueryItem(name: "filter", value: "value3"),
        ]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString == "https://example.com/path?filter=value1&filter=value2&filter=value3")
    }

    @Test("appending query items international domain works correctly")
    func appendingQueryItems_InternationalDomain_WorksCorrectly() {
        // Given
        let url = URL(string: "https://münchen.example.com/api")!
        let items = [URLQueryItem(name: "locale", value: "de")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString.contains("locale=de"))
    }

    // MARK: - Long URL Tests

    @Test("appending query items very long url handles gracefully")
    func appendingQueryItems_VeryLongURL_HandlesGracefully() {
        // Given
        let longPath = String(repeating: "segment/", count: 100)
        let url = URL(string: "https://example.com/\(longPath)")!
        let items = [URLQueryItem(name: "param", value: "value")]

        // When
        let result = url.appendingQueryItems(items)

        // Then
        #expect(result.absoluteString.contains("param=value"))
        #expect(result.absoluteString.count > url.absoluteString.count)
    }

    @Test("appending query items performance")
    func appendingQueryItems_Performance() {
        // Given
        let url = URL(string: "https://example.com/api")!
        let items = (0 ..< 100).map { URLQueryItem(name: "param\($0)", value: "value\($0)") }

        // When
        let startTime = Date()
        let result = url.appendingQueryItems(items)
        let duration = Date().timeIntervalSince(startTime)

        // Then
        #expect(duration < 1.0)
        #expect(result.absoluteString.contains("param99=value99"))
    }

    @Test("appending query items repeated calls performance")
    func appendingQueryItems_RepeatedCalls_Performance() {
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
        #expect(duration < 5.0)
    }

    // MARK: - Memory Management Tests

    @Test("appending query items efficient memory usage")
    func appendingQueryItems_EfficientMemoryUsage() {
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
        #expect(results.count == 1000)
        #expect(results.last?.query == "index=999")
    }
}
