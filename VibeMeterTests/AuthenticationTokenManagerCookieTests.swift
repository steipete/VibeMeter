import Foundation
@testable import VibeMeter
import XCTest

final class AuthenticationTokenManagerCookieTests: XCTestCase {
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
