import Foundation
import SwiftUI

// MARK: - Authentication State

/// Represents the authentication state for a provider.
public enum AuthenticationState: Codable, Sendable {
    case loggedOut
    case authenticating
    case loggedIn
}

// MARK: - Provider Session State

/// Represents the session state for a specific provider.
public struct ProviderSessionState: Codable, Sendable {
    public let provider: ServiceProvider
    public var authState: AuthenticationState
    public var userEmail: String?
    public var teamName: String?
    public var teamId: Int?
    public var lastErrorMessage: String?
    public var teamIdFetchFailed: Bool
    public var lastUpdated: Date

    public init(
        provider: ServiceProvider,
        authState: AuthenticationState = .loggedOut,
        userEmail: String? = nil,
        teamName: String? = nil,
        teamId: Int? = nil,
        lastErrorMessage: String? = nil,
        teamIdFetchFailed: Bool = false,
        lastUpdated: Date = Date()) {
        self.provider = provider
        self.authState = authState
        self.userEmail = userEmail
        self.teamName = teamName
        self.teamId = teamId
        self.lastErrorMessage = lastErrorMessage
        self.teamIdFetchFailed = teamIdFetchFailed
        self.lastUpdated = lastUpdated
    }

    /// Computed property for backward compatibility
    public var isLoggedIn: Bool {
        authState == .loggedIn
    }

    /// Computed property to check if authenticating
    public var isAuthenticating: Bool {
        authState == .authenticating
    }

    /// Updates session with successful login data.
    public mutating func handleLoginSuccess(email: String, teamName: String?, teamId: Int? = nil) {
        authState = .loggedIn
        userEmail = email
        self.teamName = teamName
        self.teamId = teamId
        lastErrorMessage = nil
        teamIdFetchFailed = false
        lastUpdated = Date()
    }

    /// Sets state to authenticating.
    public mutating func setAuthenticating() {
        authState = .authenticating
        lastErrorMessage = nil
        lastUpdated = Date()
    }

    /// Handles login failure with error message.
    public mutating func handleLoginFailure(error: Error) {
        authState = .loggedOut
        if error.localizedDescription.contains("logged out") {
            lastErrorMessage = nil
        } else if error.localizedDescription.contains("cancelled") {
            lastErrorMessage = nil
        } else if isUnauthorizedError(error) {
            // Unauthorized errors clear the session completely
            lastErrorMessage = nil
            userEmail = nil
            teamName = nil
            teamId = nil
            teamIdFetchFailed = false
        } else {
            // Create user-friendly error messages
            lastErrorMessage = formatErrorMessage(error)
        }
        // Don't clear user data on failure, just update state
        lastUpdated = Date()
    }

    /// Checks if an error is an unauthorized error (401).
    private func isUnauthorizedError(_ error: Error) -> Bool {
        // Check for NSError with 401 code
        if let nsError = error as NSError?, nsError.code == 401 {
            return true
        }

        // Check for ProviderError.unauthorized
        if let providerError = error as? ProviderError,
           case .unauthorized = providerError {
            return true
        }

        // Check for unauthorized in description
        return error.localizedDescription.lowercased().contains("unauthorized")
    }

    /// Formats error messages for user display.
    private func formatErrorMessage(_ error: Error) -> String {
        if let providerError = error as? ProviderError {
            switch providerError {
            case .unauthorized:
                return "Authentication failed. Please try logging in again."
            case let .networkError(message, _):
                if message.contains("timed out") {
                    return "Connection timed out. Please check your internet connection."
                }
                return "Network error. Please try again."
            case .tokenExpired:
                return "Session expired. Please log in again."
            case .rateLimitExceeded:
                return "Too many requests. Please try again later."
            case .serviceUnavailable:
                return "Service temporarily unavailable."
            default:
                return "Login failed. Please try again."
            }
        }

        // Check for network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                return "No internet connection."
            case .timedOut:
                return "Request timed out. Please try again."
            case .cannotFindHost, .cannotConnectToHost:
                return "Cannot connect to server."
            default:
                return "Connection error. Please try again."
            }
        }

        // Generic error
        let message = error.localizedDescription
        if message.count > 60 {
            return "Login failed. Please try again."
        }
        return message
    }

    /// Handles logout and clears session data.
    public mutating func handleLogout() {
        authState = .loggedOut
        userEmail = nil
        teamName = nil
        teamId = nil
        teamIdFetchFailed = false
        lastUpdated = Date()
        // Keep lastErrorMessage to show logout reason if needed
    }

    /// Updates user information.
    public mutating func updateUserInfo(email: String, teamName: String?, teamId: Int? = nil) {
        userEmail = email
        self.teamName = teamName
        self.teamId = teamId
        lastUpdated = Date()
    }

    /// Sets error state for team fetching.
    public mutating func setTeamFetchError(_ message: String) {
        teamIdFetchFailed = true
        lastErrorMessage = message
        lastUpdated = Date()
    }

    /// Clears error state.
    public mutating func clearError() {
        lastErrorMessage = nil
        teamIdFetchFailed = false
        lastUpdated = Date()
    }

    /// Updates only the error message without affecting other state.
    public mutating func setErrorMessage(_ message: String) {
        lastErrorMessage = message
        lastUpdated = Date()
    }
}

