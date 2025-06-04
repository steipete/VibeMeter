import Foundation

// MARK: - Provider Health Models

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
        healthDescription: String) {
        self.provider = provider
        self.isHealthy = isHealthy
        self.circuitState = circuitState
        self.successRate = successRate
        self.totalCalls = totalCalls
        self.healthDescription = healthDescription
    }
}

/// Circuit breaker state for health monitoring.
/// Note: Circuit breaker functionality has been removed, but this enum is kept for API compatibility.
public enum CircuitBreakerState: Sendable, Equatable {
    case closed
    case open(openedAt: Date)
    case halfOpen(callsAttempted: Int)

    public var description: String {
        switch self {
        case .closed:
            "Closed"
        case .open:
            "Open"
        case let .halfOpen(calls):
            "Half-Open (\(calls) calls)"
        }
    }
}
