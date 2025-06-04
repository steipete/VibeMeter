import Foundation
import os.log

/// Manages error handling, retry logic, and resilience patterns for Cursor API operations.
///
/// This manager encapsulates circuit breaker patterns, retry logic with exponential backoff,
/// and error classification specific to Cursor AI service interactions.
actor CursorResilienceManager {
    
    // MARK: - Properties
    
    private let circuitBreaker = CircuitBreaker.forProvider(.cursor)
    private let errorRecoveryManager = ErrorRecoveryManager()
    private let logger = Logger(subsystem: "com.vibemeter", category: "CursorResilienceManager")
    
    // MARK: - Public Methods
    
    /// Executes an operation with retry logic and circuit breaker protection.
    func executeWithResilience<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        // Use circuit breaker with retry logic for full resilience
        return try await circuitBreaker.execute { @Sendable in
            try await self.executeWithRetry(operation)
        }
    }
    
    /// Gets the current health status of the Cursor provider.
    func getHealthStatus() async -> ProviderHealthStatus {
        let stats = await circuitBreaker.getStatistics()
        let state = convertCircuitBreakerState(stats.state)
        
        return ProviderHealthStatus(
            provider: .cursor,
            isHealthy: stats.isHealthy,
            circuitState: state,
            successRate: stats.recentSuccessRate,
            totalCalls: stats.recentCalls,
            healthDescription: stats.healthDescription
        )
    }
    
    /// Manually resets the circuit breaker for recovery scenarios.
    func resetCircuitBreaker() async {
        await circuitBreaker.reset()
        logger.info("Circuit breaker manually reset for Cursor provider")
    }
    
    // MARK: - Private Methods
    
    private func executeWithRetry<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        var lastError: Error?
        let maxRetries = 3
        
        for attempt in 0...maxRetries {
            do {
                logger.debug("Executing operation (attempt \(attempt + 1)/\(maxRetries + 1))")
                return try await operation()
            } catch {
                lastError = error
                
                // Check if we should retry
                let shouldRetry = shouldRetryError(error)
                
                guard shouldRetry, attempt < maxRetries else {
                    logger.error("Operation failed after \(attempt + 1) attempts: \(error.localizedDescription)")
                    throw error
                }
                
                // Calculate delay with exponential backoff
                let delay = calculateRetryDelay(for: attempt, error: error)
                logger.warning("Operation failed, retrying after \(delay)s: \(error.localizedDescription)")
                
                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        throw lastError ?? URLError(.unknown)
    }
    
    private func shouldRetryError(_ error: Error) -> Bool {
        // Don't retry authentication or team not found errors
        switch error {
        case ProviderError.unauthorized, ProviderError.noTeamFound:
            return false
        case let providerError as ProviderError:
            // Don't retry client errors (4xx)
            if case let .networkError(_, statusCode) = providerError,
               let code = statusCode,
               code >= 400, code < 500 {
                return false
            }
            return true
        case is NetworkRetryHandler.RetryableError:
            return true
        case let urlError as URLError:
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .dnsLookupFailed,
                 .notConnectedToInternet:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
    
    private func calculateRetryDelay(for attempt: Int, error: Error) -> TimeInterval {
        // Check for rate limit headers
        if case let .rateLimited(retryAfter) = error as? NetworkRetryHandler.RetryableError,
           let retryAfter {
            return min(retryAfter, 30.0)
        }
        
        // Calculate exponential backoff
        let initialDelay = 1.0
        let multiplier = 2.0
        let exponentialDelay = initialDelay * pow(multiplier, Double(attempt))
        let clampedDelay = min(exponentialDelay, 30.0)
        
        // Add jitter to prevent thundering herd
        let jitter = clampedDelay * 0.1
        let jitterRange = -jitter ... jitter
        let randomJitter = Double.random(in: jitterRange)
        
        return max(0, clampedDelay + randomJitter)
    }
    
    /// Converts internal circuit breaker state to public API state.
    private func convertCircuitBreakerState(_ state: CircuitBreaker.State) -> CircuitBreakerState {
        switch state {
        case .closed:
            return .closed
        case .open(let openedAt):
            return .open(openedAt: openedAt)
        case .halfOpen(let callsAttempted):
            return .halfOpen(callsAttempted: callsAttempted)
        }
    }
}