@testable import VibeMeter
import XCTest

final class StringExtensionsTruncateTests: XCTestCase {
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
}
