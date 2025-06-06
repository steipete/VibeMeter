import Foundation
import Testing
@testable import VibeMeter

@Suite("AuthenticationTokenManager Cookie Tests", .tags(.authentication, .unit))
struct AuthenticationTokenManagerCookieTests {
    private let tokenManager: AuthenticationTokenManager
    private let mockKeychainServices: [ServiceProvider: MockKeychainService]

    init() {
        var services: [ServiceProvider: MockKeychainService] = [:]
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

    // MARK: - Cookie Generation Tests

    @Test("get cookies success")

    func getCookiesSuccess() {
        // Given
        let token = "auth-token-for-cookies"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        #expect(cookies != nil)

        if let cookie = cookies?.first {
            #expect(cookie.name == provider.authCookieName)
            #expect(cookie.domain == provider.cookieDomain)
            #expect(cookie.isSecure == true)

            // Check expiry is approximately 30 days from now (allowing 1 minute tolerance)
            let expectedExpiry = Date(timeIntervalSinceNow: 3600 * 24 * 30)
            let timeDifference = abs(cookie.expiresDate!.timeIntervalSince(expectedExpiry))
            #expect(timeDifference < 60)
        }
    }

    @Test("get cookies no token")

    func getCookiesNoToken() {
        // Given
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = nil

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        #expect(cookies == nil)
    }

    @Test("get cookies cursor specific")

    func getCookiesCursorSpecific() {
        // Given
        let token = "cursor-specific-token"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        #expect(cookies != nil)
        if let cookie = cookies?.first {
            #expect(cookie.name == "WorkosCursorSessionToken")
            #expect(cookie.domain == ".cursor.com")
        }
    }

    @Test("cookie security properties")

    func cookieSecurityProperties() {
        // Given
        let token = "security-test-token"
        let provider = ServiceProvider.cursor
        mockKeychainServices[provider]?.storedToken = token

        // When
        let cookies = tokenManager.getCookies(for: provider)

        // Then
        #expect(cookies != nil)
        if let cookie = cookies?.first {
            #expect(cookie.isSecure == true) // Should be HTTPS only
            #expect(cookie.path == "/") // Should be domain-wide
            #expect(cookie.expiresDate != nil)
            #expect(cookie.expiresDate! > Date())
            let expectedMaxExpiry = Date(timeIntervalSinceNow: 3600 * 24 * 30 + 3600)
            let expectedMinExpiry = Date(timeIntervalSinceNow: 3600 * 24 * 30 - 3600)
            #expect(cookie.expiresDate! < expectedMaxExpiry)
            #expect(cookie.expiresDate! > expectedMinExpiry)
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
