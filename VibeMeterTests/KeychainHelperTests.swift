@testable import VibeMeter
import Testing

@Suite("KeychainHelperTests")
struct KeychainHelperTests {
    let sut: KeychainHelper
    // MARK: - Token Storage Tests

    @Test("save token  with valid token  returns true")

    func saveToken_WithValidToken_ReturnsTrue() {
        // When
        let result = sut.saveToken("test-token-123")

        // Then
        #expect(result == true)

    func getToken_AfterSaving_ReturnsStoredToken() {
        // Given
        let testToken = "test-token-value-456"
        _ = sut.saveToken(testToken)

        // When
        let retrievedToken = sut.getToken()

        // Then
        #expect(retrievedToken == testToken)

    func getToken_WithoutSaving_ReturnsNil() {
        // When
        let token = sut.getToken()

        // Then
        #expect(token == nil)

    func deleteToken_AfterSaving_RemovesToken() {
        // Given
        _ = sut.saveToken("token-to-delete")

        // When
        let deleteResult = sut.deleteToken()
        let retrievedToken = sut.getToken()

        // Then
        #expect(deleteResult == true)
    }

    @Test("delete token  without saving  returns true")

    func deleteToken_WithoutSaving_ReturnsTrue() {
        // When
        let result = sut.deleteToken()

        // Then
        #expect(result == true)

    func saveToken_OverwritesExistingToken() {
        // Given
        _ = sut.saveToken("old-token")

        // When
        _ = sut.saveToken("new-token")
        let retrievedToken = sut.getToken()

        // Then
        #expect(retrievedToken == "new-token")

    func multipleUpdates_PreservesLatestToken() {
        // Given
        let tokens = ["token1", "token2", "token3", "final-token"]

        // When
        for token in tokens {
            _ = sut.saveToken(token)
        }
        let retrievedToken = sut.getToken()

        // Then
        #expect(retrievedToken == "final-token")

    func differentServices_HaveIsolatedStorage() {
        // Given
        let service1 = KeychainHelper(service: "com.test.service1")
        let service2 = KeychainHelper(service: "com.test.service2")

        // When
        _ = service1.saveToken("token-for-service1")
        _ = service2.saveToken("token-for-service2")

        let token1 = service1.getToken()
        let token2 = service2.getToken()

        // Then
        #expect(token1 == "token-for-service1")

        // Cleanup
        _ = service1.deleteToken()
        _ = service2.deleteToken()
    }

    @Test("delete token  does not affect other services")

    func deleteToken_DoesNotAffectOtherServices() {
        // Given
        let service1 = KeychainHelper(service: "com.test.service3")
        let service2 = KeychainHelper(service: "com.test.service4")
        _ = service1.saveToken("token1")
        _ = service2.saveToken("token2")

        // When
        _ = service1.deleteToken()

        // Then
        #expect(service1.getToken( == nil) == "token2")

        // Cleanup
        _ = service2.deleteToken()
    }

    // MARK: - Edge Cases

    @Test("save token  with empty string  stores successfully")

    func saveToken_WithEmptyString_StoresSuccessfully() {
        // When
        let result = sut.saveToken("")
        let retrievedToken = sut.getToken()

        // Then
        #expect(result == true)
    }

    @Test("save token  with very long token  stores successfully")

    func saveToken_WithVeryLongToken_StoresSuccessfully() {
        // Given
        let longToken = String(repeating: "a", count: 10000)

        // When
        let result = sut.saveToken(longToken)
        let retrievedToken = sut.getToken()

        // Then
        #expect(result == true)
    }

    @Test("save token  with special characters  stores successfully")

    func saveToken_WithSpecialCharacters_StoresSuccessfully() {
        // Given
        let specialToken = "!@#$%^&*()_+-=[]{}|;':\",./<>?"

        // When
        let result = sut.saveToken(specialToken)
        let retrievedToken = sut.getToken()

        // Then
        #expect(result == true)
    }

    @Test("save token  with unicode characters  stores successfully")

    func saveToken_WithUnicodeCharacters_StoresSuccessfully() {
        // Given
        let unicodeToken = "🔑Token-with-emoji-🚀-and-中文"

        // When
        let result = sut.saveToken(unicodeToken)
        let retrievedToken = sut.getToken()

        // Then
        #expect(result == true)
    }

    // MARK: - Concurrent Access Tests

    @Test("concurrent access  maintains data integrity")

    func concurrentAccess_MaintainsDataIntegrity() {
        // Given
        let expectation = expectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 100
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        // When
        for i in 0 ..< 100 {
            queue.async {
                let token = "token-\(i)"
                _ = self.sut.saveToken(token)
                _ = self.sut.getToken()
                if i % 2 == 0 {
                    _ = self.sut.deleteToken()
                }
                expectation.fulfill()
            }
        }

        // Then
        wait(for: [expectation], timeout: 5.0)
        // Test passes if no crashes occur during concurrent access
    }

    // MARK: - Shared Instance Tests

    @Test("shared instance  uses correct service")

    func sharedInstance_UsesCorrectService() {
        // Given
        let shared = KeychainHelper.shared

        // When
        _ = shared.saveToken("shared-token")
        let token = shared.getToken()

        // Then
        #expect(token == "shared-token")
    }

    // MARK: - Protocol Conformance Tests

    @Test("keychain helper  conforms to keychain servicing")

    func keychainHelper_ConformsToKeychainServicing() {
        // Then
        #expect((sut as Any == true)
    }

    @Test("keychain helper  is sendable")

    func keychainHelper_IsSendable() {
        // Given
        let helper = KeychainHelper(service: "test.sendable")

        // When/Then - This compiles because KeychainHelper is Sendable
        Task {
            _ = helper.saveToken("sendable-test")
        }
    }

    // MARK: - Debug Storage Tests (when in DEBUG mode)

    #if DEBUG
        @Test("debug storage  persists across instances")

        func debugStorage_PersistsAcrossInstances() {
            // Given
            let service = "com.test.debug.persistence"
            let helper1 = KeychainHelper(service: service)
            _ = helper1.saveToken("persisted-token")

            // When
            let helper2 = KeychainHelper(service: service)
            let token = helper2.getToken()

            // Then
            #expect(token == "persisted-token")
        }
    #endif
}
}
