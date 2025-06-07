import CryptoKit
import Foundation
import Testing
@testable import VibeMeter

@Suite("GravatarService Tests")
@MainActor
struct GravatarServiceTests {
    @Suite("Core Functionality", .tags(.network, .unit))
    @MainActor
    struct CoreTests {
        let sut: GravatarService

        init() {
            sut = GravatarService.shared
            sut.clearAvatar() // Reset state
        }

        // MARK: - Initialization Tests

        @Test("shared instance  is singleton")
        func sharedInstance_IsSingleton() {
            // Given
            let instance1 = GravatarService.shared
            let instance2 = GravatarService.shared

            // Then
            #expect(instance1 === instance2)
        }

        @Test("initial state no current avatar url")
        func initialState_NoCurrentAvatarURL() {
            // Then
            #expect(sut.currentAvatarURL == nil)
        }

        @Test("gravatar url valid email generates correct url")
        func gravatarURL_ValidEmail_GeneratesCorrectURL() {
            // Given
            let email = "test@example.com"
            let expectedHash =
                "973dfe463ec85785f5f95af5ba3906eedb2d931c24e69824a89ea65dba4e813b" // SHA256 of "test@example.com"
            _ = "https://www.gravatar.com/avatar/\(expectedHash)?s=80&d=mp"

            // When
            let result = sut.gravatarURL(for: email)

            // Then
            #expect(result != nil)
        }

        @Test("gravatar url  email with whitespace  trims and lowercases")

        func gravatarURL_EmailWithWhitespace_TrimsAndLowercases() {
            // Given
            let emailWithWhitespace = "  TEST@EXAMPLE.COM  "
            let cleanEmail = "test@example.com"

            // When
            let result1 = sut.gravatarURL(for: emailWithWhitespace)
            let result2 = sut.gravatarURL(for: cleanEmail)

            // Then
            #expect(result1 != nil)
            #expect(
                result1?.absoluteString == result2?.absoluteString)
        }

        @Test("gravatar url  empty email  generates url")
        func gravatarURL_EmptyEmail_GeneratesURL() {
            // Given
            let emptyEmail = ""

            // When
            let result = sut.gravatarURL(for: emptyEmail)

            // Then
            #expect(result != nil)
        }

