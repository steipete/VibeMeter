import Foundation
import Testing
@testable import VibeMeter

@Suite("StringExtensionsEdgeCasesTests", .tags(.unit, .edgeCase))
struct StringExtensionsEdgeCasesTests {
    // MARK: - Edge Cases Tests

    @Test("truncate negative length handles gracefully")
    func truncate_NegativeLength_HandlesGracefully() {
        // Given
        let string = "Hello"
        let length = -1

        // When
        let result = string.truncate(length: length)

        // Then
        // Negative length should result in empty string
        #expect(result == "")
    }

    @Test("truncated negative length handles gracefully")
    func truncated_NegativeLength_HandlesGracefully() {
        // Given
        let string = "Hello"
        let length = -1

        // When
        let result = string.truncated(to: length)

        // Then
        // Negative length (which is <= 3) returns "..." per MenuBar implementation
        #expect(result == "...")
    }

    @Test("truncate very long string performance test")
    func truncate_VeryLongString_PerformanceTest() {
        // Given
        let longString = String(repeating: "a", count: 100_000)
        let length = 50

        // When
        let startTime = Date()
        let result = longString.truncate(length: length)
        let duration = Date().timeIntervalSince(startTime)

        // Then
        #expect(result.count <= 53) // truncate adds trailing after length
        #expect(duration < 1.0)
    }

    @Test("truncated very long string performance test")
    func truncated_VeryLongString_PerformanceTest() {
        // Given
        let longString = String(repeating: "b", count: 100_000)
        let length = 50

        // When
        let startTime = Date()
        let result = longString.truncated(to: length)
        let duration = Date().timeIntervalSince(startTime)

        // Then
        #expect(result.count == 50)
        #expect(duration < 1.0)
    }

    // MARK: - Whitespace and Special Characters Tests

    @Test("truncate string with whitespace preserves whitespace")
    func truncate_StringWithWhitespace_PreservesWhitespace() {
        // Given
        let string = "   Hello World   "
        let length = 10

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "   Hell...") // truncate keeps (length - trailing.count) chars + trailing
    }

    @Test("truncated string with whitespace preserves whitespace")
    func truncated_StringWithWhitespace_PreservesWhitespace() {
        // Given
        let string = "   Hello World   "
        let length = 10

        // When
        let result = string.truncated(to: length)

        // Then
        #expect(result == "   Hell...")
    }

    @Test("truncate string with newlines preserves newlines")
    func truncate_StringWithNewlines_PreservesNewlines() {
        // Given
        let string = "First line\nSecond line\nThird line"
        let length = 15

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "First line\nS...") // truncate keeps (length - trailing.count) chars + trailing
    }

    @Test("truncated string with tabs preserves tabs")
    func truncated_StringWithTabs_PreservesTabs() {
        // Given
        let string = "Column1\tColumn2\tColumn3\tColumn4"
        let length = 20

        // When
        let result = string.truncated(to: length)

        // Then
        #expect(result == "Column1\tColumn2\tC...")
    }

    // MARK: - International Text Tests

    @Test("truncate chinese characters handles correctly")
    func truncate_ChineseCharacters_HandlesCorrectly() {
        // Given
        let string = "这是一个很长的中文字符串用于测试"
        let length = 8

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "这是一个很...") // truncate keeps (length - trailing.count) chars + trailing
    }

    @Test("truncated arabic characters handles correctly")
    func truncated_ArabicCharacters_HandlesCorrectly() {
        // Given
        let string = "هذا نص طويل باللغة العربية للاختبار"
        let length = 15

        // When
        let result = string.truncated(to: length)

        // Then
        #expect(result.count == 15)
    }

    @Test("truncate mixed languages handles correctly")
    func truncate_MixedLanguages_HandlesCorrectly() {
        // Given
        let string = "English 中文 العربية Русский"
        let length = 12

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "English 中...") // truncate keeps (length - trailing.count) chars + trailing
    }

    @Test("truncate max int length handles correctly")
    func truncate_MaxIntLength_HandlesCorrectly() {
        // Given
        let string = "Test"
        let length = Int.max

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "Test")
    }

    @Test("truncated max int length handles correctly")
    func truncated_MaxIntLength_HandlesCorrectly() {
        // Given
        let string = "Test"
        let length = Int.max

        // When
        let result = string.truncated(to: length)

        // Then
        #expect(result == "Test")
    }

    @Test("truncate memory efficiency")
    func truncate_MemoryEfficiency() {
        // Given
        let baseString = String(repeating: "x", count: 1000)

        // When - Create many truncated versions
        var results: [String] = []
        for i in 1 ... 100 {
            results.append(baseString.truncate(length: i * 10))
        }

        // Then - Should complete without memory issues
        #expect(results.count == 100)
    }

    @Test("truncated memory efficiency")
    func truncated_MemoryEfficiency() {
        // Given
        let baseString = String(repeating: "y", count: 1000)

        // When - Create many truncated versions
        var results: [String] = []
        for i in 1 ... 100 {
            results.append(baseString.truncated(to: i * 10))
        }

        // Then - Should complete without memory issues
        #expect(results.count == 100)
    }
}
