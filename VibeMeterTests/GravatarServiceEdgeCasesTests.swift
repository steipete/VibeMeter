import CryptoKit
@testable import VibeMeter
import Testing

@Suite("GravatarServiceEdgeCasesTests")
@MainActor
struct GravatarServiceEdgeCasesTests {
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
        #expect(result != nil, "Should generate valid Gravatar URL")
    }

    @Test("gravatar url  very long email  handles correctly")
    func gravatarURL_VeryLongEmail_HandlesCorrectly() {
        // Given
        let longEmail = String(repeating: "a", count: 100) + "@" + String(repeating: "b", count: 100) + ".com"

        // When
        let result = sut.gravatarURL(for: longEmail)

        // Then
        #expect(result != nil, "Should generate valid Gravatar URL")
    }

    @Test("gravatar url  zero size  handles gracefully")
    func gravatarURL_ZeroSize_HandlesGracefully() {
        // Given
        let email = "zero@size.com"
        let size = 0

        // When
        let result = sut.gravatarURL(for: email, size: size)

        // Then
        #expect(result != nil, "Should use size 0 (doubled from 0)")
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
        let expectedRetinaSize = 2000

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
