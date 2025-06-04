import CryptoKit
@testable import VibeMeter
import XCTest

@MainActor
final class GravatarServiceEdgeCasesTests: XCTestCase {
    var sut: GravatarService!

    override func setUp() async throws {
        await MainActor.run { super.setUp() }
        sut = GravatarService.shared
        sut.clearAvatar() // Reset state
    }

    override func tearDown() async throws {
        sut.clearAvatar()
        sut = nil
        await MainActor.run { super.tearDown() }
    }

    // MARK: - Edge Cases and Error Handling

    func testGravatarURL_SpecialCharacters_HandlesCorrectly() {
        // Given
        let emailsWithSpecialChars = [
            "user+tag@example.com",
            "user.name@sub.domain.com",
            "user_name@domain-name.co.uk",
            "user@domain.info",
        ]

        for email in emailsWithSpecialChars {
            // When
            let result = sut.gravatarURL(for: email)

            // Then
            XCTAssertNotNil(result, "Should handle special characters in email: \(email)")
            XCTAssertTrue(
                result?.absoluteString.contains("gravatar.com") ?? false,
                "Should generate valid Gravatar URL for: \(email)")
        }
    }

    func testGravatarURL_UnicodeCharacters_HandlesCorrectly() {
        // Given
        let unicodeEmail = "тест@пример.рф" // Cyrillic characters

        // When
        let result = sut.gravatarURL(for: unicodeEmail)

        // Then
        XCTAssertNotNil(result, "Should handle Unicode characters")
        XCTAssertTrue(result?.absoluteString.contains("gravatar.com") ?? false, "Should generate valid Gravatar URL")
    }

    func testGravatarURL_VeryLongEmail_HandlesCorrectly() {
        // Given
        let longEmail = String(repeating: "a", count: 100) + "@" + String(repeating: "b", count: 100) + ".com"

        // When
        let result = sut.gravatarURL(for: longEmail)

        // Then
        XCTAssertNotNil(result, "Should handle very long email addresses")
        XCTAssertTrue(result?.absoluteString.contains("gravatar.com") ?? false, "Should generate valid Gravatar URL")
    }

    func testGravatarURL_ZeroSize_HandlesGracefully() {
        // Given
        let email = "zero@size.com"
        let size = 0

        // When
        let result = sut.gravatarURL(for: email, size: size)

        // Then
        XCTAssertNotNil(result, "Should handle zero size")
        XCTAssertTrue(result?.absoluteString.contains("s=0") ?? false, "Should use size 0 (doubled from 0)")
    }

    func testGravatarURL_NegativeSize_HandlesGracefully() {
        // Given
        let email = "negative@size.com"
        let size = -10

        // When
        let result = sut.gravatarURL(for: email, size: size)

        // Then
        XCTAssertNotNil(result, "Should handle negative size")
        // The actual size handling depends on implementation - just verify it doesn't crash
    }

    func testGravatarURL_LargeSize_HandlesCorrectly() {
        // Given
        let email = "large@size.com"
        let size = 1000
        let expectedRetinaSize = 2000

        // When
        let result = sut.gravatarURL(for: email, size: size)

        // Then
        XCTAssertNotNil(result, "Should handle large size")
        XCTAssertTrue(
            result?.absoluteString.contains("s=\(expectedRetinaSize)") ?? false,
            "Should handle large retina size")
    }

    // MARK: - URL Structure Tests

    func testGravatarURL_URLStructure_IsCorrect() {
        // Given
        let email = "structure@test.com"
        let size = 64

        // When
        let result = sut.gravatarURL(for: email, size: size)

        // Then
        XCTAssertNotNil(result)
        let urlString = result?.absoluteString ?? ""

        // Verify URL components
        XCTAssertTrue(urlString.hasPrefix("https://www.gravatar.com/avatar/"), "Should use HTTPS and correct domain")
        XCTAssertTrue(urlString.contains("?s=128"), "Should include size parameter (doubled)")
        XCTAssertTrue(urlString.contains("&d=mp"), "Should include mystery person fallback")
        XCTAssertTrue(urlString.hasSuffix("d=mp"), "Should end with default parameter")
    }
}
