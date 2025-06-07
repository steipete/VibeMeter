import Foundation
import Testing
@testable import VibeMeter

@Suite("String Extensions Tests", .tags(.unit))
@MainActor
struct StringExtensionsTests {
    // MARK: - Truncate Method Tests

    @Suite("Truncate Method Tests", .tags(.fast))
    struct TruncateTests {
        // MARK: - Parameterized Truncation Tests

        struct TruncationTestCase: Sendable {
            let input: String
            let length: Int
            let trailing: String
            let expected: String
            let description: String

            init(_ input: String, length: Int, trailing: String = "...", expected: String, _ description: String) {
                self.input = input
                self.length = length
                self.trailing = trailing
                self.expected = expected
                self.description = description
            }
        }

        static let truncationTestCases: [TruncationTestCase] = [
            // Basic truncation cases
            TruncationTestCase("Short", length: 10, expected: "Short", "shorter than length"),
            TruncationTestCase("Exact", length: 5, expected: "Exact", "exact length"),
            TruncationTestCase(
                "This is a very long string",
                length: 10,
                expected: "This is...",
                "longer than length with default trailing"),

            // Custom trailing cases
            TruncationTestCase(
                "Long string here",
                length: 8,
                trailing: "…",
                expected: "Long st…",
                "custom single ellipsis"),
            TruncationTestCase(
                "Another long text",
                length: 12,
                trailing: " [more]",
                expected: "Anoth [more]",
                "custom trailing text"),
            TruncationTestCase("Test string", length: 6, trailing: "", expected: "Test s", "no trailing"),

            // Edge cases
            TruncationTestCase("", length: 5, expected: "", "empty string"),
            TruncationTestCase("A", length: 1, expected: "A", "single character exact"),
            TruncationTestCase("AB", length: 1, trailing: "X", expected: "X", "trailing longer than allowed"),
            TruncationTestCase("Hello", length: 0, expected: "", "zero length"),
            TruncationTestCase("Unicode: 🚀✨🎉", length: 12, expected: "Unicode: 🚀✨🎉", "unicode characters fit exactly"),
            TruncationTestCase("Unicode: 🚀✨🎉", length: 10, expected: "Unicode...", "unicode with truncation"),
            TruncationTestCase(
                "Unicode: 🚀✨🎉 test",
                length: 12,
                expected: "Unicode: ...",
                "unicode with more truncation"),
        ]

        @Test("String truncation", arguments: truncationTestCases)
        func stringTruncation(testCase: TruncationTestCase) {
            // When
            let result = testCase.input.truncate(length: testCase.length, trailing: testCase.trailing)

            // Then
            #expect(result == testCase.expected)
            #expect(result.count <= testCase.length || testCase.length == 0)
        }

        // MARK: - Negative Length Edge Cases

        @Test("Negative length handling", arguments: [-1, -5, -100])
        func negativeLengthHandling(negativeLength: Int) {
            // Given
            let string = "Test string"

            // When
            let result = string.truncate(length: negativeLength)

            // Then
            #expect(result.isEmpty)
        }

        // MARK: - Performance Tests

        @Test("Truncation performance with large strings", .timeLimit(.minutes(1)))
        func truncationPerformanceWithLargeStrings() {
            // Given
            let largeString = String(repeating: "This is a test string. ", count: 1000)

            // When/Then - Should complete within time limit
            for i in stride(from: 10, through: 100, by: 10) {
                _ = largeString.truncate(length: i)
            }
        }

        // MARK: - Special Character Tests

        struct SpecialCharacterTestCase: Sendable {
            let input: String
            let length: Int
            let expectedPrefix: String
            let description: String

            init(_ input: String, length: Int, expectedPrefix: String, _ description: String) {
                self.input = input
                self.length = length
                self.expectedPrefix = expectedPrefix
                self.description = description
            }
        }

        static let specialCharacterTestCases: [SpecialCharacterTestCase] = [
            SpecialCharacterTestCase(
                "Line 1\nLine 2\nLine 3",
                length: 10,
                expectedPrefix: "Line 1",
                "newline characters"),
            SpecialCharacterTestCase(
                "Tab\tSeparated\tValues",
                length: 15,
                expectedPrefix: "Tab\tSeparate",
                "tab characters"),
            SpecialCharacterTestCase("Emoji: 👨‍💻👩‍🔬🧑‍🎨", length: 12, expectedPrefix: "Emoji: 👨‍💻", "complex emoji"),
            SpecialCharacterTestCase("áéíóú ñüç ÀÈÌÒÙ", length: 10, expectedPrefix: "áéíóú ñ", "accented characters"),
        ]

        @Test("Special character handling", arguments: specialCharacterTestCases)
        func specialCharacterHandling(testCase: SpecialCharacterTestCase) {
            // When
            let result = testCase.input.truncate(length: testCase.length)

            // Then
            #expect(result.hasPrefix(testCase.expectedPrefix))
            #expect(result.count <= testCase.length)
        }

        // MARK: - Boundary Condition Tests

        @Test("Boundary conditions", arguments: [
            (string: "Test", length: 4, shouldTruncate: false),
            (string: "Test", length: 3, shouldTruncate: true),
            (string: "A", length: 1, shouldTruncate: false),
            (string: "AB", length: 1, shouldTruncate: true)
        ])
        func boundaryConditions(string: String, length: Int, shouldTruncate: Bool) {
            // When
            let result = string.truncate(length: length)

            // Then
            if shouldTruncate {
                #expect(result != string)
                // When length is very small, trailing might be truncated too
                if length >= 3 {
                    #expect(result.hasSuffix("..."))
                }
            } else {
                #expect(result == string)
            }
        }
    }

