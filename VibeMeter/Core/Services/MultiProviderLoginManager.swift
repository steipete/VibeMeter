import Foundation
import os.log

// MARK: - Multi-Provider Login Manager

/// Manages authentication across multiple service providers simultaneously.
///
/// This manager handles login/logout for multiple cost tracking services
/// (Cursor, Anthropic, OpenAI, etc.) allowing users to be logged into
/// multiple providers at once for comprehensive cost tracking.
@Observable
@MainActor
public final class MultiProviderLoginManager {
    // MARK: - Observable Properties

    public private(set) var providerLoginStates: [ServiceProvider: Bool] = [:]
    public private(set) var loginErrors: [ServiceProvider: String] = [:]

    // MARK: - Callbacks

    public var onLoginSuccess: ((ServiceProvider) -> Void)?
    public var onLoginFailure: ((ServiceProvider, Error) -> Void)?
    public var onLoginDismiss: ((ServiceProvider) -> Void)?

    // MARK: - Private Properties

    private let tokenManager: AuthenticationTokenManager
    private let stateManager: ProviderStateManager
    private let webViewManager: LoginWebViewManager
    private let providerFactory: ProviderFactory
    private let logger = Logger(subsystem: "com.vibemeter", category: "MultiProviderLogin")

    // MARK: - Initialization

    public init(providerFactory: ProviderFactory) {
        self.providerFactory = providerFactory
        self.tokenManager = AuthenticationTokenManager()
        self.stateManager = ProviderStateManager(tokenManager: tokenManager)
        self.webViewManager = LoginWebViewManager()

        setupDelegation()
        syncPublishedProperties()

        logger.info("MultiProviderLoginManager initialized for \(ServiceProvider.allCases.count) providers")
    }

    // MARK: - Public API

    /// Checks if user is logged into a specific provider.
    public func isLoggedIn(to provider: ServiceProvider) -> Bool {
        stateManager.isLoggedIn(to: provider)
    }

    /// Gets authentication token for a specific provider.
    public func getAuthToken(for provider: ServiceProvider) -> String? {
        tokenManager.getAuthToken(for: provider)
    }

    /// Gets authentication cookies for a specific provider.
    public func getCookies(for provider: ServiceProvider) -> [HTTPCookie]? {
        tokenManager.getCookies(for: provider)
    }

    /// Shows login window for a specific provider.
    public func showLoginWindow(for provider: ServiceProvider) {
        logger.info("showLoginWindow called for \(provider.displayName)")

        // Reset processing flag for new session
        stateManager.setProcessingLogin(false, for: provider)
        stateManager.clearError(for: provider)

        webViewManager.showLoginWindow(for: provider)
    }

    /// Logs out from a specific provider.
    public func logOut(from provider: ServiceProvider) {
        logger.info("logOut called for \(provider.displayName)")

        _ = tokenManager.deleteToken(for: provider)
        stateManager.setLoginState(false, for: provider)
        stateManager.clearError(for: provider)
        refreshProperties()

        logger.info("User logged out from \(provider.displayName)")

        // Notify that logout occurred
        logger.info("Calling onLoginFailure callback for \(provider.displayName) logout")
        let logoutError = NSError(
            domain: "MultiProviderLoginManager",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "User logged out from \(provider.displayName)."])
        onLoginFailure?(provider, logoutError)
    }

    /// Logs out from all providers.
    public func logOutFromAll() {
        stateManager.logOutFromAll()
        logger.info("User logged out from all providers")
    }

    /// Gets all providers the user is currently logged into.
    public var loggedInProviders: [ServiceProvider] {
        stateManager.loggedInProviders
    }

    /// Checks if user is logged into any provider.
    public var isLoggedInToAnyProvider: Bool {
        stateManager.isLoggedInToAnyProvider
    }

    /// Refreshes login states from keychain - useful after app launch.
    public func refreshLoginStatesFromKeychain() {
        stateManager.refreshLoginStatesFromKeychain()
        refreshProperties()
    }

    /// Validates tokens for all logged-in providers.
    public func validateAllTokens() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in loggedInProviders {
                group.addTask {
                    await self.validateToken(for: provider)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func setupDelegation() {
        webViewManager.onLoginCompletion = { [weak self] provider, result in
            self?.handleLoginCompletion(provider: provider, result: result)
        }

        webViewManager.onLoginDismiss = { [weak self] provider in
            self?.onLoginDismiss?(provider)
        }
    }

    private func syncPublishedProperties() {
        providerLoginStates = stateManager.providerLoginStates
        loginErrors = stateManager.loginErrors
    }

    private func refreshProperties() {
        providerLoginStates = stateManager.providerLoginStates
        loginErrors = stateManager.loginErrors
    }

    private func handleLoginCompletion(provider: ServiceProvider, result: Result<String, Error>) {
        switch result {
        case let .success(token):
            handleSuccessfulLogin(for: provider, token: token)
        case let .failure(error):
            onLoginFailure?(provider, error)
        }
    }

    private func handleSuccessfulLogin(for provider: ServiceProvider, token: String) {
        logger.info("handleSuccessfulLogin called for \(provider.displayName)")

        if tokenManager.saveToken(token, for: provider) {
            stateManager.setLoginState(true, for: provider)
            stateManager.clearError(for: provider)
            refreshProperties()
            webViewManager.closeLoginWindow(for: provider)
            logger.info("Calling onLoginSuccess callback for \(provider.displayName)")
            onLoginSuccess?(provider)
        } else {
            logger.error("Failed to save auth token for \(provider.displayName)")
            stateManager.setError(for: provider, message: "Failed to save token")
            refreshProperties()
            webViewManager.closeLoginWindow(for: provider)

            let error = NSError(
                domain: "MultiProviderLoginManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to save token for \(provider.displayName)."])
            onLoginFailure?(provider, error)
        }
    }

    private func validateToken(for provider: ServiceProvider) async {
        guard let token = getAuthToken(for: provider) else {
            stateManager.setLoginState(false, for: provider)
            return
        }

        let providerClient = providerFactory.createProvider(for: provider)
        let isValid = await providerClient.validateToken(authToken: token)

        if !isValid {
            logger.warning("Token validation failed for \(provider.displayName)")
            logOut(from: provider)
        }
    }

    // MARK: - Test Support

    #if DEBUG
        /// Test-only method to set login state directly.
        @MainActor
        public func _test_setLoginState(_ isLoggedIn: Bool, for provider: ServiceProvider) {
            stateManager.setLoginState(isLoggedIn, for: provider)
            refreshProperties()
        }

        /// Test-only method to simulate login with a token.
        @MainActor
        public func _test_simulateLogin(for provider: ServiceProvider, withToken token: String = "test-token") {
            _ = tokenManager.saveToken(token, for: provider)
            stateManager.setLoginState(true, for: provider)
            refreshProperties()
        }

        /// Test-only method to reset all login states.
        @MainActor
        public func _test_reset() {
            for provider in ServiceProvider.allCases {
                _ = tokenManager.deleteToken(for: provider)
                stateManager.setLoginState(false, for: provider)
                stateManager.clearError(for: provider)
            }
            refreshProperties()
        }
    #endif
}
