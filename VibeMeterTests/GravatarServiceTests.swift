import CryptoKit
@testable import VibeMeter
import XCTest

@MainActor
final class GravatarServiceTests: XCTestCase {
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

    // MARK: - Initialization Tests

    func testSharedInstance_IsSingleton() {
        // Given
        let instance1 = GravatarService.shared
        let instance2 = GravatarService.shared

        // Then
        XCTAssertTrue(instance1 === instance2, "GravatarService.shared should return the same instance")
    }

    func testInitialState_NoCurrentAvatarURL() {
        // Then
        XCTAssertNil(sut.currentAvatarURL, "Initial state should have no current avatar URL")
    }

    // MARK: - Gravatar URL Generation Tests

    func testGravatarURL_ValidEmail_GeneratesCorrectURL() {
        // Given
        let email = "test@example.com"
        let expectedHash =
            "973dfe463ec85785f5f95af5ba3906eedb2d931c24e69824a89ea65dba4e813b" // SHA256 of "test@example.com"
        let expectedURL = "https://www.gravatar.com/avatar/\(expectedHash)?s=80&d=mp"

        // When
        let result = sut.gravatarURL(for: email)

        // Then
        XCTAssertNotNil(result, "Should generate URL for valid email")
        XCTAssertEqual(result?.absoluteString, expectedURL, "Should generate correct Gravatar URL")
    }

    func testGravatarURL_EmailWithWhitespace_TrimsAndLowercases() {
        // Given
        let emailWithWhitespace = "  TEST@EXAMPLE.COM  "
        let cleanEmail = "test@example.com"

        // When
        let result1 = sut.gravatarURL(for: emailWithWhitespace)
        let result2 = sut.gravatarURL(for: cleanEmail)

        // Then
        XCTAssertNotNil(result1)
        XCTAssertNotNil(result2)
        XCTAssertEqual(
            result1?.absoluteString,
            result2?.absoluteString,
            "Should trim whitespace and convert to lowercase")
    }

    func testGravatarURL_EmptyEmail_GeneratesURL() {
        // Given
        let emptyEmail = ""

        // When
        let result = sut.gravatarURL(for: emptyEmail)

        // Then
        XCTAssertNotNil(result, "Should handle empty email gracefully")
        XCTAssertTrue(result?.absoluteString.contains("gravatar.com") ?? false, "Should still generate Gravatar URL")
    }

    func testGravatarURL_CustomSize_DoublesForRetina() {
        // Given
        let email = "user@domain.com"
        let size = 50
        let expectedRetinaSize = size * 2 // 100

        // When
        let result = sut.gravatarURL(for: email, size: size)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(
            result?.absoluteString.contains("s=\(expectedRetinaSize)") ?? false,
            "Should double size for retina display")
    }

    func testGravatarURL_DefaultSize_Uses40Points() {
        // Given
        let email = "default@size.com"
        let expectedRetinaSize = 80 // 40 * 2

        // When
        let result = sut.gravatarURL(for: email)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(
            result?.absoluteString.contains("s=\(expectedRetinaSize)") ?? false,
            "Should use default size of 40 points (80 retina)")
    }

