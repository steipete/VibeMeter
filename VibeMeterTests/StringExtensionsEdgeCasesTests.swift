@testable import VibeMeter
import XCTest

final class StringExtensionsEdgeCasesTests: XCTestCase {
    // MARK: - Edge Cases Tests

    func testTruncate_NegativeLength_HandlesGracefully() {
        // Given
        let string = "Hello"
        let length = -1

        // When
        let result = string.truncate(length: length)

        // Then
        // Negative length should result in empty prefix + trailing
        XCTAssertEqual(result, "...")
    }

    func testTruncated_NegativeLength_HandlesGracefully() {
        // Given
        let string = "Hello"
        let length = -1

        // When
        let result = string.truncated(to: length)

        // Then
        // Negative length - 3 = -4, prefix(-4) should be empty
        XCTAssertEqual(result, "...")
    }

    func testTruncate_VeryLongString_PerformanceTest() {
        // Given
        let longString = String(repeating: "a", count: 100_000)
        let length = 50

        // When
        let startTime = Date()
        let result = longString.truncate(length: length)
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertEqual(result.count, 53) // 50 + 3 for "..."
        XCTAssertLessThan(duration, 1.0, "Truncation should be fast even for very long strings")
    }

    func testTruncated_VeryLongString_PerformanceTest() {
        // Given
        let longString = String(repeating: "b", count: 100_000)
        let length = 50

        // When
        let startTime = Date()
        let result = longString.truncated(to: length)
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertEqual(result.count, 50)
        XCTAssertLessThan(duration, 1.0, "Truncation should be fast even for very long strings")
    }

    // MARK: - Whitespace and Special Characters Tests

    func testTruncate_StringWithWhitespace_PreservesWhitespace() {
        // Given
        let string = "   Hello World   "
        let length = 10

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "   Hello W...")
    }

    func testTruncated_StringWithWhitespace_PreservesWhitespace() {
        // Given
        let string = "   Hello World   "
        let length = 10

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "   Hell...")
        XCTAssertEqual(result.count, 10)
    }

    func testTruncate_StringWithNewlines_PreservesNewlines() {
        // Given
        let string = "First line\nSecond line\nThird line"
        let length = 15

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "First line\nSeco...")
    }

    func testTruncated_StringWithTabs_PreservesTabs() {
        // Given
        let string = "Column1\tColumn2\tColumn3\tColumn4"
        let length = 20

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "Column1\tColumn2\tC...")
        XCTAssertEqual(result.count, 20)
    }

    // MARK: - International Text Tests

    func testTruncate_ChineseCharacters_HandlesCorrectly() {
        // Given
        let string = "这是一个很长的中文字符串用于测试"
        let length = 8

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "这是一个很长的中...")
    }

    func testTruncated_ArabicCharacters_HandlesCorrectly() {
        // Given
        let string = "هذا نص طويل باللغة العربية للاختبار"
        let length = 15

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result.count, 15)
        XCTAssertTrue(result.hasSuffix("..."))
    }

    func testTruncate_MixedLanguages_HandlesCorrectly() {
        // Given
        let string = "English 中文 العربية Русский"
        let length = 12

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "English 中文 ا...")
    }

    // MARK: - Boundary Value Tests

    func testTruncate_MaxIntLength_HandlesCorrectly() {
        // Given
        let string = "Test"
        let length = Int.max

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "Test")
    }

    func testTruncated_MaxIntLength_HandlesCorrectly() {
        // Given
        let string = "Test"
        let length = Int.max

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "Test")
    }

    // MARK: - Memory and Performance Tests

    func testTruncate_MemoryEfficiency() {
        // Given
        let baseString = String(repeating: "x", count: 1000)

        // When - Create many truncated versions
        var results: [String] = []
        for i in 1 ... 100 {
            results.append(baseString.truncate(length: i * 10))
        }

        // Then - Should complete without memory issues
        XCTAssertEqual(results.count, 100)
        XCTAssertEqual(results[0], String(repeating: "x", count: 10) + "...")
    }

    func testTruncated_MemoryEfficiency() {
        // Given
        let baseString = String(repeating: "y", count: 1000)

        // When - Create many truncated versions
        var results: [String] = []
        for i in 1 ... 100 {
            results.append(baseString.truncated(to: i * 10))
        }

        // Then - Should complete without memory issues
        XCTAssertEqual(results.count, 100)
        XCTAssertEqual(results[0].count, 10)
    }
}
