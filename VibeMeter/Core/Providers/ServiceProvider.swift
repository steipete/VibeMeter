import Foundation
import os.log

// MARK: - Service Provider Enumeration

/// Enumeration of supported cost tracking service providers.
///
/// This enum defines all services that VibeMeter can track spending for.
/// Each provider has unique authentication methods, API endpoints, and data structures.
public enum ServiceProvider: String, CaseIterable, Codable, Sendable {
    case cursor
    // Future providers can be added here:
    // case openai = "openai"
    // case anthropic = "anthropic"
    // case github = "github"

    /// Human-readable display name for the provider.
    public var displayName: String {
        switch self {
        case .cursor:
            "Cursor"
        }
    }

    /// Provider's primary website URL.
    public var websiteURL: URL {
        switch self {
        case .cursor:
            URL(string: "https://cursor.com")!
        }
    }

    /// Authentication URL for the provider's OAuth/login flow.
    public var authenticationURL: URL {
        switch self {
        case .cursor:
            URL(string: "https://authenticator.cursor.sh/")!
        }
    }

    /// Base API URL for the provider's REST API.
    public var baseAPIURL: URL {
        switch self {
        case .cursor:
            URL(string: "https://www.cursor.com/api")!
        }
    }

    /// Cookie domain used for authentication token storage.
    public var cookieDomain: String {
        switch self {
        case .cursor:
            ".cursor.com"
        }
    }

    /// Name of the authentication cookie/token.
    public var authCookieName: String {
        switch self {
        case .cursor:
            "WorkosCursorSessionToken"
        }
    }

    /// Keychain service identifier for secure token storage.
    public var keychainService: String {
        switch self {
        case .cursor:
            "com.vibemeter.cursor"
        }
    }

    /// Default currency used by the provider (for billing).
    public var defaultCurrency: String {
        switch self {
        case .cursor:
            "USD" // Cursor bills in USD
        }
    }

    /// Whether this provider supports team-based billing.
    public var supportsTeams: Bool {
        switch self {
        case .cursor:
            true
        }
    }

    /// Icon name for displaying in UI (SF Symbols or custom).
    public var iconName: String {
        switch self {
        case .cursor:
            "cursor"
        }
    }

    /// Primary brand color for UI theming.
    public var brandColor: String {
        switch self {
        case .cursor:
            "#000000" // Cursor's black theme
        }
    }
}

// MARK: - Provider Configuration

/// Configuration container for provider-specific settings.
///
/// This structure holds all the necessary configuration for a specific provider,
/// including authentication details, API endpoints, and provider-specific preferences.
public struct ProviderConfiguration: Codable, Sendable {
    public let provider: ServiceProvider
    public let isEnabled: Bool
    public let customSettings: [String: String] // Provider-specific settings

    public init(provider: ServiceProvider, isEnabled: Bool = true, customSettings: [String: String] = [:]) {
        self.provider = provider
        self.isEnabled = isEnabled
        self.customSettings = customSettings
    }
}

// MARK: - Provider Registry

/// Central registry for managing multiple service providers simultaneously.
///
/// The ProviderRegistry maintains the list of available providers and manages
/// provider-specific configurations. Unlike a traditional "current provider" model,
/// this supports multi-tenancy where users can be logged into multiple services
/// simultaneously (e.g., Cursor, Anthropic, OpenAI all at once).
@MainActor
public final class ProviderRegistry: ObservableObject {
    // MARK: - Published Properties

    @Published
    public private(set) var availableProviders: [ServiceProvider]
    @Published
    public private(set) var providerConfigurations: [ServiceProvider: ProviderConfiguration]
    @Published
    public private(set) var enabledProviders: Set<ServiceProvider>

    // MARK: - Private Properties

    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.vibemeter", category: "ProviderRegistry")

    // MARK: - Constants

    private enum Keys {
        static let enabledProviders = "enabledProviders"
        static let providerConfigurations = "providerConfigurations"
    }

