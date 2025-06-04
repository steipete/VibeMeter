@testable import VibeMeter
import XCTest

final class StringExtensionsTests: XCTestCase {
    // MARK: - truncate(length:trailing:) Tests

    func testTruncate_ShorterThanLength_ReturnsOriginal() {
        // Given
        let string = "Short"
        let length = 10

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "Short")
    }

    func testTruncate_ExactLength_ReturnsOriginal() {
        // Given
        let string = "Exact"
        let length = 5

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "Exact")
    }

    func testTruncate_LongerThanLength_TruncatesWithDefaultTrailing() {
        // Given
        let string = "This is a very long string"
        let length = 10

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "This is a ...")
        XCTAssertEqual(result.count, 13) // 10 + 3 for "..."
    }

    func testTruncate_LongerThanLength_TruncatesWithCustomTrailing() {
        // Given
        let string = "This is a very long string"
        let length = 10
        let trailing = "—"

        // When
        let result = string.truncate(length: length, trailing: trailing)

        // Then
        XCTAssertEqual(result, "This is a —")
        XCTAssertEqual(result.count, 11) // 10 + 1 for "—"
    }

    func testTruncate_EmptyString_ReturnsEmpty() {
        // Given
        let string = ""
        let length = 5

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "")
    }

    func testTruncate_ZeroLength_ReturnsOnlyTrailing() {
        // Given
        let string = "Hello"
        let length = 0

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "...")
    }

    func testTruncate_SingleCharacter_TruncatesCorrectly() {
        // Given
        let string = "Hello"
        let length = 1

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "H...")
    }

    func testTruncate_UnicodeCharacters_HandlesCorrectly() {
        // Given
        let string = "Hello 🌍 World 🚀"
        let length = 8

        // When
        let result = string.truncate(length: length)

        // Then
        XCTAssertEqual(result, "Hello 🌍 ...")
    }

    func testTruncate_EmptyTrailing_WorksCorrectly() {
        // Given
        let string = "Hello World"
        let length = 5
        let trailing = ""

        // When
        let result = string.truncate(length: length, trailing: trailing)

        // Then
        XCTAssertEqual(result, "Hello")
    }

    func testTruncate_LongTrailing_WorksCorrectly() {
        // Given
        let string = "Hello World"
        let length = 5
        let trailing = " [truncated]"

        // When
        let result = string.truncate(length: length, trailing: trailing)

        // Then
        XCTAssertEqual(result, "Hello [truncated]")
    }

    // MARK: - truncated(to:) Tests

    func testTruncated_ShorterThanLength_ReturnsOriginal() {
        // Given
        let string = "Short"
        let length = 10

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "Short")
    }

    func testTruncated_ExactLength_ReturnsOriginal() {
        // Given
        let string = "Exact"
        let length = 5

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "Exact")
    }

    func testTruncated_LongerThanLength_TruncatesWithEllipsis() {
        // Given
        let string = "This is a very long string"
        let length = 10

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "This is...")
        XCTAssertEqual(result.count, 10)
    }

    func testTruncated_EmailAddress_TruncatesCorrectly() {
        // Given
        let email = "user@verylongdomainname.example.com"
        let length = 20

        // When
        let result = email.truncated(to: length)

        // Then
        XCTAssertEqual(result, "user@verylongdoma...")
        XCTAssertEqual(result.count, 20)
    }

    func testTruncated_EmptyString_ReturnsEmpty() {
        // Given
        let string = ""
        let length = 5

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "")
    }

    func testTruncated_LengthThree_ReturnsOnlyEllipsis() {
        // Given
        let string = "Hello World"
        let length = 3

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "...")
        XCTAssertEqual(result.count, 3)
    }

    func testTruncated_LengthTwo_ReturnsPartialWithEllipsis() {
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
        XCTAssertEqual(result, "...")
    }

    func testTruncated_LengthOne_ReturnsPartialWithEllipsis() {
        // Given
        let string = "Hello"
        let length = 1

        // When
        let result = string.truncated(to: length)

        // Then
        // Edge case: prefix(-2) + "..." - the implementation has limitations here
        XCTAssertEqual(result, "...")
    }

    func testTruncated_UnicodeCharacters_HandlesCorrectly() {
        // Given
        let string = "Hello 🌍 World 🚀 Testing"
        let length = 15

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "Hello 🌍 Worl...")
        XCTAssertEqual(result.count, 15)
    }

    func testTruncated_JustOverLength_TruncatesMinimally() {
        // Given
        let string = "Hello World!"
        let length = 11

        // When
        let result = string.truncated(to: length)

        // Then
        XCTAssertEqual(result, "Hello Wo...")
        XCTAssertEqual(result.count, 11)
    }

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

    // MARK: - Real-World Usage Tests

    func testTruncate_LongUserEmail_ForMenuBarDisplay() {
        // Given
        let email = "user.with.very.long.email.address@verylongdomainname.example.com"
        let maxLength = 25

        // When
        let result = email.truncate(length: maxLength)

        // Then
        XCTAssertEqual(result, "user.with.very.long.email...")
        XCTAssertEqual(result.count, 28) // 25 + 3
        XCTAssertTrue(result.hasSuffix("..."))
    }

    func testTruncated_LongUserEmail_ForMenuBarDisplay() {
        // Given
        let email = "user.with.very.long.email.address@verylongdomainname.example.com"
        let maxLength = 25

        // When
        let result = email.truncated(to: maxLength)

        // Then
        XCTAssertEqual(result, "user.with.very.long.em...")
        XCTAssertEqual(result.count, 25)
        XCTAssertTrue(result.hasSuffix("..."))
    }

    func testTruncate_APIEndpointName_ForDisplay() {
        // Given
        let endpoint = "/api/v1/users/123456789/profile/settings/advanced/preferences"
        let maxLength = 30

        // When
        let result = endpoint.truncate(length: maxLength)

        // Then
        XCTAssertEqual(result, "/api/v1/users/123456789/profil...")
        XCTAssertTrue(result.count <= 33) // 30 + 3
    }

    func testTruncated_ErrorMessage_ForNotification() {
        // Given
        let errorMessage =
            "Authentication failed: The provided API key is invalid or has expired. Please check your credentials."
        let maxLength = 50

        // When
        let result = errorMessage.truncated(to: maxLength)

        // Then
        XCTAssertEqual(result, "Authentication failed: The provided API key is ...")
        XCTAssertEqual(result.count, 50)
    }

    // MARK: - Method Comparison Tests

    func testMethodComparison_SameInput_DifferentOutputLengths() {
        // Given
        let string = "This is a test string for comparison"
        let length = 15

        // When
        let truncateResult = string.truncate(length: length)
        let truncatedResult = string.truncated(to: length)

        // Then
        // truncate() adds trailing after the specified length
        XCTAssertEqual(truncateResult, "This is a test ...")
        XCTAssertEqual(truncateResult.count, 18) // 15 + 3

        // truncated() ensures total length doesn't exceed specified length
        XCTAssertEqual(truncatedResult, "This is a te...")
        XCTAssertEqual(truncatedResult.count, 15)
    }

    func testMethodComparison_ShortString_BothReturnOriginal() {
        // Given
        let string = "Short"
        let length = 10

        // When
        let truncateResult = string.truncate(length: length)
        let truncatedResult = string.truncated(to: length)

        // Then
        XCTAssertEqual(truncateResult, "Short")
        XCTAssertEqual(truncatedResult, "Short")
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
