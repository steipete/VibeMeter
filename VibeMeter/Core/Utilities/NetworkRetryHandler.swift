import Foundation
import os.log

/// Handles network request retries with exponential backoff strategy.
///
/// This utility provides a robust retry mechanism for network operations,
/// implementing exponential backoff with jitter to avoid thundering herd problems.
actor NetworkRetryHandler {
    // MARK: - Configuration

    struct Configuration {
        let maxRetries: Int
        let initialDelay: TimeInterval
        let maxDelay: TimeInterval
        let multiplier: Double
        let jitterFactor: Double

        static let `default` = Configuration(
            maxRetries: 3,
            initialDelay: 1.0,
            maxDelay: 30.0,
            multiplier: 2.0,
            jitterFactor: 0.1)

        static let aggressive = Configuration(
            maxRetries: 5,
            initialDelay: 0.5,
            maxDelay: 60.0,
            multiplier: 1.5,
            jitterFactor: 0.2)
    }

    // MARK: - Types

    enum RetryableError: Error, Equatable {
        case networkTimeout
        case serverError(statusCode: Int)
        case connectionError
        case rateLimited(retryAfter: TimeInterval?)
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let logger = Logger.vibeMeter(category: "NetworkRetry")

    // MARK: - Initialization

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Public Methods

    /// Executes an async operation with retry logic.
    ///
    /// - Parameters:
    ///   - operation: The async operation to execute
    ///   - shouldRetry: Optional closure to determine if an error is retryable
    /// - Returns: The result of the successful operation
    /// - Throws: The last error if all retries are exhausted
    func execute<T>(
        operation: @escaping () async throws -> T,
        shouldRetry: ((Error) -> Bool)? = nil) async throws -> T where T: Sendable {
        var lastError: Error?

        for attempt in 0 ... self.configuration.maxRetries {
            do {
                logger.debug("Attempting operation (attempt \(attempt + 1)/\(self.configuration.maxRetries + 1))")
                return try await operation()
            } catch {
                lastError = error

                // Check if we should retry
                let isRetryable = shouldRetry?(error) ?? isDefaultRetryable(error)

                guard isRetryable, attempt < self.configuration.maxRetries else {
                    logger.error("Operation failed after \(attempt + 1) attempts: \(error.localizedDescription)")
                    throw error
                }

                // Calculate delay with exponential backoff
                let delay = calculateDelay(for: attempt, error: error)
                logger.warning("Operation failed, retrying after \(delay)s: \(error.localizedDescription)")

                // Wait before retrying
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw lastError ?? URLError(.unknown)
    }

    /// Executes an async operation that returns an optional value with retry logic.
    func executeOptional<T>(
        operation: @escaping () async throws -> T?,
        shouldRetry: ((Error) -> Bool)? = nil) async throws -> T? where T: Sendable {
        try await execute(operation: operation, shouldRetry: shouldRetry)
    }

    // MARK: - Private Methods

    private func calculateDelay(for attempt: Int, error: Error) -> TimeInterval {
        // Check for rate limit headers
        if case let .rateLimited(retryAfter) = error as? RetryableError,
           let retryAfter {
            return min(retryAfter, self.configuration.maxDelay)
        }

        // Calculate exponential backoff
        let exponentialDelay = self.configuration.initialDelay * pow(self.configuration.multiplier, Double(attempt))
        let clampedDelay = min(exponentialDelay, self.configuration.maxDelay)

        // Add jitter to prevent thundering herd
        let jitter = clampedDelay * self.configuration.jitterFactor
        let jitterRange = -jitter ... jitter
        let randomJitter = Double.random(in: jitterRange)

        return max(0, clampedDelay + randomJitter)
    }

    private func isDefaultRetryable(_ error: Error) -> Bool {
        // URL errors that are typically retryable
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .dnsLookupFailed,
                 .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        // Custom retryable errors
        if let retryableError = error as? RetryableError {
            switch retryableError {
            case .networkTimeout, .connectionError, .rateLimited:
                return true
            case let .serverError(statusCode):
                // Retry 5xx errors but not 4xx
                return statusCode >= 500
            }
        }

        // Check for common network-related NSErrors
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorNotConnectedToInternet,
            ].contains(nsError.code)
        }

        return false
    }
}
