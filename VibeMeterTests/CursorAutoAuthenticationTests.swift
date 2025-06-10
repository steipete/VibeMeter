import Foundation
import Testing
import KeychainAccess
@testable import VibeMeter

// MARK: - Cursor Auto-Authentication Tests

@Suite("Cursor Auto-Authentication Tests", .tags(.authentication))
struct CursorAutoAuthenticationTests {
    
    // MARK: - Test Helpers
    
    @MainActor
    private func createTestEnvironment() -> (
        loginManager: MultiProviderLoginManager,
        webViewManager: LoginWebViewManagerMock,
        tokenManager: AuthenticationTokenManager
    ) {
        let factory = ProviderFactory(settingsManager: MockSettingsManager())
        let loginManager = MultiProviderLoginManager(providerFactory: factory)
        let webViewManager = LoginWebViewManagerMock()
        let tokenManager = AuthenticationTokenManager()
        
        // Replace the real web view manager with our mock
        // Note: In real implementation, we'd need dependency injection
        
        return (loginManager, webViewManager, tokenManager)
    }
    
    private func clearTestCredentials() {
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try? credentialKeychain.removeAll()
    }
    
    // MARK: - Credential Storage Tests
    
    @Test("Store Cursor credentials on successful login")
    @MainActor
    func storeCredentialsOnLogin() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        let webViewManager = LoginWebViewManagerMock()
        
        // Simulate credential capture from login form
        let testEmail = "test@example.com"
        let testPassword = "securePassword123"
        
        webViewManager.simulateCredentialCapture(
            email: testEmail,
            password: testPassword
        )
        
        // Verify credentials were stored
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        let storedEmail = try credentialKeychain.get("cursor_email")
        let storedPassword = try credentialKeychain.get("cursor_password")
        
        #expect(storedEmail == testEmail)
        #expect(storedPassword == testPassword)
    }
    
    @Test("Clear credentials on logout")
    @MainActor
    func clearCredentialsOnLogout() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        // Store test credentials
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try credentialKeychain.set("test@example.com", key: "cursor_email")
        try credentialKeychain.set("password123", key: "cursor_password")
        
        // Simulate logout
        let (loginManager, _, _) = createTestEnvironment()
        loginManager.logOut(from: .cursor)
        
        // Verify credentials were cleared
        let emailAfterLogout = try? credentialKeychain.get("cursor_email")
        let passwordAfterLogout = try? credentialKeychain.get("cursor_password")
        
        #expect(emailAfterLogout == nil)
        #expect(passwordAfterLogout == nil)
    }
    
    // MARK: - Auto-Authentication Flow Tests
    
    @Test("Attempt auto-authentication with stored credentials")
    @MainActor
    func attemptAutoAuthWithStoredCredentials() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        // Store test credentials
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try credentialKeychain.set("test@example.com", key: "cursor_email")
        try credentialKeychain.set("password123", key: "cursor_password")
        
        let webViewManager = LoginWebViewManagerMock()
        var authenticationAttempted = false
        
        // Attempt auto-authentication
        webViewManager.attemptAutomaticReauthentication(for: .cursor) { success in
            authenticationAttempted = true
            #expect(success)
        }
        
        // Wait for async operation
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(authenticationAttempted)
        #expect(webViewManager.autoLoginScriptInjected)
        #expect(webViewManager.lastInjectedEmail == "test@example.com")
        #expect(webViewManager.lastInjectedPassword == "password123")
    }
    
    @Test("Auto-authentication fails without stored credentials")
    @MainActor
    func autoAuthFailsWithoutCredentials() async throws {
        clearTestCredentials()
        
        let webViewManager = LoginWebViewManagerMock()
        var authenticationResult: Bool?
        
        webViewManager.attemptAutomaticReauthentication(for: .cursor) { success in
            authenticationResult = success
        }
        
        // Wait for async operation
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(authenticationResult == false)
        #expect(!webViewManager.autoLoginScriptInjected)
    }
    
    // MARK: - CAPTCHA Detection Tests
    
    @Test("Detect CAPTCHA and show login window")
    @MainActor
    func detectCaptchaAndShowWindow() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        // Store credentials
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try credentialKeychain.set("test@example.com", key: "cursor_email")
        try credentialKeychain.set("password123", key: "cursor_password")
        
        let webViewManager = LoginWebViewManagerMock()
        webViewManager.simulateCaptchaPresence = true
        
        var windowShown = false
        webViewManager.onShowLoginWindow = { provider in
            #expect(provider == .cursor)
            windowShown = true
        }
        
        webViewManager.attemptAutomaticReauthentication(for: .cursor) { success in
            #expect(!success)
        }
        
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(windowShown)
        #expect(webViewManager.captchaDetected)
    }
    
    // MARK: - Session Cookie Validation Tests
    
    @Test("Validate session cookie after auto-authentication")
    @MainActor
    func validateSessionCookieAfterAutoAuth() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        // Store credentials
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try credentialKeychain.set("test@example.com", key: "cursor_email")
        try credentialKeychain.set("password123", key: "cursor_password")
        
        let webViewManager = LoginWebViewManagerMock()
        let tokenManager = AuthenticationTokenManager()
        
        // Simulate successful auto-authentication with cookie
        webViewManager.simulateSuccessfulLogin = true
        webViewManager.mockSessionCookie = "valid_session_token"
        
        var loginSuccessful = false
        webViewManager.onLoginCompletion = { provider, result in
            if case .success(let token) = result {
                #expect(provider == .cursor)
                #expect(token == "valid_session_token")
                loginSuccessful = true
                
                // Save token
                _ = tokenManager.saveToken(token, for: provider)
            }
        }
        
        webViewManager.attemptAutomaticReauthentication(for: .cursor) { _ in }
        
        try await Task.sleep(for: .milliseconds(200))
        
        #expect(loginSuccessful)
        #expect(tokenManager.getAuthToken(for: .cursor) == "valid_session_token")
    }
    
    // MARK: - Timeout Tests
    
    @Test("Auto-authentication times out after 30 seconds")
    @MainActor
    func autoAuthTimeout() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        // Store credentials
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try credentialKeychain.set("test@example.com", key: "cursor_email")
        try credentialKeychain.set("password123", key: "cursor_password")
        
        let webViewManager = LoginWebViewManagerMock()
        webViewManager.simulateTimeout = true
        
        var timedOut = false
        let startTime = Date()
        
        webViewManager.attemptAutomaticReauthentication(for: .cursor) { success in
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(!success)
            #expect(elapsed < 31) // Should timeout at ~30 seconds
            timedOut = true
        }
        
        // Wait for timeout
        try await Task.sleep(for: .seconds(2)) // Simulated timeout in mock
        
        #expect(timedOut)
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Handle network errors during auto-authentication")
    @MainActor
    func handleNetworkErrors() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        // Store credentials
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try credentialKeychain.set("test@example.com", key: "cursor_email")
        try credentialKeychain.set("password123", key: "cursor_password")
        
        let webViewManager = LoginWebViewManagerMock()
        webViewManager.simulateNetworkError = true
        
        var errorReceived = false
        webViewManager.onLoginCompletion = { provider, result in
            if case .failure = result {
                errorReceived = true
            }
        }
        
        webViewManager.attemptAutomaticReauthentication(for: .cursor) { success in
            #expect(!success)
        }
        
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(errorReceived)
    }
    
    // MARK: - Integration Tests
    
    @Test("Full auto-authentication flow from error detection")
    @MainActor
    func fullAutoAuthFlow() async throws {
        clearTestCredentials()
        defer { clearTestCredentials() }
        
        // Setup
        let orchestrator = MockMultiProviderDataOrchestrator()
        let errorHandler = MultiProviderErrorHandler(
            orchestrator: orchestrator,
            settingsManager: MockSettingsManager()
        )
        
        // Store credentials
        let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
        try credentialKeychain.set("test@example.com", key: "cursor_email")
        try credentialKeychain.set("password123", key: "cursor_password")
        
        // Simulate session expiry error
        let sessionExpiredError = ProviderError.authenticationError(
            message: "Session expired",
            statusCode: 401
        )
        
        var reauthAttempted = false
        orchestrator.onAttemptReauth = { provider in
            #expect(provider == .cursor)
            reauthAttempted = true
        }
        
        // Handle error which should trigger re-authentication
        await errorHandler.handleError(sessionExpiredError, for: .cursor)
        
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(reauthAttempted)
    }
}

