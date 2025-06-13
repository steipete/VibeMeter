import Foundation

// MARK: - Provider-Specific Extensions

extension NetworkRetryHandler {
    /// Creates a retry handler configured for API providers.
    static func forProvider(_ provider: ServiceProvider) -> NetworkRetryHandler {
        switch provider {
        case .cursor:
            // Cursor has aggressive rate limiting, use conservative retry
            NetworkRetryHandler(configuration: .default)
        case .claude:
            // Claude uses local files, no network retry needed
            NetworkRetryHandler(configuration: .default)
        }
    }
}
