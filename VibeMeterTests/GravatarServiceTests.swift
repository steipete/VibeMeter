// swiftlint:disable file_length nesting
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

        struct EmailTestCase: CustomTestStringConvertible {
            let email: String
            let description: String
            let expectedHash: String?

            init(email: String, description: String, expectedHash: String? = nil) {
                self.email = email
                self.description = description
                self.expectedHash = expectedHash
            }

            var testDescription: String {
                let emailDisplay = email.isEmpty ? "<empty>" : "\"\(email)\""
                return "\(emailDisplay) → \(description)"
            }
        }

        @Test("Email URL generation", arguments: [
            EmailTestCase(
                email: "test@example.com",
                description: "Valid email",
                expectedHash: "973dfe463ec85785f5f95af5ba3906eedb2d931c24e69824a89ea65dba4e813b"),
            EmailTestCase(email: "  TEST@EXAMPLE.COM  ", description: "Email with whitespace and caps"),
            EmailTestCase(email: "", description: "Empty email"),
            EmailTestCase(email: "user@domain.com", description: "Standard email"),
            EmailTestCase(email: "user.name@subdomain.example.com", description: "Email with dots and subdomain"),
        ])
        func gravatarURLGeneration(testCase: EmailTestCase) {
            let result = sut.gravatarURL(for: testCase.email)
            #expect(result != nil)

            // Verify URL structure
            if let url = result {
                #expect(url.absoluteString.contains("gravatar.com/avatar/"))
                #expect(url.absoluteString.contains("?s="))
                #expect(url.absoluteString.contains("&d=mp"))
            }

            // If we have an expected hash, verify it
            if let expectedHash = testCase.expectedHash,
               let url = result?.absoluteString,
               let hashRange = url.range(of: "avatar/"),
               let queryRange = url.range(of: "?") {
                let startIndex = url.index(hashRange.upperBound, offsetBy: 0)
                let endIndex = queryRange.lowerBound
                let extractedHash = String(url[startIndex ..< endIndex])
                #expect(extractedHash == expectedHash)
            }
        }

        struct SizeTestCase {
            let size: Int
            let expectedUrlSize: Int
            let description: String
        }

        @Test("Size handling", arguments: [
            SizeTestCase(size: 50, expectedUrlSize: 100, description: "Custom size doubles for retina"),
            SizeTestCase(size: 40, expectedUrlSize: 80, description: "Default size"),
            SizeTestCase(size: 16, expectedUrlSize: 32, description: "Small icon"),
            SizeTestCase(size: 128, expectedUrlSize: 256, description: "Large avatar"),
        ])
        func gravatarURLSizeHandling(testCase: SizeTestCase) {
            let email = "size@test.com"
            let result = sut.gravatarURL(for: email, size: testCase.size)

            #expect(result != nil)
            if let url = result?.absoluteString {
                #expect(url.contains("s=\(testCase.expectedUrlSize)"))
            }
        }

        @Test("Default size and fallback")
        func defaultSizeAndFallback() {
            let email = "default@test.com"
            let result = sut.gravatarURL(for: email)

            #expect(result != nil)
            if let url = result?.absoluteString {
                #expect(url.contains("s=80")) // Default 40pt doubled for retina
                #expect(url.contains("d=mp")) // Mystery person fallback
            }
        }

        // MARK: - Update Avatar Tests

        struct AvatarUpdateTestCase {
            let email: String?
            let expectURL: Bool
            let description: String
        }

        @Test("Avatar updates", arguments: [
            AvatarUpdateTestCase(email: "avatar@test.com", expectURL: true, description: "Valid email sets URL"),
            AvatarUpdateTestCase(email: nil, expectURL: false, description: "Nil email clears URL"),
            AvatarUpdateTestCase(email: "", expectURL: true, description: "Empty email sets URL"),
        ])
        func updateAvatar(testCase: AvatarUpdateTestCase) {
            // Clear any existing avatar
            sut.clearAvatar()

            // Update avatar
            sut.updateAvatar(for: testCase.email)

            // Verify result
            if testCase.expectURL {
                #expect(sut.currentAvatarURL != nil)
            } else {
                #expect(sut.currentAvatarURL == nil)
            }
        }

        @Test("Sequential avatar updates")
        func sequentialAvatarUpdates() {
            let emails = ["first@user.com", "second@user.com", "third@user.com"]
            var urls: [URL?] = []

            for email in emails {
                sut.updateAvatar(for: email)
                urls.append(sut.currentAvatarURL)
            }

            // All should be non-nil and different
            #expect(urls.allSatisfy { $0 != nil })
            #expect(Set(urls.compactMap { $0?.absoluteString }).count == emails.count)
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

        @Test("Special character emails", arguments: [
            "user+tag@example.com",
            "user.name@sub.domain.com",
            "user_name@domain-name.co.uk",
            "user@domain.info",
            "test.email+tag@subdomain.example.com",
        ])
        func specialCharacterEmails(email: String) {
            let result = sut.gravatarURL(for: email)

            #expect(result != nil)
            #expect(result?.absoluteString.contains("gravatar.com") ?? false)
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

        @Test("Edge case sizes", arguments: [
            (0, "Zero size"),
            (-10, "Negative size"),
            (1000, "Very large size"),
            (Int.max, "Maximum integer size")
        ])
        func edgeCaseSizes(size: Int, description _: String) {
            let email = "edge@case.com"
            let result = sut.gravatarURL(for: email, size: size)

            #expect(result != nil)
            // Even with edge case sizes, URL should still be valid
            if let url = result?.absoluteString {
                #expect(url.contains("gravatar.com"))
                #expect(url.contains("?s="))
            }
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

        struct HashTestCase {
            let email: String
            let expectedHashPrefix: String
            let description: String
        }

        @Test("SHA256 hash validation", arguments: [
            HashTestCase(email: "test@example.com", expectedHashPrefix: "973dfe46", description: "Known hash 1"),
            HashTestCase(email: "user@domain.org", expectedHashPrefix: "b58996c5", description: "Known hash 2"),
            HashTestCase(email: "admin@site.net", expectedHashPrefix: "5e884898", description: "Known hash 3"),
        ])
        func sha256HashValidation(testCase: HashTestCase) {
            let result = sut.gravatarURL(for: testCase.email)
            #expect(result != nil)

            // Extract and validate hash
            if let url = result?.absoluteString,
               let hashRange = url.range(of: "avatar/"),
               let queryRange = url.range(of: "?") {
                let startIndex = url.index(hashRange.upperBound, offsetBy: 0)
                let endIndex = queryRange.lowerBound
                let extractedHash = String(url[startIndex ..< endIndex])

                // Verify hash properties
                #expect(extractedHash.count == 64) // SHA256 is 64 hex chars
                #expect(extractedHash.allSatisfy { $0.isHexDigit })
                #expect(extractedHash.hasPrefix(testCase.expectedHashPrefix))
            } else {
                Issue.record("Could not extract hash from URL")
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