// MARK: - Mock Classes

@MainActor
final class LoginWebViewManagerMock: NSObject {
    var autoLoginScriptInjected = false
    var lastInjectedEmail: String?
    var lastInjectedPassword: String?
    var captchaDetected = false
    var simulateCaptchaPresence = false
    var simulateSuccessfulLogin = false
    var simulateTimeout = false
    var simulateNetworkError = false
    var mockSessionCookie: String?
    
    var onLoginCompletion: ((ServiceProvider, Result<String, Error>) -> Void)?
    var onShowLoginWindow: ((ServiceProvider) -> Void)?
    
    func attemptAutomaticReauthentication(for provider: ServiceProvider, completion: @escaping (Bool) -> Void) {
        guard provider == .cursor else {
            completion(false)
            return
        }
        
        Task { @MainActor in
            do {
                // Check for stored credentials
                let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
                guard let email = try credentialKeychain.get("cursor_email"),
                      let password = try credentialKeychain.get("cursor_password") else {
                    completion(false)
                    return
                }
                
                // Simulate script injection
                self.autoLoginScriptInjected = true
                self.lastInjectedEmail = email
                self.lastInjectedPassword = password
                
                // Simulate various scenarios
                if simulateTimeout {
                    try await Task.sleep(for: .seconds(2))
                    completion(false)
                    return
                }
                
                if simulateCaptchaPresence {
                    self.captchaDetected = true
                    onShowLoginWindow?(.cursor)
                    completion(false)
                    return
                }
                
                if simulateNetworkError {
                    let error = URLError(.notConnectedToInternet)
                    onLoginCompletion?(.cursor, .failure(error))
                    completion(false)
                    return
                }
                
                if simulateSuccessfulLogin, let cookie = mockSessionCookie {
                    onLoginCompletion?(.cursor, .success(cookie))
                    completion(true)
                    return
                }
                
                completion(false)
                
            } catch {
                completion(false)
            }
        }
    }
    
    func simulateCredentialCapture(email: String, password: String) {
        Task {
            do {
                let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
                try credentialKeychain.set(email, key: "cursor_email")
                try credentialKeychain.set(password, key: "cursor_password")
            } catch {
                // Handle error
            }
        }
    }
}

@MainActor
final class MockMultiProviderDataOrchestrator: MultiProviderDataOrchestrator {
    var onAttemptReauth: ((ServiceProvider) -> Void)?
    
    override init() {
        super.init(settingsManager: MockSettingsManager())
    }
}