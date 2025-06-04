import Foundation
@testable import VibeMeter
import XCTest

final class AuthenticationTokenManagerEdgeCasesTests: XCTestCase {
    private var tokenManager: AuthenticationTokenManager!
    private var mockKeychainServices: [ServiceProvider: MockKeychainService] = [:]

    override func setUp() {
        super.setUp()
        setupMockKeychainServices()

        // Create token manager with mock keychain services
        var keychainHelpers: [ServiceProvider: KeychainServicing] = [:]
        for provider in ServiceProvider.allCases {
            keychainHelpers[provider] = mockKeychainServices[provider]
        }
        tokenManager = AuthenticationTokenManager(keychainHelpers: keychainHelpers)
    }

    override func tearDown() {
        tokenManager = nil
        mockKeychainServices.removeAll()
        super.tearDown()
    }

    private func setupMockKeychainServices() {
        for provider in ServiceProvider.allCases {
            mockKeychainServices[provider] = MockKeychainService()
        }
    }

    // MARK: - Provider Isolation Tests

    func testProviderIsolation() {
        // Given
        let cursorToken = "cursor-token"
        let cursorProvider = ServiceProvider.cursor

        // When
        let cursorSaved = tokenManager.saveToken(cursorToken, for: cursorProvider)

        // Then
        XCTAssertTrue(cursorSaved)

        // Verify tokens are isolated
        XCTAssertEqual(tokenManager.getAuthToken(for: cursorProvider), cursorToken)

        // Other providers should not have this token
        for provider in ServiceProvider.allCases where provider != cursorProvider {
            XCTAssertNil(tokenManager.getAuthToken(for: provider))
        }
    }

    // MARK: - Edge Cases

    func testSaveEmptyToken() {
        // Given
        let emptyToken = ""
        let provider = ServiceProvider.cursor

        // When
        let result = tokenManager.saveToken(emptyToken, for: provider)

        // Then
        XCTAssertTrue(result) // Should succeed (empty string is valid)
        XCTAssertEqual(tokenManager.getAuthToken(for: provider), emptyToken)
    }

    func testSaveVeryLongToken() {
        // Given
        let longToken = String(repeating: "a", count: 10000)
        let provider = ServiceProvider.cursor

        // When
        let result = tokenManager.saveToken(longToken, for: provider)

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(tokenManager.getAuthToken(for: provider), longToken)
    }

    func testMultipleOperationsOnSameProvider() {
        // Given
        let provider = ServiceProvider.cursor
        let token1 = "first-token"
        let token2 = "second-token"

        // When/Then
        XCTAssertTrue(tokenManager.saveToken(token1, for: provider))
        XCTAssertEqual(tokenManager.getAuthToken(for: provider), token1)

        // Overwrite with second token
        XCTAssertTrue(tokenManager.saveToken(token2, for: provider))
        XCTAssertEqual(tokenManager.getAuthToken(for: provider), token2)

        // Delete
        XCTAssertTrue(tokenManager.deleteToken(for: provider))
        XCTAssertNil(tokenManager.getAuthToken(for: provider))
    }

    // MARK: - Security Tests

    func testTokensAreProviderSpecific() {
        // Given
        let sharedToken = "shared-token-value"

        // When - Save same token value for all providers
        for provider in ServiceProvider.allCases {
            let result = tokenManager.saveToken(sharedToken, for: provider)
            XCTAssertTrue(result)
        }

        // Then - Each provider should maintain its own token independently
        for provider in ServiceProvider.allCases {
            XCTAssertEqual(tokenManager.getAuthToken(for: provider), sharedToken)
        }

        // Delete token for one provider
        let testProvider = ServiceProvider.cursor
        XCTAssertTrue(tokenManager.deleteToken(for: testProvider))

        // Only that provider should lose its token
        XCTAssertNil(tokenManager.getAuthToken(for: testProvider))

        // Other providers should still have their tokens
        for provider in ServiceProvider.allCases where provider != testProvider {
            XCTAssertEqual(tokenManager.getAuthToken(for: provider), sharedToken)
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
