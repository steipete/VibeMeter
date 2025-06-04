import Foundation
import os.log

/// Circuit breaker pattern implementation for preventing cascade failures.
///
/// The circuit breaker monitors failures and automatically opens to prevent
/// unnecessary calls to failing services, then gradually allows limited requests
/// to test if the service has recovered.
actor CircuitBreaker {
    // MARK: - Configuration
    
    struct Configuration {
        let failureThreshold: Int
        let openTimeout: TimeInterval
        let halfOpenMaxCalls: Int
        let slidingWindowSize: Int
    }
    
    // MARK: - Static Configuration
    
    static let defaultConfig = Configuration(
        failureThreshold: 5,
        openTimeout: 60.0,
        halfOpenMaxCalls: 3,
        slidingWindowSize: 10
    )
    
    static let conservativeConfig = Configuration(
        failureThreshold: 3,
        openTimeout: 120.0,
        halfOpenMaxCalls: 2,
        slidingWindowSize: 8
    )
    
    static let aggressiveConfig = Configuration(
        failureThreshold: 8,
        openTimeout: 30.0,
        halfOpenMaxCalls: 5,
        slidingWindowSize: 15
    )
    
    // MARK: - State
    
    enum State: Equatable {
        case closed
        case open(openedAt: Date)
        case halfOpen(callsAttempted: Int)
        
        var description: String {
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
    
    // MARK: - Error Types
    
    enum CircuitBreakerError: Error, LocalizedError {
        case circuitOpen
        case halfOpenLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .circuitOpen:
                return "Circuit breaker is open - service may be unavailable"
            case .halfOpenLimitExceeded:
                return "Circuit breaker half-open limit exceeded"
            }
        }
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private let logger: Logger
    private var state: State = .closed
    private var failureCount = 0
    private var successCount = 0
    private var recentResults: [Bool] = [] // true = success, false = failure
    
    // MARK: - Initialization
    
    init(configuration: Configuration = CircuitBreaker.defaultConfig, subsystem: String = "com.vibemeter", category: String = "CircuitBreaker") {
        self.configuration = configuration
        self.logger = Logger(subsystem: subsystem, category: category)
    }
    
    // MARK: - Public Methods
    
    /// Executes an operation through the circuit breaker.
    ///
    /// - Parameter operation: The async operation to execute
    /// - Returns: The result of the operation if successful
    /// - Throws: CircuitBreakerError if the circuit is open, or the original error from the operation
    func execute<Result: Sendable>(
        operation: @escaping () async throws -> Result
    ) async throws -> Result {
        try await executeInternal {
            try await operation()
        }
    }
    
    /// Executes an operation that returns an optional value through the circuit breaker.
    func executeOptional<Result: Sendable>(
        operation: @escaping () async throws -> Result?
    ) async throws -> Result? {
        try await executeInternal {
            try await operation()
        }
    }
    
    /// Gets the current state of the circuit breaker.
    func getCurrentState() -> State {
        state
    }
    
    /// Gets circuit breaker statistics.
    func getStatistics() -> Statistics {
        let totalCalls = recentResults.count
        let recentSuccesses = recentResults.filter { $0 }.count
        let successRate = totalCalls > 0 ? Double(recentSuccesses) / Double(totalCalls) : 0.0
        
        return Statistics(
            state: state,
            totalFailures: failureCount,
            totalSuccesses: successCount,
            recentSuccessRate: successRate,
            recentCalls: totalCalls
        )
    }
    
    /// Manually resets the circuit breaker to closed state.
    func reset() {
        logger.info("Circuit breaker manually reset")
        state = .closed
        failureCount = 0
        successCount = 0
        recentResults.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func executeInternal<Result: Sendable>(
        operation: @escaping () async throws -> Result
    ) async throws -> Result {
        // Check if we can execute based on current state
        try checkStateBeforeExecution()
        
        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }
    
    private func checkStateBeforeExecution() throws {
        switch state {
        case .closed:
            // Normal operation
            break
            
        case .open(let openedAt):
            let now = Date()
            let timeSinceOpened = now.timeIntervalSince(openedAt)
            
            if timeSinceOpened >= configuration.openTimeout {
                // Transition to half-open
                logger.info("Circuit breaker transitioning from open to half-open")
                state = .halfOpen(callsAttempted: 0)
            } else {
                logger.debug("Circuit breaker is open, rejecting call")
                throw CircuitBreakerError.circuitOpen
            }
            
        case .halfOpen(let callsAttempted):
            if callsAttempted >= configuration.halfOpenMaxCalls {
                logger.warning("Circuit breaker half-open limit exceeded")
                throw CircuitBreakerError.halfOpenLimitExceeded
            }
            
            // Increment calls attempted
            state = .halfOpen(callsAttempted: callsAttempted + 1)
        }
    }
    
    private func recordSuccess() {
        successCount += 1
        recentResults.append(true)
        trimSlidingWindow()
        
        switch state {
        case .closed:
            // Normal operation continues
            break
            
        case .open:
            // This shouldn't happen as open circuit should block calls
            logger.warning("Unexpected success while circuit is open")
            break
            
        case .halfOpen(let callsAttempted):
            logger.info("Circuit breaker half-open success (\(callsAttempted) calls)")
            
            // If we've had enough successful calls, close the circuit
            if callsAttempted >= configuration.halfOpenMaxCalls {
                logger.info("Circuit breaker closing after successful half-open period")
                state = .closed
                failureCount = 0 // Reset failure count on successful recovery
            }
        }
        
        logger.debug("Circuit breaker recorded success. State: \(self.state.description)")
    }
    
    private func recordFailure() {
        failureCount += 1
        recentResults.append(false)
        trimSlidingWindow()
        
        switch state {
        case .closed:
            // Check if we should open the circuit
            if shouldOpenCircuit() {
                logger.warning("Circuit breaker opening due to failure threshold")
                state = .open(openedAt: Date())
            }
            
        case .open:
            // Circuit is already open, failure expected
            break
            
        case .halfOpen:
            // Failure during half-open period - go back to open
            logger.warning("Circuit breaker reopening due to failure during half-open period")
            state = .open(openedAt: Date())
        }
        
        logger.debug("Circuit breaker recorded failure. State: \(self.state.description), Failures: \(self.failureCount)")
    }
    
    private func shouldOpenCircuit() -> Bool {
        // Simple threshold-based approach
        guard failureCount >= configuration.failureThreshold else {
            return false
        }
        
        // Check sliding window failure rate if we have enough data
        guard recentResults.count >= configuration.slidingWindowSize / 2 else {
            return true // Open if we don't have enough data but hit failure threshold
        }
        
        let recentFailures = recentResults.suffix(configuration.slidingWindowSize).filter { !$0 }.count
        let failureRate = Double(recentFailures) / Double(min(recentResults.count, configuration.slidingWindowSize))
        
        // Open if failure rate is above 50%
        return failureRate > 0.5
    }
    
    private func trimSlidingWindow() {
        if recentResults.count > configuration.slidingWindowSize {
            recentResults.removeFirst(recentResults.count - configuration.slidingWindowSize)
        }
    }
}

// MARK: - Statistics

extension CircuitBreaker {
    struct Statistics: Sendable {
        let state: State
        let totalFailures: Int
        let totalSuccesses: Int
        let recentSuccessRate: Double
        let recentCalls: Int
        
        var isHealthy: Bool {
            switch state {
            case .closed:
                return recentSuccessRate > 0.8 || recentCalls == 0
            case .open:
                return false
            case .halfOpen:
                return recentSuccessRate > 0.5
            }
        }
        
        var healthDescription: String {
            switch state {
            case .closed:
                if recentCalls == 0 {
                    return "No recent activity"
                } else if recentSuccessRate > 0.9 {
                    return "Excellent"
                } else if recentSuccessRate > 0.7 {
                    return "Good"
                } else {
                    return "Degraded"
                }
            case .open:
                return "Service Unavailable"
            case .halfOpen:
                return "Testing Recovery"
            }
        }
    }
}

// MARK: - Provider-Specific Factory

extension CircuitBreaker {
    /// Creates a circuit breaker configured for a specific service provider.
    static func forProvider(_ provider: ServiceProvider) -> CircuitBreaker {
        switch provider {
        case .cursor:
            // Cursor API can be flaky, use conservative settings
            return CircuitBreaker(
                configuration: CircuitBreaker.conservativeConfig,
                category: "CircuitBreaker-Cursor"
            )
        }
    }
}