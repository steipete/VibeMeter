import Foundation
import os.log

// MARK: - Multi-Provider Error Handler

/// Handles errors that occur during multi-provider data operations.
///
/// This handler centralizes error processing logic for all provider types,
/// ensuring consistent error handling and appropriate status updates.
final class MultiProviderErrorHandler {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.vibemeter", category: "MultiProviderErrorHandler")
    private let sessionStateManager: SessionStateManager

    // MARK: - Initialization

    init(sessionStateManager: SessionStateManager) {
        self.sessionStateManager = sessionStateManager
    }

    // MARK: - Public Methods

    /// Handles errors that occur during provider data refresh operations.
    func handleRefreshError(
        for provider: ServiceProvider,
        error: Error,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        refreshErrors: inout [ServiceProvider: String]) {
        switch error {
        case let providerError as ProviderError where providerError == .unauthorized || providerError == .noTeamFound:
            handleProviderSpecificError(
                for: provider,
                error: providerError,
                userSessionData: userSessionData,
                spendingData: spendingData)
        case let providerError as ProviderError where providerError == .rateLimitExceeded:
            handleRateLimitError(for: provider, spendingData: spendingData, refreshErrors: &refreshErrors)
        case let retryableError as NetworkRetryHandler.RetryableError:
            handleNetworkError(
                for: provider,
                error: retryableError,
                spendingData: spendingData,
                refreshErrors: &refreshErrors)
        default:
            handleGenericError(
                for: provider,
                error: error,
                userSessionData: userSessionData,
                spendingData: spendingData,
                refreshErrors: &refreshErrors)
        }
    }

    // MARK: - Private Methods

    private func handleProviderSpecificError(
        for provider: ServiceProvider,
        error: ProviderError,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData) {
        let errorMessage = error == .unauthorized ? "Authentication failed" : "Team data unavailable"
        logger.warning("\(errorMessage) for \(provider.displayName)")

        if error == .unauthorized {
            logger.warning("Clearing session data due to authentication failure")
            spendingData.updateConnectionStatus(for: provider, status: .error(message: errorMessage))
            sessionStateManager.handleAuthenticationError(
                for: provider,
                error: error,
                userSessionData: userSessionData,
                spendingData: spendingData)
        } else {
            logger.info("Team data unavailable but user remains authenticated")
            spendingData.updateConnectionStatus(for: provider, status: .connected)
            userSessionData.setTeamFetchError(
                for: provider,
                message: "Team data unavailable, but you remain logged in.")
        }
    }

    private func handleRateLimitError(
        for provider: ServiceProvider,
        spendingData: MultiProviderSpendingData,
        refreshErrors: inout [ServiceProvider: String]) {
        logger.warning("Rate limit exceeded for \(provider.displayName)")
        spendingData.updateConnectionStatus(for: provider, status: .rateLimited(until: nil))
        refreshErrors[provider] = "Rate limit exceeded"
    }

    private func handleNetworkError(
        for provider: ServiceProvider,
        error: NetworkRetryHandler.RetryableError,
        spendingData: MultiProviderSpendingData,
        refreshErrors: inout [ServiceProvider: String]) {
        logger.error("Network error for \(provider.displayName): \(error)")
        if let status = ProviderConnectionStatus.from(error) {
            spendingData.updateConnectionStatus(for: provider, status: status)
        } else {
            spendingData.updateConnectionStatus(for: provider, status: .error(message: "Network error"))
        }
        refreshErrors[provider] = error.localizedDescription
    }

    private func handleGenericError(
        for provider: ServiceProvider,
        error: Error,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        refreshErrors: inout [ServiceProvider: String]) {
        logger.error("Failed to refresh data for \(provider.displayName): \(error)")
        let errorMessage = "Error fetching data: \(error.localizedDescription)".prefix(50)
        refreshErrors[provider] = String(errorMessage)
        userSessionData.setErrorMessage(for: provider, message: String(errorMessage))

        if let providerError = error as? ProviderError {
            spendingData.updateConnectionStatus(for: provider, status: .from(providerError))
        } else {
            spendingData.updateConnectionStatus(for: provider, status: .error(message: String(errorMessage)))
        }
    }
}
