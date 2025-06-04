import Foundation
import os.log

/// Enhanced error recovery manager providing user-friendly error handling and recovery suggestions.
///
/// This manager analyzes errors, provides contextual recovery suggestions, and implements
/// automatic recovery strategies where appropriate.
public struct ErrorRecoveryManager {
    private let logger = Logger(subsystem: "com.vibemeter", category: "ErrorRecovery")
    
    // MARK: - Error Analysis
    
    /// Analyzes an error and provides recovery information.
    public func analyzeError(_ error: Error, context: ErrorContext) -> ErrorRecoveryInfo {
        logger.debug("Analyzing error: \(error.localizedDescription)")
        
        // Check for specific error types first
        if let providerError = error as? ProviderError {
            return analyzeProviderError(providerError, context: context)
        }
        
        if let circuitBreakerError = error as? CircuitBreaker.CircuitBreakerError {
            return analyzeCircuitBreakerError(circuitBreakerError, context: context)
        }
        
        if let retryableError = error as? NetworkRetryHandler.RetryableError {
            return analyzeRetryableError(retryableError, context: context)
        }
        
        if let urlError = error as? URLError {
            return analyzeURLError(urlError, context: context)
        }
        
        // Default analysis for unknown errors
        return ErrorRecoveryInfo(
            severity: .moderate,
            category: .unknown,
            userMessage: "An unexpected error occurred",
            technicalMessage: error.localizedDescription,
            suggestions: [.contactSupport],
            isRetryable: false,
            estimatedRecoveryTime: nil
        )
    }
    
    // MARK: - Provider Error Analysis
    
    private func analyzeProviderError(_ error: ProviderError, context: ErrorContext) -> ErrorRecoveryInfo {
        switch error {
        case .unauthorized:
            return ErrorRecoveryInfo(
                severity: .high,
                category: .authentication,
                userMessage: "Your session has expired",
                technicalMessage: "Authentication token is invalid or expired",
                suggestions: [.reAuthenticate, .checkAccountStatus],
                isRetryable: false,
                estimatedRecoveryTime: nil
            )
            
        case .noTeamFound:
            return ErrorRecoveryInfo(
                severity: .high,
                category: .configuration,
                userMessage: "No team found for your account",
                technicalMessage: "User account is not associated with any team",
                suggestions: [.checkAccountSetup, .contactSupport],
                isRetryable: false,
                estimatedRecoveryTime: nil
            )
            
        case .teamIdNotSet:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .configuration,
                userMessage: "Account setup incomplete",
                technicalMessage: "Team ID is not configured",
                suggestions: [.reAuthenticate, .checkAccountSetup],
                isRetryable: false,
                estimatedRecoveryTime: nil
            )
            
        case .rateLimitExceeded:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .rateLimiting,
                userMessage: "Too many requests - please wait before trying again",
                technicalMessage: "API rate limit exceeded",
                suggestions: [.waitAndRetry(minutes: 5), .reduceRefreshFrequency],
                isRetryable: true,
                estimatedRecoveryTime: 300 // 5 minutes
            )
            
        case .serviceUnavailable:
            return ErrorRecoveryInfo(
                severity: .high,
                category: .serviceHealth,
                userMessage: "Service is temporarily unavailable",
                technicalMessage: "Remote service returned 503 Service Unavailable",
                suggestions: [.waitAndRetry(minutes: 10), .checkServiceStatus],
                isRetryable: true,
                estimatedRecoveryTime: 600 // 10 minutes
            )
            
        case let .networkError(message, statusCode):
            return analyzeNetworkError(message: message, statusCode: statusCode, context: context)
            
