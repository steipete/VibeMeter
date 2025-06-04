import SwiftUI

/// Represents the connection status of a service provider.
///
/// This enum captures all possible states a provider connection can be in,
/// from disconnected to various error states, with appropriate visual representations.
public enum ProviderConnectionStatus: Equatable, Codable, Sendable {
    case disconnected // Not logged in
    case connecting // Currently authenticating
    case connected // Authenticated and working
    case syncing // Fetching data
    case error(message: String) // Connection/API error (simplified for Codable)
    case rateLimited(until: Date?) // Rate limited with retry time
    case stale // Data is old (haven't refreshed in a while)

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
        case let .error(message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        case let .rateLimited(until):
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
            .gray
        case .connecting, .syncing:
            .blue
        case .connected:
            .green
        case .error:
            .red
        case .rateLimited:
            .orange
        case .stale:
            .yellow
        }
    }

    /// SF Symbol name for the status.
    public var iconName: String {
        switch self {
        case .disconnected:
            "circle"
        case .connecting, .syncing:
            "arrow.2.circlepath"
        case .connected:
            "checkmark.circle.fill"
        case .error:
            "exclamationmark.triangle.fill"
        case .rateLimited:
            "clock.fill"
        case .stale:
            "exclamationmark.circle"
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
        case let .error(message):
            return userFriendlyError(from: message)
        case let .rateLimited(until):
            if let until, until > Date() {
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
            "Offline"
        case .connecting:
            "Connecting"
        case .syncing:
            "Syncing"
        case .connected:
            "Online"
        case .error:
            "Error"
        case .rateLimited:
            "Limited"
        case .stale:
            "Stale"
        }
    }

    /// Whether this status indicates an active operation.
    public var isActive: Bool {
        switch self {
        case .connecting, .syncing:
            true
        default:
            false
        }
    }

    /// Whether this status indicates a problem.
    public var isError: Bool {
        switch self {
        case .error, .rateLimited, .stale:
            true
        default:
            false
        }
    }

    // MARK: - Private Helpers

    private func userFriendlyError(from message: String) -> String {
        // Handle empty or whitespace-only messages
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedMessage.isEmpty {
            return "Something went wrong"
        }

        let lowercasedMessage = trimmedMessage.lowercased()

        // Authentication errors
        if lowercasedMessage.contains("unauthorized") ||
            lowercasedMessage.contains("authentication") ||
            lowercasedMessage.contains("auth") {
            return "Authentication required"
        }

        // Rate limit errors
        if lowercasedMessage.contains("rate limit") ||
            lowercasedMessage.contains("too many requests") ||
            lowercasedMessage.contains("rate_limited") {
            return "Too many requests"
        }

        // Server errors
        if lowercasedMessage.contains("internal server error") ||
            lowercasedMessage.contains("500") ||
            lowercasedMessage.contains("service unavailable") {
            return "Service unavailable"
        }

        // Network/connection errors
        if lowercasedMessage.contains("network") ||
            lowercasedMessage.contains("connection") {
            return "Connection failed"
        }

        // Timeout errors
        if lowercasedMessage.contains("timeout") ||
            lowercasedMessage.contains("timed out") {
            return "Request timed out"
        }

        // Team-specific errors
        if lowercasedMessage.contains("team not found") {
            return "Team not found"
        }

        // Generic/unknown errors
        if lowercasedMessage.contains("unknown error") ||
            lowercasedMessage.contains("unexpected response") ||
            lowercasedMessage.contains("something went wrong") {
            return "Something went wrong"
        }

        // Fallback for any other error - truncate long messages
        if trimmedMessage.count > 50 {
            return String(trimmedMessage.prefix(50))
        }

        // If message doesn't match known patterns, default to generic message
        return "Something went wrong"
    }
}

// MARK: - Convenience Factory Methods

extension ProviderConnectionStatus {
    /// Creates an error status from a ProviderError.
    public static func from(_ error: ProviderError) -> ProviderConnectionStatus {
        switch error {
        case .unauthorized:
            .disconnected
        case .rateLimitExceeded:
            .rateLimited(until: nil)
        case let .networkError(message, _):
            .error(message: message)
        case .noTeamFound:
            .error(message: "Team not found")
        case .teamIdNotSet:
            .error(message: "Team not configured")
        case .serviceUnavailable:
            .stale
        case let .decodingError(message, _):
            .error(message: "Data error: \(message)")
        case let .unsupportedProvider(provider):
            .error(message: "Unsupported provider: \(provider.displayName)")
        case .authenticationFailed:
            .disconnected
        case .tokenExpired:
            .disconnected
        }
    }

    /// Creates a rate limited status from a NetworkRetryHandler error.
    static func from(_ error: NetworkRetryHandler.RetryableError) -> ProviderConnectionStatus? {
        switch error {
        case let .rateLimited(retryAfter):
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
