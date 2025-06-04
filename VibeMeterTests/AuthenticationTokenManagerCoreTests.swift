import Foundation
@testable import VibeMeter
import XCTest

final class AuthenticationTokenManagerCoreTests: XCTestCase {
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

        // Verify tokens are isolated per provider - other providers should not have this token
        for provider in ServiceProvider.allCases where provider != testProvider {
            XCTAssertNil(mockKeychainServices[provider]?.lastSavedToken)
        }
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
