import Foundation
import Testing
@testable import VibeMeter

// MARK: - Authentication Token Manager Tests

@Suite("Authentication Token Manager Tests", .tags(.authentication, .unit))
@MainActor
struct AuthenticationTokenManagerTests {
    
    // MARK: - Core Functionality
    
    @Suite("Core Functionality", .tags(.fast))
    struct Core {
        private let tokenManager: AuthenticationTokenManager
        private let mockKeychainServices: [ServiceProvider: KeychainServiceMock]

        init() {
            var mockServices: [ServiceProvider: KeychainServiceMock] = [:]
            for provider in ServiceProvider.allCases {
                mockServices[provider] = KeychainServiceMock()
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

        @Test("save token success", .tags(.critical, .requiresKeychain))
        func saveTokenSuccess() {
            // Given
            let token = "test-auth-token-123"
            let provider = ServiceProvider.cursor

            // When
            let result = tokenManager.saveToken(token, for: provider)

            // Then
            #expect(result == true)
            // Verify token was saved (mock doesn't expose lastSavedToken, but save was called)
            #expect(mockKeychainServices[provider]?.saveTokenCalled == true)
        }

        @Test("save token failure")
        func saveTokenFailure() {
            // Given
            let token = "test-auth-token-123"
            let provider = ServiceProvider.cursor
            mockKeychainServices[provider]?.saveTokenShouldSucceed = false

            // When
            let result = tokenManager.saveToken(token, for: provider)

            // Then
            #expect(result == false)
            #expect(mockKeychainServices[provider]?.saveTokenCalled == true)
        }

        @Test("retrieve saved token")
        func retrieveSavedToken() {
            // Given
            let token = "test-token-456"
            let provider = ServiceProvider.cursor
            mockKeychainServices[provider]?.setStoredToken(token)

            // When
            let retrievedToken = tokenManager.getAuthToken(for: provider)

            // Then
            #expect(retrievedToken == token)
        }

        @Test("delete token success")
        func deleteTokenSuccess() {
            // Given
            let token = "token-to-delete"
            let provider = ServiceProvider.cursor
            mockKeychainServices[provider]?.setStoredToken(token)

            // When
            let result = tokenManager.deleteToken(for: provider)

            // Then
            #expect(result == true)
            #expect(mockKeychainServices[provider]?.deleteTokenCalled == true)
        }

        @Test("delete token failure")
        func deleteTokenFailure() {
            // Given
            let provider = ServiceProvider.cursor
            mockKeychainServices[provider]?.deleteTokenShouldSucceed = false

            // When
            let result = tokenManager.deleteToken(for: provider)

            // Then
            #expect(result == false)
        }

        @Test("retrieve non-existent token")
        func retrieveNonExistentToken() {
            // Given
            let provider = ServiceProvider.cursor
            // No token stored

            // When
            let retrievedToken = tokenManager.getAuthToken(for: provider)

            // Then
            #expect(retrievedToken == nil)
        }
    }
    
    // MARK: - Cookie Management
    
    @Suite("Cookie Management")
    struct CookieManagement {
        private let tokenManager: AuthenticationTokenManager
        private let mockKeychainServices: [ServiceProvider: KeychainServiceMock]

        init() {
            var services: [ServiceProvider: KeychainServiceMock] = [:]
            for provider in ServiceProvider.allCases {
                services[provider] = KeychainServiceMock()
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
            mockKeychainServices[provider]?.setStoredToken(token)

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

        @Test("get cookies without token")
        func getCookiesWithoutToken() {
            // Given
            let provider = ServiceProvider.cursor
            // No token stored

            // When
            let cookies = tokenManager.getCookies(for: provider)

            // Then
            #expect(cookies == nil)
        }

        @Test("cookie properties validation")
        func cookiePropertiesValidation() {
            // Given
            let token = "secure-token"
            let provider = ServiceProvider.cursor
            mockKeychainServices[provider]?.setStoredToken(token)

            // When
            let cookies = tokenManager.getCookies(for: provider)

            // Then
            #expect(cookies?.count == 1)

            if let cookie = cookies?.first {
                #expect(cookie.isHTTPOnly == false)
                #expect(cookie.isSecure == true)
                // Note: sameSitePolicy may be nil on some platforms
                #expect(cookie.sameSitePolicy == .sameSiteStrict || cookie.sameSitePolicy == nil)
                #expect(cookie.path == "/")
                #expect(cookie.value.isEmpty == false)
            }
        }

        @Test("cookie expiry time")
        func cookieExpiryTime() {
            // Given
            let token = "expiry-test-token"
            let provider = ServiceProvider.cursor
            mockKeychainServices[provider]?.setStoredToken(token)

            // When
            let cookies = tokenManager.getCookies(for: provider)

            // Then
            if let cookie = cookies?.first,
               let expiryDate = cookie.expiresDate {
                let thirtyDaysFromNow = Date(timeIntervalSinceNow: 3600 * 24 * 30)
                let timeDifference = abs(expiryDate.timeIntervalSince(thirtyDaysFromNow))

                // Should be within 1 minute of 30 days from now
                #expect(timeDifference < 60)
            }
        }

        @Test("multiple providers cookie isolation")
        func multipleProvidersCookieIsolation() {
            // Given
            let cursorToken = "cursor-cookie-token"
            let cursorProvider = ServiceProvider.cursor

            mockKeychainServices[cursorProvider]?.setStoredToken(cursorToken)

            // When
            let cursorCookies = tokenManager.getCookies(for: cursorProvider)

            // Then
            #expect(cursorCookies != nil)
            #expect(cursorCookies?.count == 1)

            // Other providers should not have cookies
            for provider in ServiceProvider.allCases where provider != cursorProvider {
                let otherCookies = tokenManager.getCookies(for: provider)
                #expect(otherCookies == nil)
            }
        }
    }
    
    // MARK: - Edge Cases
    
    @Suite("Edge Cases", .tags(.edgeCase, .fast))
    struct EdgeCases {
        private let tokenManager: AuthenticationTokenManager
        private let mockKeychainServices: [ServiceProvider: KeychainServiceMock]

        init() {
            var services: [ServiceProvider: KeychainServiceMock] = [:]
            for provider in ServiceProvider.allCases {
                services[provider] = KeychainServiceMock()
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
            #expect(mockKeychainServices[provider]?.lastSavedToken == emptyToken)
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
            #expect(mockKeychainServices[provider]?.lastSavedToken == longToken)
        }

        @Test("save special characters token")
        func saveSpecialCharactersToken() {
            // Given
            let specialToken = "test!@#$%^&*()_+-=[]{}|;':\",./<>?"
            let provider = ServiceProvider.cursor

            // When
            let result = tokenManager.saveToken(specialToken, for: provider)

            // Then
            #expect(result == true)
            #expect(mockKeychainServices[provider]?.lastSavedToken == specialToken)
        }

        @Test("save unicode token")
        func saveUnicodeToken() {
            // Given
            let unicodeToken = "test-👋-🌍-😀-token"
            let provider = ServiceProvider.cursor

            // When
            let result = tokenManager.saveToken(unicodeToken, for: provider)

            // Then
            #expect(result == true)
            #expect(mockKeychainServices[provider]?.lastSavedToken == unicodeToken)
        }

        @Test("update existing token")
        func updateExistingToken() {
            // Given
            let provider = ServiceProvider.cursor
            let originalToken = "original-token"
            let updatedToken = "updated-token"

            mockKeychainServices[provider]?.setStoredToken(originalToken)

            // When
            let result = tokenManager.saveToken(updatedToken, for: provider)

            // Then
            #expect(result == true)
            #expect(mockKeychainServices[provider]?.lastSavedToken == updatedToken)
            #expect(tokenManager.getAuthToken(for: provider) == updatedToken)
        }

        @Test("delete already deleted token")
        func deleteAlreadyDeletedToken() {
            // Given
            let provider = ServiceProvider.cursor
            // No token stored

            // When
            let result = tokenManager.deleteToken(for: provider)

            // Then
            #expect(result == true)
            #expect(mockKeychainServices[provider]?.deleteTokenCalled == true)
        }

        @Test("concurrent access simulation")
        func concurrentAccessSimulation() {
            // Given
            let provider = ServiceProvider.cursor
            let tokens = (1...10).map { "token-\($0)" }

            // When - Save tokens sequentially (simulating concurrent access)
            for token in tokens {
                _ = tokenManager.saveToken(token, for: provider)
            }

            // Then - Should have the last token
            #expect(tokenManager.getAuthToken(for: provider) == "token-10")
        }

        @Test("keychain error recovery")
        func keychainErrorRecovery() {
            // Given
            let provider = ServiceProvider.cursor
            let token = "recovery-test-token"

            // First make save fail
            mockKeychainServices[provider]?.saveTokenShouldSucceed = false
            let failResult = tokenManager.saveToken(token, for: provider)
            #expect(failResult == false)

            // When - Recover from error
            mockKeychainServices[provider]?.shouldFailSave = false
            mockKeychainServices[provider]?.saveTokenShouldSucceed = true
            let successResult = tokenManager.saveToken(token, for: provider)

            // Then
            #expect(successResult == true)
            #expect(tokenManager.getAuthToken(for: provider) == token)
        }
    }
}