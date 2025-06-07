// swiftlint:disable nesting
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
            var keychainHelpers: [ServiceProvider: KeychainServicing] = [:]

            for provider in ServiceProvider.allCases {
                let mock = KeychainServiceMock()
                mockServices[provider] = mock
                keychainHelpers[provider] = mock
            }

            self.mockKeychainServices = mockServices
            self.tokenManager = AuthenticationTokenManager(keychainHelpers: keychainHelpers)
        }

        // MARK: - Token Storage Tests

        struct TokenOperationTestCase {
            let provider: ServiceProvider
            let token: String
            let description: String
        }

        @Test(
            "Save and retrieve tokens",
            .tags(.critical, .requiresKeychain),
            arguments: ServiceProvider.allCases.map { provider in
                TokenOperationTestCase(
                    provider: provider,
                    token: "test-token-\(provider.rawValue)",
                    description: "\(provider.rawValue) provider")
            })
        func saveAndRetrieveTokens(testCase: TokenOperationTestCase) {
            // Save token
            let saveResult = tokenManager.saveToken(testCase.token, for: testCase.provider)
            #expect(saveResult == true)
            #expect(mockKeychainServices[testCase.provider]?.saveTokenCalled == true)

            // Retrieve token
            let retrievedToken = tokenManager.getAuthToken(for: testCase.provider)
            #expect(retrievedToken == testCase.token)

            // Delete token
            let deleteResult = tokenManager.deleteToken(for: testCase.provider)
            #expect(deleteResult == true)
            #expect(mockKeychainServices[testCase.provider]?.deleteTokenCalled == true)

            // Verify deletion
            let afterDelete = tokenManager.getAuthToken(for: testCase.provider)
            #expect(afterDelete == nil)
        }

        struct ErrorTestCase {
            let operation: String
            let shouldSucceed: Bool
            let description: String
        }

        @Test("Token operation failures", arguments: [
            ErrorTestCase(operation: "save", shouldSucceed: false, description: "Save failure"),
            ErrorTestCase(operation: "delete", shouldSucceed: false, description: "Delete failure"),
        ])
        func tokenOperationFailures(testCase: ErrorTestCase) {
            let provider = ServiceProvider.cursor

            switch testCase.operation {
            case "save":
                mockKeychainServices[provider]?.saveTokenShouldSucceed = testCase.shouldSucceed
                let result = tokenManager.saveToken("test-token", for: provider)
                #expect(result == testCase.shouldSucceed)
                #expect(mockKeychainServices[provider]?.saveTokenCalled == true)

            case "delete":
                mockKeychainServices[provider]?.deleteTokenShouldSucceed = testCase.shouldSucceed
                let result = tokenManager.deleteToken(for: provider)
                #expect(result == testCase.shouldSucceed)

            default:
                Issue.record("Unknown operation: \(testCase.operation)")
            }
        }
    }

    // MARK: - Cookie Management

    @Suite("Cookie Management")
    struct CookieManagement {
        private let tokenManager: AuthenticationTokenManager
        private let mockKeychainServices: [ServiceProvider: KeychainServiceMock]

        init() {
            var services: [ServiceProvider: KeychainServiceMock] = [:]
            var keychainHelpers: [ServiceProvider: KeychainServicing] = [:]

            for provider in ServiceProvider.allCases {
                let mock = KeychainServiceMock()
                services[provider] = mock
                keychainHelpers[provider] = mock
            }

            self.mockKeychainServices = services
            self.tokenManager = AuthenticationTokenManager(keychainHelpers: keychainHelpers)
        }

        // MARK: - Cookie Generation Tests

        struct CookieTestCase: CustomTestStringConvertible {
            let provider: ServiceProvider
            let token: String?
            let expectCookie: Bool

            var testDescription: String {
                "\(provider.rawValue): \(token != nil ? "with token" : "without token")"
            }
        }

        @Test("Cookie generation for providers", arguments: [
            CookieTestCase(provider: .cursor, token: "cursor-token", expectCookie: true),
            CookieTestCase(provider: .cursor, token: nil, expectCookie: false),
        ])
        func cookieGeneration(testCase: CookieTestCase) throws {
            // Setup
            if let token = testCase.token {
                mockKeychainServices[testCase.provider]?.setStoredToken(token)
            }

            // Get cookies
            let cookies = tokenManager.getCookies(for: testCase.provider)

            if testCase.expectCookie {
                #expect(cookies != nil)
                let cookie = try #require(cookies?.first)

                // Validate cookie properties
                #expect(cookie.name == testCase.provider.authCookieName)
                #expect(cookie.domain == testCase.provider.cookieDomain)
                #expect(cookie.isSecure == true)
                #expect(cookie.isHTTPOnly == false)
                #expect(cookie.path == "/")
                #expect(!cookie.value.isEmpty)

                // Validate expiry (30 days ± 1 minute)
                if let expiryDate = cookie.expiresDate {
                    let expectedExpiry = Date(timeIntervalSinceNow: 3600 * 24 * 30)
                    let timeDifference = abs(expiryDate.timeIntervalSince(expectedExpiry))
                    #expect(timeDifference < 60)
                }

                // Validate sameSitePolicy (may be nil on some platforms)
                #expect(cookie.sameSitePolicy == .sameSiteStrict || cookie.sameSitePolicy == nil)
            } else {
                #expect(cookies == nil)
            }
        }

        @Test("Cookie isolation between providers", arguments: ServiceProvider.allCases)
        func cookieIsolation(activeProvider: ServiceProvider) {
            // Set token only for the active provider
            let token = "\(activeProvider.rawValue)-isolation-token"
            mockKeychainServices[activeProvider]?.setStoredToken(token)

            // Verify cookies for all providers
            for provider in ServiceProvider.allCases {
                let cookies = tokenManager.getCookies(for: provider)

                if provider == activeProvider {
                    #expect(cookies != nil)
                    #expect(cookies?.count == 1)
                    #expect(cookies?.first?.value == token)
                } else {
                    #expect(cookies == nil)
                }
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

        // MARK: - Edge Cases

        struct EdgeCaseToken: CustomTestStringConvertible {
            let token: String
            let description: String

            var testDescription: String { description }
        }

        @Test("Provider isolation", arguments: ServiceProvider.allCases)
        func providerIsolation(targetProvider: ServiceProvider) {
            let token = "\(targetProvider.rawValue)-isolation-test"

            // Save token for target provider
            let saved = tokenManager.saveToken(token, for: targetProvider)
            #expect(saved == true)
            #expect(tokenManager.getAuthToken(for: targetProvider) == token)

            // Verify other providers don't have this token
            for provider in ServiceProvider.allCases where provider != targetProvider {
                #expect(tokenManager.getAuthToken(for: provider) == nil)
            }
        }

        @Test("Special token handling", arguments: [
            EdgeCaseToken(token: "", description: "Empty token"),
            EdgeCaseToken(token: String(repeating: "a", count: 10000), description: "Very long token"),
            EdgeCaseToken(token: "test!@#$%^&*()_+-=[]{}|;':\",./<>?", description: "Special characters"),
            EdgeCaseToken(token: "test-👋-🌍-😀-token", description: "Unicode characters"),
            EdgeCaseToken(token: "  token with spaces  ", description: "Token with spaces"),
            EdgeCaseToken(token: "\n\t\rtoken\nwith\nwhitespace\t", description: "Token with whitespace")
        ])
        func specialTokenHandling(testCase: EdgeCaseToken) {
            let provider = ServiceProvider.cursor

            // Save token
            let saveResult = tokenManager.saveToken(testCase.token, for: provider)
            #expect(saveResult == true)
            #expect(mockKeychainServices[provider]?.lastSavedToken == testCase.token)

            // Retrieve token
            let retrieved = tokenManager.getAuthToken(for: provider)
            #expect(retrieved == testCase.token)
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
            let tokens = (1 ... 10).map { "token-\($0)" }

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
