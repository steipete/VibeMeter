@testable import VibeMeter
import Testing

@Suite("StringExtensionsTruncateTests")
struct StringExtensionsTruncateTests {
    // MARK: - truncate(length:trailing:) Tests

    @Test("truncate  shorter than length  returns original")

    func truncate_ShorterThanLength_ReturnsOriginal() {
        // Given
        let string = "Short"
        let length = 10

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "Short")

    func truncate_ExactLength_ReturnsOriginal() {
        // Given
        let string = "Exact"
        let length = 5

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "Exact")

    func truncate_LongerThanLength_TruncatesWithDefaultTrailing() {
        // Given
        let string = "This is a very long string"
        let length = 10

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "This is a ...") // 10 + 3 for "..."
    }

    @Test("truncate  longer than length  truncates with custom trailing")

    func truncate_LongerThanLength_TruncatesWithCustomTrailing() {
        // Given
        let string = "This is a very long string"
        let length = 10
        let trailing = "—"

        // When
        let result = string.truncate(length: length, trailing: trailing)

        // Then
        #expect(result == "This is a —") // 10 + 1 for "—"
    }

    @Test("truncate  empty string  returns empty")

    func truncate_EmptyString_ReturnsEmpty() {
        // Given
        let string = ""
        let length = 5

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "")

    func truncate_ZeroLength_ReturnsOnlyTrailing() {
        // Given
        let string = "Hello"
        let length = 0

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "...")

    func truncate_SingleCharacter_TruncatesCorrectly() {
        // Given
        let string = "Hello"
        let length = 1

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "H...")

    func truncate_UnicodeCharacters_HandlesCorrectly() {
        // Given
        let string = "Hello 🌍 World 🚀"
        let length = 8

        // When
        let result = string.truncate(length: length)

        // Then
        #expect(result == "Hello 🌍 ...")

    func truncate_EmptyTrailing_WorksCorrectly() {
        // Given
        let string = "Hello World"
        let length = 5
        let trailing = ""

        // When
        let result = string.truncate(length: length, trailing: trailing)

        // Then
        #expect(result == "Hello")

    func truncate_LongTrailing_WorksCorrectly() {
        // Given
        let string = "Hello World"
        let length = 5
        let trailing = " [truncated]"

        // When
        let result = string.truncate(length: length, trailing: trailing)

        // Then
        #expect(result == "Hello [truncated]")

    func truncate_LongUserEmail_ForMenuBarDisplay() {
        // Given
        let email = "user.with.very.long.email.address@verylongdomainname.example.com"
        let maxLength = 25

        // When
        let result = email.truncate(length: maxLength)

        // Then
        #expect(result == "user.with.very.long.email...") // 25 + 3
        #expect(result.hasSuffix("..." == true)

    func truncate_APIEndpointName_ForDisplay() {
        // Given
        let endpoint = "/api/v1/users/123456789/profile/settings/advanced/preferences"
        let maxLength = 30

        // When
        let result = endpoint.truncate(length: maxLength)

        // Then
        #expect(result == "/api/v1/users/123456789/profil...") // 30 + 3
    }
}
