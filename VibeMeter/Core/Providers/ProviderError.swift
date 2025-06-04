import Foundation

// MARK: - Provider Error Types

/// Errors that can occur across all providers.
///
/// While providers may have their own specific errors, these common errors
/// provide a standardized way to handle authentication and network issues.
public enum ProviderError: Error, Equatable, LocalizedError {
    case networkError(message: String, statusCode: Int?)
    case decodingError(message: String, statusCode: Int?)
    case noTeamFound
    case teamIdNotSet
    case unauthorized
    case unsupportedProvider(ServiceProvider)
    case authenticationFailed(reason: String)
    case tokenExpired
    case rateLimitExceeded
    case serviceUnavailable

    public var errorDescription: String? {
        switch self {
        case let .networkError(message, statusCode):
            if let statusCode {
                return "Network error (status \(statusCode)): \(message)"
            }
            return "Network error: \(message)"
        case let .decodingError(message, statusCode):
            if let statusCode {
                return "Decoding error (status \(statusCode)): \(message)"
            }
            return "Decoding error: \(message)"
        case .noTeamFound:
            return "No team found for this account"
        case .teamIdNotSet:
            return "Team ID not configured"
        case .unauthorized:
            return "Unauthorized - please log in again"
        case let .unsupportedProvider(provider):
            return "Provider \(provider.displayName) is not supported"
        case let .authenticationFailed(reason):
            return "Authentication failed: \(reason)"
        case .tokenExpired:
            return "Authentication token has expired"
        case .rateLimitExceeded:
            return "Rate limit exceeded - please try again later"
        case .serviceUnavailable:
            return "Service is temporarily unavailable"
        }
    }
}
