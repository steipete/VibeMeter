import Foundation
import SwiftUI

// MARK: - Provider Session State

/// Represents the session state for a specific provider.
public struct ProviderSessionState: Codable, Sendable {
    public let provider: ServiceProvider
    public var isLoggedIn: Bool
    public var userEmail: String?
    public var teamName: String?
    public var teamId: Int?
    public var lastErrorMessage: String?
    public var teamIdFetchFailed: Bool
    public var lastUpdated: Date

    public init(
        provider: ServiceProvider,
        isLoggedIn: Bool = false,
        userEmail: String? = nil,
        teamName: String? = nil,
        teamId: Int? = nil,
        lastErrorMessage: String? = nil,
        teamIdFetchFailed: Bool = false,
        lastUpdated: Date = Date()) {
        self.provider = provider
        self.isLoggedIn = isLoggedIn
        self.userEmail = userEmail
        self.teamName = teamName
        self.teamId = teamId
        self.lastErrorMessage = lastErrorMessage
        self.teamIdFetchFailed = teamIdFetchFailed
        self.lastUpdated = lastUpdated
    }

    /// Updates session with successful login data.
    public mutating func handleLoginSuccess(email: String, teamName: String?, teamId: Int? = nil) {
        isLoggedIn = true
        userEmail = email
        self.teamName = teamName
        self.teamId = teamId
        lastErrorMessage = nil
        teamIdFetchFailed = false
        lastUpdated = Date()
    }

    /// Handles login failure with error message.
    public mutating func handleLoginFailure(error: Error) {
        if error.localizedDescription.contains("logged out") {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = "Login failed or cancelled."
        }
        handleLogout()
    }

    /// Handles logout and clears session data.
    public mutating func handleLogout() {
        isLoggedIn = false
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
        var session = providerSessions[provider] ?? ProviderSessionState(provider: provider)
        session.handleLogout()
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
