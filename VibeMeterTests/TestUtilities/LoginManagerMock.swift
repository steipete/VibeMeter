import Foundation
@testable import VibeMeter

/// Mock implementation for MultiProviderLoginManager testing
@MainActor
final class LoginManagerMock {
    // Callbacks
    var onLoginSuccess: (() -> Void)?
    var onLoginFailure: ((Error) -> Void)?
    var onLoginDismiss: (() -> Void)?

    // Mock state
    private var isLoggedInValue = false
    private var authToken: String?

    // Call tracking
    var showLoginWindowCalled = false
    var logOutCalled = false

    func isLoggedIn() -> Bool {
        isLoggedInValue
    }

    func getAuthToken() -> String? {
        authToken
    }

    func showLoginWindow() {
        showLoginWindowCalled = true
    }

    func logOut() {
        logOutCalled = true
        isLoggedInValue = false
        authToken = nil
        // Simulate logout callback
        onLoginFailure?(NSError(
            domain: "LoginManager",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "User logged out."]))
    }

    // Test helpers
    func simulateLogin(withToken token: String) {
        isLoggedInValue = true
        authToken = token
        // Call the success callback synchronously
        onLoginSuccess?()
    }

    func simulateLoginFailure(error: Error) {
        isLoggedInValue = false
        authToken = nil
        onLoginFailure?(error)
    }

    func reset() {
        isLoggedInValue = false
        authToken = nil
        showLoginWindowCalled = false
        logOutCalled = false
        onLoginSuccess = nil
        onLoginFailure = nil
        onLoginDismiss = nil
    }
}