// MARK: - Multi-Provider User Session Data

/// Enhanced observable model for user session state across multiple providers.
///
/// This model maintains session information for all enabled providers
/// while providing backward compatibility with existing single-provider code.
@Observable
@MainActor
public final class MultiProviderUserSessionData {
    // Provider-specific session data
    public private(set) var providerSessions: [ServiceProvider: ProviderSessionState] = [:]

    public init() {}

    // MARK: - Multi-Provider Methods

    /// Updates session with successful login data for a specific provider.
    public func handleLoginSuccess(for provider: ServiceProvider, email: String, teamName: String?,
                                   teamId: Int? = nil) {
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.handleLoginSuccess(email: email, teamName: teamName, teamId: teamId)
        providerSessions[provider] = session
    }

    /// Handles login failure for a specific provider.
    public func handleLoginFailure(for provider: ServiceProvider, error: Error) {
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.handleLoginFailure(error: error)
        providerSessions[provider] = session
    }

    /// Handles logout for a specific provider.
    public func handleLogout(from provider: ServiceProvider) {
        // Completely remove the session on logout
        providerSessions.removeValue(forKey: provider)
    }

    /// Sets authenticating state for a specific provider.
    public func setAuthenticating(for provider: ServiceProvider) {
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.setAuthenticating()
        providerSessions[provider] = session
    }

    /// Updates user information for a specific provider.
    public func updateUserInfo(for provider: ServiceProvider, email: String, teamName: String?, teamId: Int? = nil) {
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.updateUserInfo(email: email, teamName: teamName, teamId: teamId)
        providerSessions[provider] = session
    }

    /// Sets team fetch error for a specific provider.
    public func setTeamFetchError(for provider: ServiceProvider, message: String) {
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.setTeamFetchError(message)
        providerSessions[provider] = session
    }

    /// Clears error for a specific provider.
    public func clearError(for provider: ServiceProvider) {
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.clearError()
        providerSessions[provider] = session
    }

    /// Sets error message for a specific provider.
    public func setErrorMessage(for provider: ServiceProvider, message: String) {
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.setErrorMessage(message)
        providerSessions[provider] = session
    }

    /// Gets session state for a specific provider.
    public func getSession(for provider: ServiceProvider) -> ProviderSessionState? {
        providerSessions[provider]
    }

    /// Checks if user is logged into a specific provider.
    public func isLoggedIn(to provider: ServiceProvider) -> Bool {
        providerSessions[provider]?.isLoggedIn ?? false
    }

    /// Gets all providers the user is logged into.
    public var loggedInProviders: [ServiceProvider] {
        providerSessions.values.filter(\.isLoggedIn).map(\.provider).sorted { $0.rawValue < $1.rawValue }
    }

    /// Gets all providers with any session data.
    public var providersWithSessions: [ServiceProvider] {
        Array(providerSessions.keys).sorted { $0.rawValue < $1.rawValue }
    }

    /// Checks if user is logged into any provider.
    public var isLoggedInToAnyProvider: Bool {
        providerSessions.values.contains { $0.isLoggedIn }
    }

    /// Gets the most recently updated provider session.
    public var mostRecentSession: ProviderSessionState? {
        providerSessions.values
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .first
    }

    /// Clears all session data.
    public func clearAllSessions() {
        providerSessions.removeAll()
    }

    /// Removes session data for a specific provider.
    public func removeSession(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }
}
