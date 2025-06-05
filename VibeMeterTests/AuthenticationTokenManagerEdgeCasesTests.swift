import Foundation
@testable import VibeMeter
import Testing

@Suite("AuthenticationTokenManager Edge Cases Tests")
struct AuthenticationTokenManagerEdgeCasesTests {
    private let tokenManager: AuthenticationTokenManager
    private let mockKeychainServices: [ServiceProvider: MockKeychainService]

    init() {
        let services: [ServiceProvider: MockKeychainService] = [:]
        for provider in ServiceProvider.allCases {
            services[provider] = MockKeychainService()
        }
        self.mockKeychainServices = services

        // Create token manager with mock keychain services
        var keychainHelpers: [ServiceProvider: KeychainServicing] = [:]
        for provider in ServiceProvider.allCases {
            keychainHelpers[provider] = services[provider]
        }
        self.tokenManager = AuthenticationTokenManager(keychainHelpers: keychainHelpers)
    }

    // MARK: - Provider Isolation Tests

    @Test("provider isolation")

    func providerIsolation() {
        // Given
        let cursorToken = "cursor-token"
        let cursorProvider = ServiceProvider.cursor

        // When
        let cursorSaved = tokenManager.saveToken(cursorToken, for: cursorProvider)

        // Then
        #expect(cursorSaved == true)
        #expect(tokenManager.getAuthToken(for: cursorProvider) == cursorToken)

        // Other providers should not have this token
        for provider in ServiceProvider.allCases where provider != cursorProvider {
            #expect(tokenManager.getAuthToken(for: provider) == nil)
        }
    }

    // MARK: - Edge Cases

    @Test("save empty token")

    func saveEmptyToken() {
        // Given
        let emptyToken = ""
        let provider = ServiceProvider.cursor

        // When
        let result = tokenManager.saveToken(emptyToken, for: provider)

        // Then
        #expect(result == true)
        #expect(tokenManager.getAuthToken(for: provider == true)
    }

    @Test("save very long token")

    func saveVeryLongToken() {
        // Given
        let longToken = String(repeating: "a", count: 10000)
        let provider = ServiceProvider.cursor

        // When
        let result = tokenManager.saveToken(longToken, for: provider)

        // Then
        #expect(result == true)
        #expect(tokenManager.getAuthToken(for: provider) == longToken)
    }

    @Test("multiple operations on same provider")

    func multipleOperationsOnSameProvider() {
        // Given
        let provider = ServiceProvider.cursor
        let token1 = "first-token"
        let token2 = "second-token"

        // When/Then
        #expect(tokenManager.saveToken(token1, for: provider) == true)
        #expect(tokenManager.getAuthToken(for: provider) == token1)

        // Overwrite with second token
        #expect(tokenManager.saveToken(token2, for: provider) == true)
        #expect(tokenManager.getAuthToken(for: provider) == token2)

        // Delete
        #expect(tokenManager.deleteToken(for: provider) == true)
        #expect(tokenManager.getAuthToken(for: provider) == nil)
    }

    // MARK: - Security Tests

    @Test("tokens are provider specific")

    func tokensAreProviderSpecific() {
        // Given
        let sharedToken = "shared-token-value"

        // When - Save same token value for all providers
        for provider in ServiceProvider.allCases {
            let result = tokenManager.saveToken(sharedToken, for: provider)
            #expect(result == true)
            #expect(tokenManager.getAuthToken(for: provider) == sharedToken)
        }

        // Delete token for one provider
        let testProvider = ServiceProvider.cursor
        #expect(tokenManager.deleteToken(for: testProvider) == true)
        #expect(tokenManager.getAuthToken(for: testProvider) == nil)

        // Other providers should still have their tokens
        for provider in ServiceProvider.allCases where provider != testProvider {
            #expect(tokenManager.getAuthToken(for: provider) == sharedToken)
        }
    }
}

// MARK: - Mock Keychain Service

private final class MockKeychainService: KeychainServicing, @unchecked Sendable {
    var storedToken: String?
    var shouldFailSave = false
    var shouldFailGet = false
    var shouldFailDelete = false

    // Call tracking
    var saveTokenCallCount = 0
    var getTokenCallCount = 0
    var deleteTokenCallCount = 0

    // Last operation tracking
    var lastSavedToken: String?

    func saveToken(_ token: String) -> Bool {
        saveTokenCallCount += 1
        lastSavedToken = token

        if shouldFailSave {
            return false
        }

        storedToken = token
        return true
    }

    func getToken() -> String? {
        getTokenCallCount += 1

        if shouldFailGet {
            return nil
        }

        return storedToken
    }

    func deleteToken() -> Bool {
        deleteTokenCallCount += 1

        if shouldFailDelete {
            return false
        }

        storedToken = nil
        return true
    }
}
