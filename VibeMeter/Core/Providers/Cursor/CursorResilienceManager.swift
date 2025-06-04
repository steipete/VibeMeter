import Foundation
import os.log

/// Manages error handling and retry logic for Cursor API operations.
///
/// This manager encapsulates retry logic with exponential backoff
/// and error classification specific to Cursor AI service interactions.
actor CursorResilienceManager {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.vibemeter", category: "CursorResilienceManager")

    // MARK: - Public Methods

    /// Executes an operation with retry logic.
    func executeWithResilience<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await executeWithRetry(operation)
    }

    /// Gets the current health status of the Cursor provider.
    func getHealthStatus() async -> ProviderHealthStatus {
        // Return a simple healthy status without circuit breaker
        return ProviderHealthStatus(
            provider: .cursor,
            isHealthy: true,
            circuitState: .closed,
            successRate: 1.0,
            totalCalls: 0,
            healthDescription: "Operating normally")
    }

    /// Manually resets the circuit breaker for recovery scenarios.
    func resetCircuitBreaker() async {
        // No-op since circuit breaker is removed
        logger.info("Circuit breaker reset requested (no-op)")
    }

    // MARK: - Private Methods

    private func executeWithRetry<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async throws
        -> T {
        var lastError: Error?
        let maxRetries = 3

        for attempt in 0 ... maxRetries {
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
            // Don't retry decoding errors with 204 status (indicates expired session)
            if case let .decodingError(_, statusCode) = providerError,
               statusCode == 204 {
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
}