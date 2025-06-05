import Foundation

/// Constants for Cursor API integration.
///
/// This file centralizes all API-related constants used throughout the application,
/// ensuring consistency and making it easier to update endpoints if the API changes.
public enum CursorAPIConstants {
    
    // MARK: - Base URLs
    
    /// Base URL for all Cursor API endpoints.
    /// - Note: All API endpoints are constructed by appending paths to this base URL.
    public static let apiBaseURL = URL(string: "https://www.cursor.com/api")!
    
    /// Authentication URL where users log in to Cursor.
    /// - Note: This is the web-based authentication page, not an API endpoint.
    public static let authenticationURL = URL(string: "https://authenticator.cursor.sh/")!
    
    // MARK: - API Endpoints
    
    /// API endpoint paths relative to the base URL.
    public enum Endpoints {
        /// Teams endpoint - Fetches user's team information.
        /// - Method: POST
        /// - Response: List of teams the user belongs to
        public static let teams = "dashboard/teams"
        
        /// User info endpoint - Fetches authenticated user's information.
        /// - Method: GET
        /// - Response: User email and optional team ID
        public static let userInfo = "auth/me"
        
        /// Monthly invoice endpoint - Fetches spending data for a specific month.
        /// - Method: POST
        /// - Body: `{"month": Int, "year": Int, "teamId": Int?, "includeUsageEvents": Bool}`
        /// - Response: Invoice items and pricing description
        public static let monthlyInvoice = "dashboard/get-monthly-invoice"
        
        /// Usage data endpoint - Fetches current month's API usage statistics.
        /// - Method: GET
        /// - Query: `?user={userId}`
        /// - Response: Usage statistics per model (GPT-3.5, GPT-4, etc.)
        public static let usage = "usage"
    }
    
    // MARK: - Full URL Construction
    
    /// Constructs full URLs for specific endpoints.
    public enum URLs {
        /// Full URL for teams endpoint: https://www.cursor.com/api/dashboard/teams
        public static let teams = apiBaseURL.appendingPathComponent(Endpoints.teams)
        
        /// Full URL for user info endpoint: https://www.cursor.com/api/auth/me
        public static let userInfo = apiBaseURL.appendingPathComponent(Endpoints.userInfo)
        
        /// Full URL for monthly invoice endpoint: https://www.cursor.com/api/dashboard/get-monthly-invoice
        public static let monthlyInvoice = apiBaseURL.appendingPathComponent(Endpoints.monthlyInvoice)
        
        /// Full URL for usage endpoint: https://www.cursor.com/api/usage
        public static let usage = apiBaseURL.appendingPathComponent(Endpoints.usage)
    }
    
    // MARK: - Headers
    
    /// HTTP header constants used in API requests.
    public enum Headers {
        /// Cookie name for the authentication token.
        /// - Note: Cursor uses cookie-based authentication instead of Bearer tokens.
        public static let sessionCookieName = "WorkosCursorSessionToken"
        
        /// User agent string identifying this application.
        public static let userAgent = "VibeMeter/1.0"
        
        /// Referer header required by some Cursor API endpoints.
        public static let referer = "https://www.cursor.com"
        
        /// Content type for JSON requests.
        public static let contentTypeJSON = "application/json"
        
        /// Accept header for JSON responses.
        public static let acceptJSON = "application/json"
        
        /// Default timeout interval for API requests (in seconds).
        public static let defaultTimeout: TimeInterval = 30.0
    }
    
    // MARK: - Response Constants
    
    /// Constants used in API responses and data transformation.
    public enum ResponseConstants {
        /// Fallback team ID used when user has no team.
        /// - Note: -1 indicates no valid team (0 might be misinterpreted as valid).
        public static let individualUserTeamId = -1
        
        /// Fallback team name for users without a team.
        public static let individualUserTeamName = "Individual"
        
        /// Minimum valid team ID. Team IDs less than or equal to 0 are considered invalid.
        public static let minimumValidTeamId = 1
    }
    
    // MARK: - Error Messages
    
    /// Standard error messages used throughout the application.
    public enum ErrorMessages {
        /// Error message when a team is not found.
        public static let teamNotFound = "Team not found"
        
        /// Error message for invalid response type.
        public static let invalidResponseType = "Invalid response type"
        
        /// Error message when response data is empty.
        public static let emptyResponseData = "Received empty response data"
        
        /// Error message when API endpoint is not found.
        public static let apiEndpointNotFound = "API endpoint not found - the endpoint may have been moved or deprecated"
        
        /// Error message when URL construction fails.
        public static let failedToConstructURL = "Failed to construct usage URL"
    }
    
    // MARK: - Helper Methods
    
    /// Constructs a full URL for an API endpoint.
    /// - Parameter endpoint: The endpoint path relative to the base URL
    /// - Returns: The complete URL for the endpoint
    public static func apiURL(for endpoint: String) -> URL {
        apiBaseURL.appendingPathComponent(endpoint)
    }
    
    /// Creates a cookie header value from an authentication token.
    /// - Parameter authToken: The authentication token
    /// - Returns: A properly formatted cookie header value
    public static func cookieHeader(for authToken: String) -> String {
        "\(Headers.sessionCookieName)=\(authToken)"
    }
    
    /// Checks if a team ID is valid (not a fallback or invalid value).
    /// - Parameter teamId: The team ID to validate
    /// - Returns: `true` if the team ID is valid, `false` otherwise
    public static func isValidTeamId(_ teamId: Int?) -> Bool {
        guard let teamId = teamId else { return false }
        return teamId >= ResponseConstants.minimumValidTeamId
    }
}

// MARK: - Sendable Conformance

extension CursorAPIConstants: Sendable {}