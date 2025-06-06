import Foundation
import Testing
@testable import VibeMeter

@Suite("AuthenticationTokenManager Core Tests")
struct AuthenticationTokenManagerCoreTests {
    private let tokenManager: AuthenticationTokenManager
    private let mockKeychainServices: [ServiceProvider: MockKeychainService]

    init() {
        var mockServices: [ServiceProvider: MockKeychainService] = [:]
        for provider in ServiceProvider.allCases {
            mockServices[provider] = MockKeychainService()
        }
        self.mockKeychainServices = mockServices

        // Create token manager with mock keychain services
        var keychainHelpers: [ServiceProvider: KeychainServicing] = [:]
        for provider in ServiceProvider.allCases {
            keychainHelpers[provider] = mockServices[provider]
        }
        self.tokenManager = AuthenticationTokenManager(keychainHelpers: keychainHelpers)
    }

    // MARK: - Token Storage Tests

    @Test("save token success")

    func saveTokenSuccess() {
        // Given
        let token = "test-auth-token-123"
        let provider = ServiceProvider.cursor

        // When
        let result = tokenManager.saveToken(token, for: provider)

        // Then
        #expect(result == true)
        #expect(mockKeychainServices[provider]?.lastSavedToken == token)
    }

    @Test("save token failure")

    func saveTokenFailure() {
        // Given
        let token = "test-auth-token-123"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.shouldFailSave = true

        // When
        let result = tokenManager.saveToken(token, for: provider)

        // Then
        #expect(result == false)
    }

    @Test("save token multiple providers")

    func saveTokenMultipleProviders() {
        // Given
        let cursorToken = "cursor-token-123"
        let testProvider = ServiceProvider.cursor

        // When
        let cursorResult = tokenManager.saveToken(cursorToken, for: testProvider)

        // Then
        #expect(cursorResult == true)

        // Verify tokens are isolated per provider - other providers should not have this token
        for provider in ServiceProvider.allCases where provider != testProvider {
            #expect(mockKeychainServices[provider]?.lastSavedToken == nil)
        }
    }

    @Test("get auth token success")

    func getAuthTokenSuccess() {
        // Given
        let token = "stored-auth-token"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let result = tokenManager.getAuthToken(for: provider)

        // Then
        #expect(result == token)
    }

    @Test("get auth token no token")

    func getAuthTokenNoToken() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = nil

        // When
        let result = tokenManager.getAuthToken(for: provider)

        // Then
        #expect(result == nil)
    }

    @Test("get auth token keychain error")

    func getAuthTokenKeychainError() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.shouldFailGet = true

        // When
        let result = tokenManager.getAuthToken(for: provider)

        // Then
        #expect(result == nil)
    }

    // MARK: - Token Deletion Tests

    @Test("delete token success")

    func deleteTokenSuccess() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = "some-token"

        // When
        let result = tokenManager.deleteToken(for: provider)

        // Then
        #expect(result == true)
    }

    @Test("delete token failure")

    func deleteTokenFailure() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.shouldFailDelete = true

        // When
        let result = tokenManager.deleteToken(for: provider)

        // Then
        #expect(result == false)
    }

    // MARK: - Token Existence Tests

    @Test("has token when token exists")

    func hasTokenWhenTokenExists() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = "existing-token"

        // When
        let result = tokenManager.hasToken(for: provider)

        // Then
        #expect(result == true)
    }

    @Test("has token when token does not exist")

    func hasTokenWhenTokenDoesNotExist() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = nil

        // When
        let result = tokenManager.hasToken(for: provider)

        // Then
        #expect(result == false)
    }

    @Test("complete token lifecycle")

    func completeTokenLifecycle() {
        // Given
        let token = "lifecycle-test-token"
        let provider = ServiceProvider.cursor

        // Initially no token
        #expect(tokenManager.hasToken(for: provider) == false)

        // Save token
        let saveResult = tokenManager.saveToken(token, for: provider)
        #expect(saveResult == true)
        #expect(tokenManager.hasToken(for: provider) == true)
        #expect(tokenManager.getAuthToken(for: provider) == token)

        // Cookies should be available
        let cookies = tokenManager.getCookies(for: provider)
        #expect(cookies != nil)

        // Delete token
        let deleteResult = tokenManager.deleteToken(for: provider)
        #expect(deleteResult == true)
        #expect(tokenManager.hasToken(for: provider) == false)
        #expect(tokenManager.getAuthToken(for: provider) == nil)
        #expect(tokenManager.getCookies(for: provider) == nil)
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