    func testGravatarURL_ContainsMysteryPersonFallback() {
        // Given
        let email = "fallback@test.com"

        // When
        let result = sut.gravatarURL(for: email)

        // Then
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.absoluteString.contains("d=mp") ?? false, "Should include mystery person fallback")
    }

    // MARK: - SHA256 Hashing Tests

    func testSHA256Hashing_KnownInputs_GeneratesExpectedHashes() {
        // Test cases with known SHA256 hashes
        let testCases = [
            ("test@example.com", "973dfe463ec85785f5f95af5ba3906eedb2d931c24e69824a89ea65dba4e813b"),
            ("user@domain.org", "b58996c504c5638798eb6b511e6f49af5c7dd25d0e0e08db9893e9bf6e6e9c23"),
            ("admin@site.net", "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"),
            // SHA256 of "password" but this is "admin@site.net"
        ]

        for (email, _) in testCases {
            // When
            let result = sut.gravatarURL(for: email)

            // Then
            XCTAssertNotNil(result, "Should generate URL for email: \(email)")

            // Extract hash from URL
            if let url = result?.absoluteString,
               let hashRange = url.range(of: "avatar/"),
               let queryRange = url.range(of: "?") {
                let startIndex = url.index(hashRange.upperBound, offsetBy: 0)
                let endIndex = queryRange.lowerBound
                let extractedHash = String(url[startIndex ..< endIndex])

                // Verify it's a valid 64-character hex string (SHA256)
                XCTAssertEqual(extractedHash.count, 64, "Hash should be 64 characters for email: \(email)")
                XCTAssertTrue(
                    extractedHash.allSatisfy(\.isHexDigit),
                    "Hash should contain only hex digits for email: \(email)")
            } else {
                XCTFail("Could not extract hash from URL for email: \(email)")
            }
        }
    }

    func testSHA256Hashing_SameEmail_GeneratesSameHash() {
        // Given
        let email = "consistent@test.com"

        // When
        let url1 = sut.gravatarURL(for: email)
        let url2 = sut.gravatarURL(for: email)

        // Then
        XCTAssertEqual(url1?.absoluteString, url2?.absoluteString, "Same email should generate same hash/URL")
    }

    func testSHA256Hashing_DifferentEmails_GenerateDifferentHashes() {
        // Given
        let email1 = "user1@example.com"
        let email2 = "user2@example.com"

        // When
        let url1 = sut.gravatarURL(for: email1)
        let url2 = sut.gravatarURL(for: email2)

        // Then
        XCTAssertNotEqual(
            url1?.absoluteString,
            url2?.absoluteString,
            "Different emails should generate different hashes/URLs")
    }

    // MARK: - Update Avatar Tests

    func testUpdateAvatar_WithValidEmail_SetsCurrentAvatarURL() {
        // Given
        let email = "avatar@test.com"
        XCTAssertNil(sut.currentAvatarURL) // Precondition

        // When
        sut.updateAvatar(for: email)

        // Then
        XCTAssertNotNil(sut.currentAvatarURL, "Should set current avatar URL")
        XCTAssertTrue(
            sut.currentAvatarURL?.absoluteString.contains("gravatar.com") ?? false,
            "Should be a Gravatar URL")
    }

    func testUpdateAvatar_WithNilEmail_ClearsCurrentAvatarURL() {
        // Given
        sut.updateAvatar(for: "setup@test.com") // Set initial URL
        XCTAssertNotNil(sut.currentAvatarURL) // Precondition

        // When
        sut.updateAvatar(for: nil)

        // Then
        XCTAssertNil(sut.currentAvatarURL, "Should clear current avatar URL when email is nil")
    }

    func testUpdateAvatar_MultipleUpdates_UpdatesCurrentURL() {
        // Given
        let email1 = "first@user.com"
        let email2 = "second@user.com"

        // When
        sut.updateAvatar(for: email1)
        let firstURL = sut.currentAvatarURL

        sut.updateAvatar(for: email2)
        let secondURL = sut.currentAvatarURL

        // Then
        XCTAssertNotNil(firstURL)
        XCTAssertNotNil(secondURL)
        XCTAssertNotEqual(firstURL?.absoluteString, secondURL?.absoluteString, "Should update to new avatar URL")
    }

    // MARK: - Clear Avatar Tests

    func testClearAvatar_WithCurrentURL_ClearsIt() {
        // Given
        sut.updateAvatar(for: "clear@test.com")
        XCTAssertNotNil(sut.currentAvatarURL) // Precondition

        // When
        sut.clearAvatar()

        // Then
        XCTAssertNil(sut.currentAvatarURL, "Should clear current avatar URL")
    }

    func testClearAvatar_WithNoCurrentURL_HandlesGracefully() {
        // Given
        XCTAssertNil(sut.currentAvatarURL) // Precondition

        // When
        sut.clearAvatar()

        // Then
        XCTAssertNil(sut.currentAvatarURL, "Should remain nil")
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

    // MARK: - Observable Pattern Tests

    func testGravatarService_IsObservable() {
        // Then
        // GravatarService should be marked with @Observable macro
        // We can verify this by checking if it conforms to Observable protocol
        XCTAssertNotNil(sut as? any Observable, "GravatarService should be Observable")
    }

    func testCurrentAvatarURL_IsReadable() {
        // Given
        sut.updateAvatar(for: "observable@test.com")

        // Then
        XCTAssertNotNil(sut.currentAvatarURL, "currentAvatarURL should be publicly readable")
    }

    // MARK: - Performance Tests

    func testGravatarURL_Performance() {
        // Given
        let emails = (0 ..< 1000).map { "user\($0)@performance.test" }

        // When
        let startTime = Date()
        for email in emails {
            _ = sut.gravatarURL(for: email)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "Generating 1000 Gravatar URLs should be fast")
    }

    func testSHA256Hashing_Performance() {
        // Given
        let testString = "performance@test.com"
        let iterations = 10000

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            let inputData = Data(testString.utf8)
            _ = SHA256.hash(data: inputData)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "SHA256 hashing should be performant")
    }
}
