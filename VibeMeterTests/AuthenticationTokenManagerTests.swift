import Foundation
@testable import VibeMeter
import XCTest

@MainActor
final class AuthenticationTokenManagerTests: XCTestCase {
    private var tokenManager: AuthenticationTokenManager!
    private var mockKeychainServices: [ServiceProvider: MockKeychainService] = [:]

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            setupMockKeychainServices()

            // Create token manager with mock keychain services
            var keychainHelpers: [ServiceProvider: KeychainServicing] = [:]
            for provider in ServiceProvider.allCases {
                keychainHelpers[provider] = mockKeychainServices[provider]
            }
            tokenManager = AuthenticationTokenManager(keychainHelpers: keychainHelpers)
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            tokenManager = nil
            mockKeychainServices.removeAll()
        }
        super.tearDown()
    }

    private func setupMockKeychainServices() {
        for provider in ServiceProvider.allCases {
            mockKeychainServices[provider] = MockKeychainService()
        }
    }

    // MARK: - Token Storage Tests

    func testSaveToken_Success() {
        // Given
        let token = "test-auth-token-123"
        let provider = ServiceProvider.cursor

        // When
        let result = tokenManager.saveToken(token, for: provider)

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockKeychainServices[provider]?.saveTokenCallCount, 1)
        XCTAssertEqual(mockKeychainServices[provider]?.lastSavedToken, token)
    }

    func testSaveToken_Failure() {
        // Given
        let token = "test-auth-token-123"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.shouldFailSave = true

        // When
        let result = tokenManager.saveToken(token, for: provider)

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(mockKeychainServices[provider]?.saveTokenCallCount, 1)
    }

    func testSaveToken_MultipleProviders() {
        // Given
        let cursorToken = "cursor-token-123"
        let testProvider = ServiceProvider.cursor

        // When
        let cursorResult = tokenManager.saveToken(cursorToken, for: testProvider)

        // Then
        XCTAssertTrue(cursorResult)
        XCTAssertEqual(mockKeychainServices[testProvider]?.lastSavedToken, cursorToken)

        // Verify tokens are isolated per provider
        XCTAssertNotEqual(mockKeychainServices[testProvider]?.lastSavedToken, cursorToken)
    }

    // MARK: - Token Retrieval Tests

    func testGetAuthToken_Success() {
        // Given
        let token = "stored-auth-token"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let result = tokenManager.getAuthToken(for: provider)

        // Then
        XCTAssertEqual(result, token)
        XCTAssertEqual(mockKeychainServices[provider]?.getTokenCallCount, 1)
    }

    func testGetAuthToken_NoToken() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = nil

        // When
        let result = tokenManager.getAuthToken(for: provider)

        // Then
        XCTAssertNil(result)
        XCTAssertEqual(mockKeychainServices[provider]?.getTokenCallCount, 1)
    }

    func testGetAuthToken_KeychainError() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.shouldFailGet = true

        // When
        let result = tokenManager.getAuthToken(for: provider)

        // Then
        XCTAssertNil(result)
        XCTAssertEqual(mockKeychainServices[provider]?.getTokenCallCount, 1)
    }

    // MARK: - Token Deletion Tests

    func testDeleteToken_Success() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = "some-token"

        // When
        let result = tokenManager.deleteToken(for: provider)

        // Then
        XCTAssertTrue(result)
        XCTAssertEqual(mockKeychainServices[provider]?.deleteTokenCallCount, 1)
    }

    func testDeleteToken_Failure() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.shouldFailDelete = true

        // When
        let result = tokenManager.deleteToken(for: provider)

        // Then
        XCTAssertFalse(result)
        XCTAssertEqual(mockKeychainServices[provider]?.deleteTokenCallCount, 1)
    }

    // MARK: - Token Existence Tests

    func testHasToken_WhenTokenExists() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = "existing-token"

        // When
        let result = tokenManager.hasToken(for: provider)

        // Then
        XCTAssertTrue(result)
    }

    func testHasToken_WhenTokenDoesNotExist() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = nil

        // When
        let result = tokenManager.hasToken(for: provider)

        // Then
        XCTAssertFalse(result)
    }

    // MARK: - Cookie Generation Tests

    func testGetCookies_Success() {
        // Given
        let token = "auth-token-for-cookies"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        XCTAssertNotNil(cookies)
        XCTAssertEqual(cookies?.count, 1)

        if let cookie = cookies?.first {
            XCTAssertEqual(cookie.name, provider.authCookieName)
            XCTAssertEqual(cookie.value, token)
            XCTAssertEqual(cookie.domain, provider.cookieDomain)
            XCTAssertEqual(cookie.path, "/")
            XCTAssertTrue(cookie.isSecure)
            XCTAssertNotNil(cookie.expiresDate)

            // Check expiry is approximately 30 days from now (allowing 1 minute tolerance)
            let expectedExpiry = Date(timeIntervalSinceNow: 3600 * 24 * 30)
            let timeDifference = abs(cookie.expiresDate!.timeIntervalSince(expectedExpiry))
            XCTAssertLessThan(timeDifference, 60) // Within 1 minute
        }
    }

    func testGetCookies_NoToken() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = nil

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        XCTAssertNil(cookies)
    }

    func testGetCookies_CursorSpecific() {
        // Given
        let token = "cursor-specific-token"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        XCTAssertNotNil(cookies)
        XCTAssertEqual(cookies?.first?.name, "WorkosCursorSessionToken")
        XCTAssertEqual(cookies?.first?.domain, ".cursor.com")
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

    // MARK: - Full Workflow Tests

    func testCompleteTokenLifecycle() {
        // Given
        let token = "lifecycle-test-token"
        let provider = ServiceProvider.cursor

        // Initially no token
        XCTAssertFalse(tokenManager.hasToken(for: provider))
        XCTAssertNil(tokenManager.getAuthToken(for: provider))

        // Save token
        let saveResult = tokenManager.saveToken(token, for: provider)
        XCTAssertTrue(saveResult)

        // Token should now exist
        XCTAssertTrue(tokenManager.hasToken(for: provider))
        XCTAssertEqual(tokenManager.getAuthToken(for: provider), token)

        // Cookies should be available
        let cookies = tokenManager.getCookies(for: provider)
        XCTAssertNotNil(cookies)
        XCTAssertEqual(cookies?.first?.value, token)

        // Delete token
        let deleteResult = tokenManager.deleteToken(for: provider)
        XCTAssertTrue(deleteResult)

        // Token should no longer exist
        XCTAssertFalse(tokenManager.hasToken(for: provider))
        XCTAssertNil(tokenManager.getAuthToken(for: provider))
        XCTAssertNil(tokenManager.getCookies(for: provider))
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

    func testCookieSecurityProperties() {
        // Given
        let token = "security-test-token"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        XCTAssertNotNil(cookies)
        let cookie = cookies!.first!

        // Verify security properties
        XCTAssertTrue(cookie.isSecure) // Should be HTTPS only
        XCTAssertEqual(cookie.path, "/") // Should be site-wide
        XCTAssertTrue(cookie.domain.hasPrefix(".")) // Should be domain-wide
        XCTAssertNotNil(cookie.expiresDate) // Should have expiration

        // Expiration should be in the future (30 days)
        XCTAssertGreaterThan(cookie.expiresDate!, Date())

        // Should expire within reasonable timeframe (30 days ± 1 hour tolerance)
        let expectedMaxExpiry = Date(timeIntervalSinceNow: 3600 * 24 * 30 + 3600)
        let expectedMinExpiry = Date(timeIntervalSinceNow: 3600 * 24 * 30 - 3600)
        XCTAssertLessThan(cookie.expiresDate!, expectedMaxExpiry)
        XCTAssertGreaterThan(cookie.expiresDate!, expectedMinExpiry)
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
