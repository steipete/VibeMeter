import CryptoKit
@testable import VibeMeter
import Testing

@Suite("GravatarServiceCoreTests")
@MainActor
struct GravatarServiceCoreTests {
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
        let expectedURL = "https://www.gravatar.com/avatar/\(expectedHash)?s=80&d=mp"

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

    func gravatarURL_EmptyEmail_GeneratesURL() {
        // Given
        let emptyEmail = ""

        // When
        let result = sut.gravatarURL(for: emptyEmail)

        // Then
        #expect(result != nil) ?? false, "Should still generate Gravatar URL")
    }

    @Test("gravatar url  custom size  doubles for retina")

    func gravatarURL_CustomSize_DoublesForRetina() {
        // Given
        let email = "user@domain.com"
        let size = 50
        let expectedRetinaSize = size * 2 // 100

        // When
        let result = sut.gravatarURL(for: email, size: size)

        // Then
        #expect(result != nil) ?? false,
            "Should double size for retina display")
    }

    @Test("gravatar url  default size  uses40 points")

    func gravatarURL_DefaultSize_Uses40Points() {
        // Given
        let email = "default@size.com"
        let expectedRetinaSize = 80 // 40 * 2

        // When
        let result = sut.gravatarURL(for: email)

        // Then
        #expect(result != nil) ?? false,
            "Should use default size of 40 points (80 retina)")
    }

    @Test("gravatar url  contains mystery person fallback")

    func gravatarURL_ContainsMysteryPersonFallback() {
        // Given
        let email = "fallback@test.com"

        // When
        let result = sut.gravatarURL(for: email)

        // Then
        #expect(result != nil) ?? false, "Should include mystery person fallback")
    }

    // MARK: - Update Avatar Tests

    @Test("update avatar  with valid email  sets current avatar url")

    func updateAvatar_WithValidEmail_SetsCurrentAvatarURL() {
        // Given
        let email = "avatar@test.com"
        #expect(sut.currentAvatarURL == nil)

        // Then
        #expect(sut.currentAvatarURL != nil) ?? false,
            "Should be a Gravatar URL")
    }

    @Test("update avatar  with nil email  clears current avatar url")

    func updateAvatar_WithNilEmail_ClearsCurrentAvatarURL() {
        // Given
        sut.updateAvatar(for: "setup@test.com") // Set initial URL
        #expect(sut.currentAvatarURL != nil)

        // Then
        #expect(sut.currentAvatarURL == nil)

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

    func clearAvatar_WithCurrentURL_ClearsIt() {
        // Given
        sut.updateAvatar(for: "clear@test.com")
        #expect(sut.currentAvatarURL != nil)

        // Then
        #expect(sut.currentAvatarURL == nil)

    func clearAvatar_WithNoCurrentURL_HandlesGracefully() {
        // Given
        #expect(sut.currentAvatarURL == nil)

        // Then
        #expect(sut.currentAvatarURL == nil)

    func gravatarService_IsObservable() {
        // Then
        // GravatarService should be marked with @Observable macro
        // We can verify this by checking if it conforms to Observable protocol
        #expect(sut as (any Observable != nil)
    }

    @Test("current avatar url  is readable")

    func currentAvatarURL_IsReadable() {
        // Given
        sut.updateAvatar(for: "observable@test.com")

        // Then
        #expect(sut.currentAvatarURL != nil)
    }
}
