import Foundation

// MARK: - Error Extensions

extension Error {
    /// Converts common errors to retryable errors for better handling.
    var asRetryableError: NetworkRetryHandler.RetryableError? {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut:
                return .networkTimeout
            case .cannotFindHost, .cannotConnectToHost, .networkConnectionLost:
                return .connectionError
            default:
                return nil
            }
        }

        return nil
    }
}
