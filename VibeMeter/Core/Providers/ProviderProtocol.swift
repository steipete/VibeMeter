import Foundation

// MARK: - Provider Protocol

/// Generic protocol for all service provider integrations.
///
/// This protocol defines the common interface that all service providers must implement.
/// It abstracts away provider-specific details while maintaining a consistent API
/// for authentication, data fetching, and user management.
public protocol ProviderProtocol: Sendable {
    /// The service provider this instance represents.
    var provider: ServiceProvider { get }

    /// Fetches team/organization information for the authenticated user.
    /// - Parameter authToken: Authentication token for the provider
    /// - Returns: Team information including ID and name
    func fetchTeamInfo(authToken: String) async throws -> ProviderTeamInfo

    /// Fetches user account information.
    /// - Parameter authToken: Authentication token for the provider
    /// - Returns: User information including email and team association
    func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo

    /// Fetches monthly usage/billing information.
    /// - Parameters:
    ///   - authToken: Authentication token for the provider
    ///   - month: Month (0-11, 0-based indexing)
    ///   - year: Full year (e.g., 2023)
    ///   - teamId: Team ID for the request (optional, for providers that support teams)
    /// - Returns: Monthly invoice with itemized costs
    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int, teamId: Int?) async throws
    -> ProviderMonthlyInvoice

    /// Fetches current usage statistics and quotas.
    /// - Parameter authToken: Authentication token for the provider
    /// - Returns: Usage information including requests, quotas, and tokens
    func fetchUsageData(authToken: String) async throws -> ProviderUsageData

    /// Validates that an authentication token is still valid.
    /// - Parameter authToken: Authentication token to validate
    /// - Returns: True if token is valid, false otherwise
    func validateToken(authToken: String) async -> Bool

    /// Gets the authentication URL for this provider's OAuth flow.
    /// - Returns: URL to initiate authentication
    func getAuthenticationURL() -> URL

    /// Extracts authentication token from provider-specific callback data.
    /// - Parameter callbackData: Provider-specific callback information
    /// - Returns: Extracted authentication token, if available
    func extractAuthToken(from callbackData: [String: Any]) -> String?
}