        case let .decodingError(message, _):
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .dataProcessing,
                userMessage: "Received unexpected data format",
                technicalMessage: "Data decoding failed: \(message)",
                suggestions: [.retryLater, .checkAppUpdate],
                isRetryable: true,
                estimatedRecoveryTime: 60
            )
            
        case let .authenticationFailed(reason):
            return ErrorRecoveryInfo(
                severity: .high,
                category: .authentication,
                userMessage: "Login failed",
                technicalMessage: "Authentication failed: \(reason)",
                suggestions: [.reAuthenticate, .checkCredentials],
                isRetryable: false,
                estimatedRecoveryTime: nil
            )
            
        case .tokenExpired:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .authentication,
                userMessage: "Your session has expired",
                technicalMessage: "Authentication token has expired",
                suggestions: [.reAuthenticate],
                isRetryable: false,
                estimatedRecoveryTime: nil
            )
            
        case let .unsupportedProvider(provider):
            return ErrorRecoveryInfo(
                severity: .low,
                category: .configuration,
                userMessage: "Provider not supported",
                technicalMessage: "Provider \(provider.displayName) is not supported",
                suggestions: [.checkAppUpdate],
                isRetryable: false,
                estimatedRecoveryTime: nil
            )
        }
    }
    
    // MARK: - Network Error Analysis
    
    private func analyzeNetworkError(message: String, statusCode: Int?, context: ErrorContext) -> ErrorRecoveryInfo {
        guard let statusCode else {
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .network,
                userMessage: "Network connection failed",
                technicalMessage: message,
                suggestions: [.checkConnection, .retryLater],
                isRetryable: true,
                estimatedRecoveryTime: 30
            )
        }
        
        switch statusCode {
        case 400...499:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .client,
                userMessage: "Request failed due to client error",
                technicalMessage: "HTTP \(statusCode): \(message)",
                suggestions: [.reAuthenticate, .checkAppUpdate],
                isRetryable: false,
                estimatedRecoveryTime: nil
            )
            
        case 500...599:
            return ErrorRecoveryInfo(
                severity: .high,
                category: .serviceHealth,
                userMessage: "Server error - please try again later",
                technicalMessage: "HTTP \(statusCode): \(message)",
                suggestions: [.waitAndRetry(minutes: 5), .checkServiceStatus],
                isRetryable: true,
                estimatedRecoveryTime: 300
            )
            
        default:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .network,
                userMessage: "Unexpected server response",
                technicalMessage: "HTTP \(statusCode): \(message)",
                suggestions: [.retryLater, .contactSupport],
                isRetryable: true,
                estimatedRecoveryTime: 60
            )
        }
    }
    
    // MARK: - Circuit Breaker Error Analysis
    
    private func analyzeCircuitBreakerError(_ error: CircuitBreaker.CircuitBreakerError, context: ErrorContext) -> ErrorRecoveryInfo {
        switch error {
        case .circuitOpen:
            return ErrorRecoveryInfo(
                severity: .high,
                category: .serviceHealth,
                userMessage: "Service is experiencing issues",
                technicalMessage: "Circuit breaker is open - too many recent failures",
                suggestions: [.waitAndRetry(minutes: 2), .checkServiceStatus],
                isRetryable: true,
                estimatedRecoveryTime: 120
            )
            
        case .halfOpenLimitExceeded:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .serviceHealth,
                userMessage: "Service recovery in progress",
                technicalMessage: "Circuit breaker is testing service recovery",
                suggestions: [.waitAndRetry(minutes: 1)],
                isRetryable: true,
                estimatedRecoveryTime: 60
            )
        }
    }
    
    // MARK: - URL Error Analysis
    
    private func analyzeURLError(_ error: URLError, context: ErrorContext) -> ErrorRecoveryInfo {
        switch error.code {
        case .notConnectedToInternet:
            return ErrorRecoveryInfo(
                severity: .high,
                category: .network,
                userMessage: "No internet connection",
                technicalMessage: "Device is not connected to the internet",
                suggestions: [.checkConnection, .checkWiFi],
                isRetryable: true,
                estimatedRecoveryTime: nil
            )
            
        case .timedOut:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .network,
                userMessage: "Request timed out",
                technicalMessage: "Network request timed out",
                suggestions: [.checkConnection, .retryLater],
                isRetryable: true,
                estimatedRecoveryTime: 30
            )
            
        case .cannotFindHost, .cannotConnectToHost:
            return ErrorRecoveryInfo(
                severity: .high,
                category: .network,
                userMessage: "Cannot reach server",
                technicalMessage: "Cannot connect to remote server",
                suggestions: [.checkConnection, .checkServiceStatus],
                isRetryable: true,
                estimatedRecoveryTime: 60
            )
            
        case .networkConnectionLost:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .network,
                userMessage: "Connection lost during request",
                technicalMessage: "Network connection was lost",
                suggestions: [.checkConnection, .retryNow],
                isRetryable: true,
                estimatedRecoveryTime: 10
            )
            
        default:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .network,
                userMessage: "Network error occurred",
                technicalMessage: error.localizedDescription,
                suggestions: [.checkConnection, .retryLater],
                isRetryable: true,
                estimatedRecoveryTime: 30
            )
        }
    }
    
    // MARK: - Retryable Error Analysis
    
    private func analyzeRetryableError(_ error: NetworkRetryHandler.RetryableError, context: ErrorContext) -> ErrorRecoveryInfo {
        switch error {
        case .networkTimeout:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .network,
                userMessage: "Request timed out",
                technicalMessage: "Network request timed out",
                suggestions: [.checkConnection, .retryLater],
                isRetryable: true,
                estimatedRecoveryTime: 30
            )
            
        case .connectionError:
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .network,
                userMessage: "Connection failed",
                technicalMessage: "Failed to establish network connection",
                suggestions: [.checkConnection, .retryLater],
                isRetryable: true,
                estimatedRecoveryTime: 30
            )
            
        case let .rateLimited(retryAfter):
            let waitTime = retryAfter ?? 300
            return ErrorRecoveryInfo(
                severity: .moderate,
                category: .rateLimiting,
                userMessage: "Rate limit exceeded",
                technicalMessage: "Too many requests - rate limited",
                suggestions: [.waitAndRetry(minutes: Int(waitTime / 60))],
                isRetryable: true,
                estimatedRecoveryTime: waitTime
            )
            
        case let .serverError(statusCode):
            return ErrorRecoveryInfo(
                severity: .high,
                category: .serviceHealth,
                userMessage: "Server error occurred",
                technicalMessage: "Server returned error \(statusCode)",
                suggestions: [.waitAndRetry(minutes: 5), .checkServiceStatus],
                isRetryable: true,
                estimatedRecoveryTime: 300
            )
        }
    }
}

