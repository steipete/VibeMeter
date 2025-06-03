import Foundation

// MARK: - Provider Session Model

/// Represents user session data for a specific provider.
///
/// This model stores authentication and user information for individual service providers,
/// allowing the application to track login status, user details, and team information
/// across multiple connected services.
public struct ProviderSession: Codable, Sendable {
    /// The service provider this session belongs to
    public let provider: ServiceProvider

    /// Team ID for team-based providers (optional)
    public var teamId: Int?

    /// Team name for display purposes (optional)
    public var teamName: String?

    /// User's email address
    public var userEmail: String?

    /// Whether this session is currently active
    public var isActive: Bool

    /// Creates a new provider session with the specified parameters.
    ///
    /// - Parameters:
    ///   - provider: The service provider for this session
    ///   - teamId: Optional team ID for team-based services
    ///   - teamName: Optional team name for display
    ///   - userEmail: Optional user email address
    ///   - isActive: Whether the session is currently active (default: false)
    public init(
        provider: ServiceProvider,
        teamId: Int? = nil,
        teamName: String? = nil,
        userEmail: String? = nil,
        isActive: Bool = false) {
        self.provider = provider
        self.teamId = teamId
        self.teamName = teamName
        self.userEmail = userEmail
        self.isActive = isActive
    }
}

// MARK: - Session Helper Extensions

public extension ProviderSession {
    /// Returns a display name for the session, using team name or email as fallback.
    var displayName: String {
        if let teamName, !teamName.isEmpty {
            teamName
        } else if let userEmail, !userEmail.isEmpty {
            userEmail
        } else {
            provider.displayName
        }
    }

    /// Returns whether this session has complete user information.
    var hasCompleteInfo: Bool {
        guard isActive else { return false }

        if provider.supportsTeams {
            return userEmail != nil && teamId != nil && teamName != nil
        } else {
            return userEmail != nil
        }
    }
}
