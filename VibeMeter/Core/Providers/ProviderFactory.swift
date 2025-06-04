import Foundation
import os.log

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