// MARK: - Error Recovery Models

/// Context information for error analysis.
public struct ErrorContext: Sendable {
    let provider: ServiceProvider
    let operation: String
    let attemptCount: Int
    let lastSuccessTime: Date?
    
    public init(provider: ServiceProvider, operation: String, attemptCount: Int = 1, lastSuccessTime: Date? = nil) {
        self.provider = provider
        self.operation = operation
        self.attemptCount = attemptCount
        self.lastSuccessTime = lastSuccessTime
    }
}

/// Comprehensive error recovery information.
public struct ErrorRecoveryInfo: Sendable {
    let severity: Severity
    let category: Category
    let userMessage: String
    let technicalMessage: String
    let suggestions: [RecoverySuggestion]
    let isRetryable: Bool
    let estimatedRecoveryTime: TimeInterval? // seconds
    
    public enum Severity: Sendable {
        case low
        case moderate
        case high
        case critical
        
        var description: String {
            switch self {
            case .low: return "Low"
            case .moderate: return "Moderate"
            case .high: return "High"  
            case .critical: return "Critical"
            }
        }
    }
    
    public enum Category: Sendable {
        case authentication
        case network
        case serviceHealth
        case rateLimiting
        case configuration
        case dataProcessing
        case client
        case unknown
        
        var description: String {
            switch self {
            case .authentication: return "Authentication"
            case .network: return "Network"
            case .serviceHealth: return "Service Health"
            case .rateLimiting: return "Rate Limiting"
            case .configuration: return "Configuration"
            case .dataProcessing: return "Data Processing"
            case .client: return "Client Error"
            case .unknown: return "Unknown"
            }
        }
    }
    
    public enum RecoverySuggestion: Sendable, Equatable {
        case retryNow
        case retryLater
        case waitAndRetry(minutes: Int)
        case reAuthenticate
        case checkConnection
        case checkWiFi
        case checkServiceStatus
        case checkAccountStatus
        case checkAccountSetup
        case checkCredentials
        case checkAppUpdate
        case reduceRefreshFrequency
        case contactSupport
        
        var description: String {
            switch self {
            case .retryNow:
                return "Try again now"
            case .retryLater:
                return "Try again in a few minutes"
            case .waitAndRetry(let minutes):
                return "Wait \(minutes) minute\(minutes == 1 ? "" : "s") and try again"
            case .reAuthenticate:
                return "Sign in again"
            case .checkConnection:
                return "Check your internet connection"
            case .checkWiFi:
                return "Check your Wi-Fi connection"
            case .checkServiceStatus:
                return "Check service status"
            case .checkAccountStatus:
                return "Check your account status"
            case .checkAccountSetup:
                return "Verify your account setup"
            case .checkCredentials:
                return "Check your login credentials"
            case .checkAppUpdate:
                return "Check for app updates"
            case .reduceRefreshFrequency:
                return "Reduce refresh frequency"
            case .contactSupport:
                return "Contact support if the problem persists"
            }
        }
        
        var isActionable: Bool {
            switch self {
            case .retryNow, .reAuthenticate, .checkConnection, .checkWiFi, .checkAppUpdate:
                return true
            default:
                return false
            }
        }
    }
}