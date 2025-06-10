import Foundation
import os.log

/// Manages session state validation and login flow coordination.
///
/// This manager handles login success/failure callbacks, session consistency validation,
/// and provider authentication state management. It coordinates with the login manager
/// and maintains session data integrity.
@Observable
@MainActor
public final class SessionStateManager {
    // MARK: - Dependencies

    private let loginManager: MultiProviderLoginManager
    private let settingsManager: any SettingsManagerProtocol
    private let logger = Logger(subsystem: "com.vibemeter", category: "SessionStateManager")

    // MARK: - Callbacks

    public var onLoginSuccess: ((ServiceProvider) async -> Void)?
    public var onLoginFailure: ((ServiceProvider, Error) -> Void)?
    public var onLoginDismiss: ((ServiceProvider) -> Void)?

    // MARK: - Initialization

    public init(
        loginManager: MultiProviderLoginManager,
        settingsManager: any SettingsManagerProtocol) {
        self.loginManager = loginManager
        self.settingsManager = settingsManager

        setupLoginCallbacks()
        logger.info("SessionStateManager initialized")
    }

    // MARK: - Public Methods

    /// Validates session consistency at startup for all providers
    public func validateSessionConsistency(
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData) {
        logger.info("Validating session consistency at startup")

        for provider in ServiceProvider.allCases {
            validateProviderSessionConsistency(
                provider: provider,
                userSessionData: userSessionData,
                spendingData: spendingData)
        }
    }

    /// Initializes session state for providers with existing tokens
    public func initializeExistingProviderSessions(
        userSessionData: MultiProviderUserSessionData) {
        // Check regular providers with tokens
        for provider in loginManager.loggedInProviders {
            logger.info("Initializing session state for logged-in provider: \(provider.displayName)")
            // Create a basic logged-in session state until we fetch full data
            userSessionData.handleLoginSuccess(
                for: provider,
                email: "", // Will be updated when data is fetched
                teamName: nil,
                teamId: nil)
        }
        
        // Special handling for Claude - check folder access
        Task { @MainActor in
            if ClaudeLogManager.shared.hasAccess {
                // Check if Claude already has a token
                if loginManager.getAuthToken(for: .claude) == nil {
                    logger.info("Claude has folder access but no token, initializing...")
                    // Save the dummy token for Claude through login manager
                    let claudeToken = "claude_local_access"
                    loginManager.handleLoginSuccess(for: .claude, cookieValue: claudeToken)
                    logger.info("Initialized Claude with folder access")
                } else if !userSessionData.isLoggedIn(to: .claude) {
                    // Token exists but session not initialized
                    logger.info("Claude has token but no session, initializing...")
                    userSessionData.handleLoginSuccess(
                        for: .claude,
                        email: "\(NSUserName())@local",
                        teamName: nil,
                        teamId: nil)
                }
            }
        }

        logger.info(
            "Initialized session states for \(self.loginManager.loggedInProviders.count) logged-in providers")
    }

    /// Handles logout from a specific provider
    public func handleLogout(
        from provider: ServiceProvider,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData) {
        logger.info("Handling logout from \(provider.displayName)")

        loginManager.logOut(from: provider)
        userSessionData.handleLogout(from: provider)
        spendingData.clear(provider: provider)
        settingsManager.clearUserSessionData(for: provider)

        logger.info("Successfully logged out from \(provider.displayName)")
    }

    /// Handles logout from all providers
    public func handleLogoutFromAll(
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData) {
        logger.info("Handling logout from all providers")

        let loggedInProviders = ServiceProvider.allCases.filter { provider in
            userSessionData.isLoggedIn(to: provider)
        }

        for provider in loggedInProviders {
            handleLogout(
                from: provider,
                userSessionData: userSessionData,
                spendingData: spendingData)
        }

        logger.info("Successfully logged out from all \(loggedInProviders.count) providers")
    }

    /// Updates session data after successful data fetch
    public func updateSessionAfterDataFetch(
        for provider: ServiceProvider,
        userInfo: String,
        teamInfo: (name: String, id: Int),
        userSessionData: MultiProviderUserSessionData) {
        logger.info("Updating session data for \(provider.displayName)")

        // Update session data
        userSessionData.handleLoginSuccess(
            for: provider,
            email: userInfo,
            teamName: teamInfo.name,
            teamId: teamInfo.id)

        // Sync with SettingsManager
        let providerSession = ProviderSession(
            provider: provider,
            teamId: teamInfo.id,
            teamName: teamInfo.name,
            userEmail: userInfo,
            isActive: true)
        settingsManager.updateSession(for: provider, session: providerSession)

        logger.info("Updated session data for \(provider.displayName)")
    }

    /// Handles authentication errors by clearing session data
    public func handleAuthenticationError(
        for provider: ServiceProvider,
        error: ProviderError,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData) {
        switch error {
        case .unauthorized:
            logger.warning("Unauthorized for \(provider.displayName), clearing session and logging out")
            clearSessionData(
                for: provider,
                userSessionData: userSessionData,
                spendingData: spendingData)

        case .noTeamFound:
            logger.warning("Team not found for \(provider.displayName), but keeping user logged in with valid token")
            // Don't clear session data - user still has valid authentication
            // Just set an error message to inform them that team features may be limited
            userSessionData.setTeamFetchError(
                for: provider,
                message: "Team data unavailable, but you remain logged in.")

        default:
            // For other errors, don't clear session data
            break
        }
    }

    // MARK: - Private Methods

    private func setupLoginCallbacks() {
        logger.info("Setting up login callbacks")

        loginManager.onLoginSuccess = { [weak self] provider in
            self?.logger.info("Login success callback triggered for \(provider.displayName)")
            Task { @MainActor in
                await self?.onLoginSuccess?(provider)
            }
        }

        loginManager.onLoginFailure = { [weak self] provider, error in
            self?.logger.info(
                "Login failure callback triggered for \(provider.displayName): \(error.localizedDescription)")
            self?.onLoginFailure?(provider, error)
        }

        loginManager.onLoginDismiss = { [weak self] provider in
            self?.logger.info("Login dismissed for \(provider.displayName)")
            self?.onLoginDismiss?(provider)
        }
    }

    private func validateProviderSessionConsistency(
        provider: ServiceProvider,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData) {
        // Check if we have stored session data but no keychain token
        if let storedSession = settingsManager.getSession(for: provider),
           storedSession.isActive {
            let hasToken = loginManager.getAuthToken(for: provider) != nil

            if !hasToken {
                let warningMessage = "Inconsistent state detected for \(provider.displayName): " +
                    "stored session active but no keychain token"
                logger.warning("\(warningMessage)")
                logger.warning("Clearing stale session data for \(provider.displayName)")

                // Clear the inconsistent session data
                settingsManager.clearUserSessionData(for: provider)
                userSessionData.handleLogout(from: provider)
                spendingData.clear(provider: provider)
            } else {
                logger.info(
                    "Session consistency validated for \(provider.displayName): both session and token present")
            }
        }
    }

    private func clearSessionData(
        for provider: ServiceProvider,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData) {
        // Clear all stored session data since the token is invalid
        userSessionData.handleLogout(from: provider)
        spendingData.clear(provider: provider)
        settingsManager.clearUserSessionData(for: provider)
        loginManager.logOut(from: provider)

        logger.info("Cleared session data for \(provider.displayName)")
    }
}
