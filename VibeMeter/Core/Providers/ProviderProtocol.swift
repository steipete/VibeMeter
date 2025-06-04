import Foundation
import os.log

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

// MARK: - Provider Factory

/// Factory for creating provider instances based on service type.
///
/// The ProviderFactory centralizes provider instantiation and ensures
/// that each provider is properly configured with required dependencies.
public final class ProviderFactory: @unchecked Sendable {
    private let settingsManager: any SettingsManagerProtocol
    private let urlSession: URLSessionProtocol
    private let logger = Logger(subsystem: "com.vibemeter", category: "ProviderFactory")

    public init(
        settingsManager: any SettingsManagerProtocol,
        urlSession: URLSessionProtocol = URLSession.shared) {
        self.settingsManager = settingsManager
        self.urlSession = urlSession
    }

    /// Creates a provider instance for the specified service.
    /// - Parameter provider: The service provider to create
    /// - Returns: Configured provider instance
    public func createProvider(for provider: ServiceProvider) -> ProviderProtocol {
        switch provider {
        case .cursor:
            CursorProvider(
                settingsManager: settingsManager,
                urlSession: urlSession)
        }
    }

    /// Creates provider instances for all enabled services.
    /// - Returns: Dictionary of configured provider instances for all enabled services
    @MainActor
    public func createEnabledProviders() -> [ServiceProvider: ProviderProtocol] {
        let enabledProviders = ProviderRegistry.shared.activeProviders
        var providers: [ServiceProvider: ProviderProtocol] = [:]

        for provider in enabledProviders {
            providers[provider] = createProvider(for: provider)
        }

        return providers
    }
}

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

// MARK: - Generic Data Models

/// Generic team information that works across all providers.
public struct ProviderTeamInfo: Equatable, Sendable, Codable {
    public let id: Int
    public let name: String
    public let provider: ServiceProvider

    public init(id: Int, name: String, provider: ServiceProvider) {
        self.id = id
        self.name = name
        self.provider = provider
    }
}

/// Generic user information that works across all providers.
public struct ProviderUserInfo: Equatable, Sendable, Codable {
    public let email: String
    public let teamId: Int?
    public let provider: ServiceProvider

    public init(email: String, teamId: Int? = nil, provider: ServiceProvider) {
        self.email = email
        self.teamId = teamId
        self.provider = provider
    }
}

/// Generic monthly invoice that works across all providers.
public struct ProviderMonthlyInvoice: Equatable, Sendable, Codable {
    public let items: [ProviderInvoiceItem]
    public let pricingDescription: ProviderPricingDescription?
    public let provider: ServiceProvider
    public let month: Int
    public let year: Int

    public var totalSpendingCents: Int {
        items.reduce(0) { $0 + $1.cents }
    }

    public init(
        items: [ProviderInvoiceItem],
        pricingDescription: ProviderPricingDescription? = nil,
        provider: ServiceProvider,
        month: Int,
        year: Int) {
        self.items = items
        self.pricingDescription = pricingDescription
        self.provider = provider
        self.month = month
        self.year = year
    }
}

/// Generic invoice item that works across all providers.
public struct ProviderInvoiceItem: Codable, Equatable, Sendable {
    public let cents: Int
    public let description: String
    public let provider: ServiceProvider

    public init(cents: Int, description: String, provider: ServiceProvider) {
        self.cents = cents
        self.description = description
        self.provider = provider
    }
}

/// Generic pricing description that works across all providers.
public struct ProviderPricingDescription: Codable, Equatable, Sendable {
    public let description: String
    public let id: String
    public let provider: ServiceProvider

    public init(description: String, id: String, provider: ServiceProvider) {
        self.description = description
        self.id = id
        self.provider = provider
    }
}

/// Generic usage data that works across all providers.
public struct ProviderUsageData: Codable, Equatable, Sendable {
    public let currentRequests: Int
    public let totalRequests: Int
    public let maxRequests: Int?
    public let startOfMonth: Date
    public let provider: ServiceProvider

    public init(
        currentRequests: Int,
        totalRequests: Int,
        maxRequests: Int? = nil,
        startOfMonth: Date,
        provider: ServiceProvider) {
        self.currentRequests = currentRequests
        self.totalRequests = totalRequests
        self.maxRequests = maxRequests
        self.startOfMonth = startOfMonth
        self.provider = provider
    }
}

/// Provider health status for resilience monitoring.
public struct ProviderHealthStatus: Sendable {
    public let provider: ServiceProvider
    public let isHealthy: Bool
    public let circuitState: CircuitBreakerState
    public let successRate: Double
    public let totalCalls: Int
    public let healthDescription: String
    
    public init(
        provider: ServiceProvider,
        isHealthy: Bool,
        circuitState: CircuitBreakerState,
        successRate: Double,
        totalCalls: Int,
        healthDescription: String
    ) {
        self.provider = provider
        self.isHealthy = isHealthy
        self.circuitState = circuitState
        self.successRate = successRate
        self.totalCalls = totalCalls
        self.healthDescription = healthDescription
    }
}

/// Circuit breaker state for health monitoring.
public enum CircuitBreakerState: Sendable, Equatable {
    case closed
    case open(openedAt: Date)
    case halfOpen(callsAttempted: Int)
    
    public var description: String {
        switch self {
        case .closed:
            return "Closed"
        case .open:
            return "Open"
        case .halfOpen(let calls):
            return "Half-Open (\(calls) calls)"
        }
    }
}