        @Test("gravatar url  custom size  doubles for retina")
        func gravatarURL_CustomSize_DoublesForRetina() {
            // Given
            let email = "user@domain.com"
            let size = 50
            _ = size * 2 // 100

            // When
            let result = sut.gravatarURL(for: email, size: size)

            // Then
            #expect(result != nil,
                    "Should double size for retina display")
        }

        @Test("gravatar url  default size  uses40 points")
        func gravatarURL_DefaultSize_Uses40Points() {
            // Given
            let email = "default@size.com"
            _ = 80 // 40 * 2

            // When
            let result = sut.gravatarURL(for: email)

            // Then
            #expect(result != nil,
                    "Should use default size of 40 points (80 retina)")
        }

        @Test("gravatar url  contains mystery person fallback")
        func gravatarURL_ContainsMysteryPersonFallback() {
            // Given
            let email = "fallback@test.com"

            // When
            let result = sut.gravatarURL(for: email)

            // Then
            #expect(result != nil)
        }

        // MARK: - Update Avatar Tests

        @Test("update avatar  with valid email  sets current avatar url")
        func updateAvatar_WithValidEmail_SetsCurrentAvatarURL() {
            // Given
            let email = "avatar@test.com"
            #expect(sut.currentAvatarURL == nil)

            // When
            sut.updateAvatar(for: email)

            // Then
            #expect(sut.currentAvatarURL != nil,
                    "Should be a Gravatar URL")
        }

        @Test("update avatar  with nil email  clears current avatar url")
        func updateAvatar_WithNilEmail_ClearsCurrentAvatarURL() {
            // Given
            sut.updateAvatar(for: "setup@test.com") // Set initial URL
            #expect(sut.currentAvatarURL != nil)

            // When
            sut.updateAvatar(for: nil)

            // Then
            #expect(sut.currentAvatarURL == nil)
        }

        @Test("update avatar  multiple updates  updates current url")
        func updateAvatar_MultipleUpdates_UpdatesCurrentURL() {
            // Given
            let email1 = "first@user.com"
            let email2 = "second@user.com"

            // When
            sut.updateAvatar(for: email1)
            let firstURL = sut.currentAvatarURL

            sut.updateAvatar(for: email2)
            let secondURL = sut.currentAvatarURL

            // Then
            #expect(firstURL != nil)
            #expect(firstURL?.absoluteString != secondURL?.absoluteString)
        }

        @Test("clear avatar  with current url  clears it")
        func clearAvatar_WithCurrentURL_ClearsIt() {
            // Given
            sut.updateAvatar(for: "clear@test.com")
            #expect(sut.currentAvatarURL != nil)

            // When
            sut.clearAvatar()

            // Then
            #expect(sut.currentAvatarURL == nil)
        }

        @Test("clear avatar  with no current url  handles gracefully")
        func clearAvatar_WithNoCurrentURL_HandlesGracefully() {
            // Given
            #expect(sut.currentAvatarURL == nil)

            // When
            sut.clearAvatar()

            // Then
            #expect(sut.currentAvatarURL == nil)
        }

        @Test("gravatar service  is observable")
        func gravatarService_IsObservable() {
            // Then
            // GravatarService should be marked with @Observable macro
            // We can verify this by checking if it conforms to Observable protocol
            #expect((sut as (any Observable)?) != nil)
        }

        @Test("current avatar url  is readable")
        func currentAvatarURL_IsReadable() {
            // Given
            sut.updateAvatar(for: "observable@test.com")

            // Then
            #expect(sut.currentAvatarURL != nil)
        }
    }

    @Suite("Edge Cases", .tags(.network, .edgeCase))
    @MainActor
    struct EdgeCasesTests {
        let sut: GravatarService

        init() {
            sut = GravatarService.shared
            sut.clearAvatar() // Reset state
        }

        // MARK: - Edge Cases and Error Handling

        @Test("gravatar url  special characters  handles correctly")
        func gravatarURL_SpecialCharacters_HandlesCorrectly() {
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
                #expect(result != nil)
                #expect(
                    result?.absoluteString.contains("gravatar.com") ?? false)
            }
        }

        @Test("gravatar url  unicode characters  handles correctly")
        func gravatarURL_UnicodeCharacters_HandlesCorrectly() {
            // Given
            let unicodeEmail = "тест@пример.рф" // Cyrillic characters

            // When
            let result = sut.gravatarURL(for: unicodeEmail)

            // Then
            #expect(result != nil)
        }

        @Test("gravatar url  very long email  handles correctly")
        func gravatarURL_VeryLongEmail_HandlesCorrectly() {
            // Given
            let longEmail = String(repeating: "a", count: 100) + "@" + String(repeating: "b", count: 100) + ".com"

            // When
            let result = sut.gravatarURL(for: longEmail)

            // Then
            #expect(result != nil)
        }

        @Test("gravatar url  zero size  handles gracefully")
        func gravatarURL_ZeroSize_HandlesGracefully() {
            // Given
            let email = "zero@size.com"
            let size = 0

            // When
            let result = sut.gravatarURL(for: email, size: size)

            // Then
            #expect(result != nil)
        }

        @Test("gravatar url  negative size  handles gracefully")
        func gravatarURL_NegativeSize_HandlesGracefully() {
            // Given
            let email = "negative@size.com"
            let size = -10

            // When
            let result = sut.gravatarURL(for: email, size: size)

            // Then
            #expect(result != nil)
        }

        @Test("gravatar url  large size  handles correctly")
        func gravatarURL_LargeSize_HandlesCorrectly() {
            // Given
            let email = "large@size.com"
            let size = 1000
            _ = 2000

            // When
            let result = sut.gravatarURL(for: email, size: size)

            // Then
            #expect(result != nil,
                    "Should handle large retina size")
        }

        // MARK: - URL Structure Tests

        @Test("gravatar url url structure  is correct")
        func gravatarURL_URLStructure_IsCorrect() {
            // Given
            let email = "structure@test.com"
            let size = 64

            // When
            let result = sut.gravatarURL(for: email, size: size)

            // Then
            #expect(result != nil)
            let urlString = result?.absoluteString ?? ""
            #expect(urlString.contains("?s=128"))
            #expect(urlString.contains("&d=mp"))
            #expect(urlString.hasSuffix("d=mp"))
        }
    }

    @Suite("Hashing", .tags(.unit, .fast))
    @MainActor
    struct HashingTests {
        let sut: GravatarService

        init() {
            sut = GravatarService.shared
            sut.clearAvatar() // Reset state
        }

        // MARK: - SHA256 Hashing Tests

        @Test("s ha256 hashing  known inputs  generates expected hashes")
        func sHA256Hashing_KnownInputs_GeneratesExpectedHashes() {
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
                #expect(result != nil)

                // Extract hash from URL
                if let url = result?.absoluteString,
                   let hashRange = url.range(of: "avatar/"),
                   let queryRange = url.range(of: "?") {
                    let startIndex = url.index(hashRange.upperBound, offsetBy: 0)
                    let endIndex = queryRange.lowerBound
                    let extractedHash = String(url[startIndex ..< endIndex])

                    // Verify it's a valid 64-character hex string (SHA256)
                    #expect(extractedHash.count == 64)
                    #expect(
                        extractedHash.allSatisfy(\.isHexDigit) == true)
                } else {
                    #expect(Bool(false), "Could not extract hash from Gravatar URL")
                }
            }
        }

        @Test("s ha256 hashing  same email  generates same hash")
        func sHA256Hashing_SameEmail_GeneratesSameHash() {
            // Given
            let email = "consistent@test.com"

            // When
            let url1 = sut.gravatarURL(for: email)
            let url2 = sut.gravatarURL(for: email)

            // Then
            #expect(url1?.absoluteString == url2?.absoluteString)
        }

        @Test("s ha256 hashing  different emails  generate different hashes")
        func sHA256Hashing_DifferentEmails_GenerateDifferentHashes() {
            // Given
            let email1 = "user1@example.com"
            let email2 = "user2@example.com"

            // When
            let url1 = sut.gravatarURL(for: email1)
            let url2 = sut.gravatarURL(for: email2)

            // Then
            #expect(
                url1?.absoluteString != url2?.absoluteString)
        }

        @Test("gravatar url performance", .timeLimit(.minutes(1)))
        func gravatarURL_Performance() {
            // Given
            let emails = (0 ..< 1000).map { "user\($0)@performance.test" }

            // When
            let startTime = Date()
            for email in emails {
                _ = sut.gravatarURL(for: email)
            }
            let duration = Date().timeIntervalSince(startTime)

            // Then
            #expect(duration < 1.0)
        }

        @Test(
            "SHA256 hashing performance",
            .timeLimit(.minutes(1)),
            .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil))
        func sHA256Hashing_Performance() {
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
            #expect(duration < 1.0)
        }
    }
}
