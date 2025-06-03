import Foundation
import os.log

/// Manages login states and errors for service providers.
@Observable
@MainActor
final class ProviderStateManager {
    // MARK: - Observable Properties

    private(set) var providerLoginStates: [ServiceProvider: Bool] = [:]
    private(set) var loginErrors: [ServiceProvider: String] = [:]
    private(set) var isProcessingLogin: [ServiceProvider: Bool] = [:]

    // MARK: - Private Properties

    private let tokenManager: AuthenticationTokenManager
    private let logger = Logger(subsystem: "com.vibemeter", category: "ProviderState")

    // MARK: - Initialization

    init(tokenManager: AuthenticationTokenManager) {
        self.tokenManager = tokenManager
        initializeLoginStates()
    }

    // MARK: - Public Methods

    /// Checks if user is logged into a specific provider.
    func isLoggedIn(to provider: ServiceProvider) -> Bool {
        providerLoginStates[provider, default: false]
    }

    /// Gets all providers the user is currently logged into.
    var loggedInProviders: [ServiceProvider] {
        ServiceProvider.allCases.filter { isLoggedIn(to: $0) }
    }

    /// Checks if user is logged into any provider.
    var isLoggedInToAnyProvider: Bool {
        !loggedInProviders.isEmpty
    }

    /// Updates login state for a provider.
    func setLoginState(_ isLoggedIn: Bool, for provider: ServiceProvider) {
        providerLoginStates[provider] = isLoggedIn
        logger.info("Updated login state for \(provider.displayName) to: \(isLoggedIn)")
    }

    /// Sets processing state for a provider.
    func setProcessingLogin(_ isProcessing: Bool, for provider: ServiceProvider) {
        isProcessingLogin[provider] = isProcessing
    }

    /// Checks if login is currently being processed for a provider.
    func isProcessingLogin(for provider: ServiceProvider) -> Bool {
        isProcessingLogin[provider, default: false]
    }

    /// Sets error message for a provider.
    func setError(for provider: ServiceProvider, message: String) {
        loginErrors[provider] = message
    }

    /// Clears error for a provider.
    func clearError(for provider: ServiceProvider) {
        loginErrors.removeValue(forKey: provider)
    }

    /// Refreshes login states from keychain - useful after app launch.
    func refreshLoginStatesFromKeychain() {
        logger.info("Refreshing login states from keychain")
        for provider in ServiceProvider.allCases {
            let hasToken = tokenManager.hasToken(for: provider)
            let oldState = providerLoginStates[provider, default: false]
            providerLoginStates[provider] = hasToken

            if oldState != hasToken {
                logger.info("Login state changed for \(provider.displayName): \(oldState) -> \(hasToken)")
            }
        }
    }

    /// Logs out from all providers.
    func logOutFromAll() {
        for provider in ServiceProvider.allCases {
            if isLoggedIn(to: provider) {
                setLoginState(false, for: provider)
                clearError(for: provider)
                _ = tokenManager.deleteToken(for: provider)
            }
        }
        logger.info("User logged out from all providers")
    }

    // MARK: - Private Methods

    private func initializeLoginStates() {
        for provider in ServiceProvider.allCases {
            let hasToken = tokenManager.hasToken(for: provider)
            providerLoginStates[provider] = hasToken
            isProcessingLogin[provider] = false

            logger.info("\(provider.displayName) initial login state: \(hasToken ? "logged in" : "not logged in")")
        }

        logger.info("ProviderStateManager initialized for \(ServiceProvider.allCases.count) providers")
    }
}
