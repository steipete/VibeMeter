import CryptoKit
@testable import VibeMeter
import XCTest

@MainActor
final class GravatarServiceCoreTests: XCTestCase {
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

    // MARK: - Observable Pattern Tests

    func testGravatarService_IsObservable() {
        // Then
        // GravatarService should be marked with @Observable macro
        // We can verify this by checking if it conforms to Observable protocol
        XCTAssertNotNil(sut as (any Observable)?, "GravatarService should be Observable")
    }

    func testCurrentAvatarURL_IsReadable() {
        // Given
        sut.updateAvatar(for: "observable@test.com")

        // Then
        XCTAssertNotNil(sut.currentAvatarURL, "currentAvatarURL should be publicly readable")
    }
}