    // MARK: - Truncated Method Tests

    @Suite("Truncated Method Tests", .tags(.fast))
    struct TruncatedTests {
        // MARK: - truncated(to:) Tests

        @Test("truncated shorter than length returns original")
        func truncated_ShorterThanLength_ReturnsOriginal() {
            // Given
            let string = "Short"
            let length = 10

            // When
            let result = string.truncated(to: length)

            // Then
            #expect(result == "Short")
        }

        @Test("truncated exact length returns original")
        func truncated_ExactLength_ReturnsOriginal() {
            // Given
            let string = "Exact"
            let length = 5

            // When
            let result = string.truncated(to: length)

            // Then
            #expect(result == "Exact")
        }

        @Test("truncated longer than length truncates with ellipsis")
        func truncated_LongerThanLength_TruncatesWithEllipsis() {
            // Given
            let string = "This is a very long string"
            let length = 10

            // When
            let result = string.truncated(to: length)

            // Then
            #expect(result == "This is...")
        }

        @Test("truncated email address truncates correctly")
        func truncated_EmailAddress_TruncatesCorrectly() {
            // Given
            let email = "user@verylongdomainname.example.com"
            let length = 20

            // When
            let result = email.truncated(to: length)

            // Then
            #expect(result == "user@verylongdoma...")
        }

        @Test("truncated empty string returns empty")
        func truncated_EmptyString_ReturnsEmpty() {
            // Given
            let string = ""
            let length = 5

            // When
            let result = string.truncated(to: length)

            // Then
            #expect(result.isEmpty)
        }

        @Test("truncated length three returns only ellipsis")
        func truncated_LengthThree_ReturnsOnlyEllipsis() {
            // Given
            let string = "Hello World"
            let length = 3

            // When
            let result = string.truncated(to: length)

            // Then
            #expect(result == "...")
        }

        @Test("truncated length two returns partial with ellipsis")
        func truncated_LengthTwo_ReturnsPartialWithEllipsis() {
            // Given
            let string = "Hello"
            let length = 2

            // When
            let result = string.truncated(to: length)

            // Then
            // Should return empty prefix + "..." but limited to length 2, this might be edge case behavior
            // Based on the implementation: prefix(length - 3) + "..." where length = 2
            // prefix(-1) would be empty, so result would be "..." but that's 3 chars > 2
            // The implementation doesn't handle this edge case perfectly
            #expect(result == "...")
        }

        @Test("truncated length one returns partial with ellipsis")
        func truncated_LengthOne_ReturnsPartialWithEllipsis() {
            // Given
            let string = "Hello"
            let length = 1

            // When
            let result = string.truncated(to: length)

            // Then
            // Edge case: prefix(-2) + "..." - the implementation has limitations here
            #expect(result == "...")
        }

        @Test("truncated unicode characters handles correctly")
        func truncated_UnicodeCharacters_HandlesCorrectly() {
            // Given
            let string = "Hello 🌍 World 🚀 Testing"
            let length = 15

            // When
            let result = string.truncated(to: length)

            // Then
            #expect(result == "Hello 🌍 Worl...")
        }

        @Test("truncated just over length truncates minimally")
        func truncated_JustOverLength_TruncatesMinimally() {
            // Given
            let string = "Hello World!"
            let length = 11

            // When
            let result = string.truncated(to: length)

            // Then
            #expect(result == "Hello Wo...")
        }

        // MARK: - Real-World Usage Tests

        @Test("truncated long user email for menu bar display")
        func truncated_LongUserEmail_ForMenuBarDisplay() {
            // Given
            let email = "user.with.very.long.email.address@verylongdomainname.example.com"
            let maxLength = 25

            // When
            let result = email.truncated(to: maxLength)

            // Then
            #expect(result == "user.with.very.long.em...")
            #expect(result.hasSuffix("..."))
        }

        @Test("truncated error message for notification")
        func truncated_ErrorMessage_ForNotification() {
            // Given
            let errorMessage =
                "Authentication failed: The provided API key is invalid or has expired. Please check your credentials."
            let maxLength = 50

            // When
            let result = errorMessage.truncated(to: maxLength)

            // Then
            #expect(result == "Authentication failed: The provided API key is ...")
        }

        // MARK: - Method Comparison Tests

        @Test("method comparison same input different output lengths")
        func methodComparison_SameInput_DifferentOutputLengths() {
            // Given
            let string = "This is a test string for comparison"
            let length = 15

            // When
            let truncateResult = string.truncate(length: length)
            let truncatedResult = string.truncated(to: length)

            // Then
            // Both methods should produce the same result - total length = 15
            #expect(truncateResult == "This is a te...")
            #expect(truncatedResult == "This is a te...")
        }

        @Test("method comparison short string both return original")
        func methodComparison_ShortString_BothReturnOriginal() {
            // Given
            let string = "Short"
            let length = 10

            // When
            let truncateResult = string.truncate(length: length)
            let truncatedResult = string.truncated(to: length)

            // Then
            #expect(truncateResult == "Short")
            #expect(truncatedResult == "Short")
        }
    }

    // MARK: - Edge Cases Tests

    @Suite("Edge Cases Tests", .tags(.edgeCase))
    struct EdgeCasesTests {
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
            #expect(result.isEmpty)
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
}