    // MARK: - Singleton

    public static let shared = ProviderRegistry()

    // MARK: - Initialization

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Load available providers (currently only Cursor, but ready for more)
        self.availableProviders = ServiceProvider.allCases

        // Load enabled providers from settings, default to Cursor only
        if let savedEnabledRaw = userDefaults.array(forKey: Keys.enabledProviders) as? [String] {
            self.enabledProviders = Set(savedEnabledRaw.compactMap(ServiceProvider.init))
        } else {
            self.enabledProviders = [.cursor] // Default to Cursor enabled
        }

        // Load provider configurations
        if let configData = userDefaults.data(forKey: Keys.providerConfigurations),
           let configs = try? JSONDecoder().decode([ServiceProvider: ProviderConfiguration].self, from: configData) {
            self.providerConfigurations = configs
        } else {
            // Initialize with default configurations
            self.providerConfigurations = [:]
            for provider in availableProviders {
                let isEnabled = enabledProviders.contains(provider)
                self.providerConfigurations[provider] = ProviderConfiguration(provider: provider, isEnabled: isEnabled)
            }
        }

        logger
            .info(
                "ProviderRegistry initialized with enabled providers: \(self.enabledProviders.map(\.displayName).joined(separator: ", "))")
    }

    // MARK: - Public Methods

    /// Enables a service provider for multi-tenancy tracking.
    public func enableProvider(_ provider: ServiceProvider) {
        guard availableProviders.contains(provider) else {
            logger.error("Attempted to enable unavailable provider: \(provider.rawValue)")
            return
        }

        enabledProviders.insert(provider)
        updateProviderConfiguration(provider, isEnabled: true)
        saveEnabledProviders()

        logger.info("Enabled provider: \(provider.displayName)")
    }

    /// Disables a service provider (user will be logged out).
    public func disableProvider(_ provider: ServiceProvider) {
        enabledProviders.remove(provider)
        updateProviderConfiguration(provider, isEnabled: false)
        saveEnabledProviders()

        logger.info("Disabled provider: \(provider.displayName)")
    }

    /// Updates configuration for a specific provider.
    public func updateConfiguration(_ configuration: ProviderConfiguration) {
        providerConfigurations[configuration.provider] = configuration
        saveConfigurations()

        logger.debug("Updated configuration for provider: \(configuration.provider.displayName)")
    }

    /// Gets configuration for a specific provider.
    public func configuration(for provider: ServiceProvider) -> ProviderConfiguration {
        providerConfigurations[provider] ?? ProviderConfiguration(provider: provider)
    }

    /// Checks if a provider is currently enabled.
    public func isEnabled(_ provider: ServiceProvider) -> Bool {
        enabledProviders.contains(provider)
    }

    /// Gets all providers that are currently enabled for tracking.
    public var activeProviders: [ServiceProvider] {
        availableProviders.filter { isEnabled($0) }
    }

    // MARK: - Private Methods

    private func updateProviderConfiguration(_ provider: ServiceProvider, isEnabled: Bool) {
        var config = configuration(for: provider)
        config = ProviderConfiguration(
            provider: provider,
            isEnabled: isEnabled,
            customSettings: config.customSettings)
        providerConfigurations[provider] = config
        saveConfigurations()
    }

    private func saveEnabledProviders() {
        let enabledRaw = enabledProviders.map(\.rawValue)
        userDefaults.set(enabledRaw, forKey: Keys.enabledProviders)
    }

    private func saveConfigurations() {
        if let configData = try? JSONEncoder().encode(providerConfigurations) {
            userDefaults.set(configData, forKey: Keys.providerConfigurations)
        }
    }
}

// MARK: - Extensions

extension ServiceProvider: Identifiable {
    public var id: String { rawValue }
}

extension ServiceProvider: CustomStringConvertible {
    public var description: String { displayName }
}
