import SwiftUI

/// Represents the connection status of a service provider.
///
/// This enum captures all possible states a provider connection can be in,
/// from disconnected to various error states, with appropriate visual representations.
public enum ProviderConnectionStatus: Equatable, Codable, Sendable {
    case disconnected           // Not logged in
    case connecting            // Currently authenticating
    case connected            // Authenticated and working
    case syncing             // Fetching data
    case error(message: String) // Connection/API error (simplified for Codable)
    case rateLimited(until: Date?) // Rate limited with retry time
    case stale               // Data is old (haven't refreshed in a while)
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case type
        case message
        case until
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "disconnected":
            self = .disconnected
        case "connecting":
            self = .connecting
        case "connected":
            self = .connected
        case "syncing":
            self = .syncing
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case "rateLimited":
            let until = try container.decodeIfPresent(Date.self, forKey: .until)
            self = .rateLimited(until: until)
        case "stale":
            self = .stale
        default:
            self = .disconnected
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .disconnected:
            try container.encode("disconnected", forKey: .type)
        case .connecting:
            try container.encode("connecting", forKey: .type)
        case .connected:
            try container.encode("connected", forKey: .type)
        case .syncing:
            try container.encode("syncing", forKey: .type)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        case .rateLimited(let until):
            try container.encode("rateLimited", forKey: .type)
            try container.encodeIfPresent(until, forKey: .until)
        case .stale:
            try container.encode("stale", forKey: .type)
        }
    }
    
    // MARK: - Display Properties
    
    /// Color representing the status.
    public var displayColor: Color {
        switch self {
        case .disconnected:
            return .gray
        case .connecting, .syncing:
            return .blue
        case .connected:
            return .green
        case .error:
            return .red
        case .rateLimited:
            return .orange
        case .stale:
            return .yellow
        }
    }
    
    /// SF Symbol name for the status.
    public var iconName: String {
        switch self {
        case .disconnected:
            return "circle"
        case .connecting, .syncing:
            return "arrow.2.circlepath"
        case .connected:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .rateLimited:
            return "clock.fill"
        case .stale:
            return "exclamationmark.circle"
        }
    }
    
    /// Human-readable description of the status.
    public var description: String {
        switch self {
        case .disconnected:
            return "Not connected"
        case .connecting:
            return "Connecting..."
        case .syncing:
            return "Updating..."
        case .connected:
            return "Connected"
        case .error(let message):
            return userFriendlyError(from: message)
        case .rateLimited(let until):
            if let until {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Rate limited \(formatter.localizedString(for: until, relativeTo: Date()))"
            }
            return "Rate limited"
        case .stale:
            return "Data may be outdated"
        }
    }
    
    /// Short description for compact displays.
    public var shortDescription: String {
        switch self {
        case .disconnected:
            return "Offline"
        case .connecting:
            return "Connecting"
        case .syncing:
            return "Syncing"
        case .connected:
            return "Online"
        case .error:
            return "Error"
        case .rateLimited:
            return "Limited"
        case .stale:
            return "Stale"
        }
    }
    
    /// Whether this status indicates an active operation.
    public var isActive: Bool {
        switch self {
        case .connecting, .syncing:
            return true
        default:
            return false
        }
    }
    
    /// Whether this status indicates a problem.
    public var isError: Bool {
        switch self {
        case .error, .rateLimited, .stale:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private func userFriendlyError(from message: String) -> String {
        // Convert technical errors to user-friendly messages
        if message.lowercased().contains("network") || message.lowercased().contains("connection") {
            return "Connection failed"
        } else if message.lowercased().contains("unauthorized") || message.lowercased().contains("auth") {
            return "Authentication failed"
        } else if message.lowercased().contains("timeout") {
            return "Request timed out"
        } else if message.lowercased().contains("team not found") {
            return "Team not found"
        } else {
            // Truncate long error messages
            return String(message.prefix(50))
        }
    }
}

// MARK: - Convenience Factory Methods

extension ProviderConnectionStatus {
    /// Creates an error status from a ProviderError.
    public static func from(_ error: ProviderError) -> ProviderConnectionStatus {
        switch error {
        case .unauthorized:
            return .error(message: "Authentication failed")
        case .rateLimitExceeded:
            return .rateLimited(until: nil)
        case .networkError(let message, _):
            return .error(message: message)
        case .noTeamFound:
            return .error(message: "Team not found")
        case .teamIdNotSet:
            return .error(message: "Team not configured")
        case .serviceUnavailable:
            return .error(message: "Service unavailable")
        case .decodingError(let message, _):
            return .error(message: "Data error: \(message)")
        case .unsupportedProvider(let provider):
            return .error(message: "Unsupported provider: \(provider.displayName)")
        case .authenticationFailed(let reason):
            return .error(message: "Authentication failed: \(reason)")
        case .tokenExpired:
            return .error(message: "Token expired")
        }
    }
    
    /// Creates a rate limited status from a NetworkRetryHandler error.
    static func from(_ error: NetworkRetryHandler.RetryableError) -> ProviderConnectionStatus? {
        switch error {
        case .rateLimited(let retryAfter):
            let until = retryAfter.map { Date(timeIntervalSinceNow: $0) }
            return .rateLimited(until: until)
        case .serverError:
            return .error(message: "Server error")
        case .networkTimeout:
            return .error(message: "Request timed out")
        case .connectionError:
            return .error(message: "Connection failed")
        }
    }
}