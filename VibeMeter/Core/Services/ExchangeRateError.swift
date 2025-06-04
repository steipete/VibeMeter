import Foundation

// MARK: - Exchange Rate Error

/// Custom error type for exchange rate operations.
///
/// This enum provides structured error handling for exchange rate API interactions, including
/// invalid responses, and HTTP errors with descriptive error messages.
enum ExchangeRateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid API URL"
        case .invalidResponse:
            "Invalid response from exchange rate API"
        case let .httpError(statusCode):
            "HTTP error: \(statusCode)"
        }
    }
}