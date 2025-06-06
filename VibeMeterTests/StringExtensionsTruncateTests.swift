import Foundation
import Testing
@testable import VibeMeter

@Suite("String Extensions Truncate Tests")
struct StringExtensionsTruncateTests {
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
        TruncationTestCase("Unicode: 🚀✨🎉 test", length: 12, expected: "Unicode: ...", "unicode with more truncation"),
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
        SpecialCharacterTestCase("Line 1\nLine 2\nLine 3", length: 10, expectedPrefix: "Line 1", "newline characters"),
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
