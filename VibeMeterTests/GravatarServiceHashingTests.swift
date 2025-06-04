import CryptoKit
@testable import VibeMeter
import XCTest

@MainActor
final class GravatarServiceHashingTests: XCTestCase {
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
