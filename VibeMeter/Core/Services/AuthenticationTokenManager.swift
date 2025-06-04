import Foundation
import os.log

/// Manages authentication tokens and keychain operations for service providers.
final class AuthenticationTokenManager: @unchecked Sendable {
    // MARK: - Private Properties

    private let keychainHelpers: [ServiceProvider: KeychainServicing]
    private let logger = Logger(subsystem: "com.vibemeter", category: "AuthTokenManager")

    // MARK: - Initialization

    init() {
        self.keychainHelpers = Self.createKeychainHelpers()
    }

    // For testing purposes
    init(keychainHelpers: [ServiceProvider: KeychainServicing]) {
        self.keychainHelpers = keychainHelpers
    }

    // MARK: - Public Methods

    /// Gets authentication token for a specific provider.
    func getAuthToken(for provider: ServiceProvider) -> String? {
        keychainHelpers[provider]?.getToken()
    }

    /// Gets authentication cookies for a specific provider.
    func getCookies(for provider: ServiceProvider) -> [HTTPCookie]? {
        guard let token = getAuthToken(for: provider) else { return nil }

        var cookieProperties = [HTTPCookiePropertyKey: Any]()
        cookieProperties[.name] = provider.authCookieName
        cookieProperties[.value] = token
        cookieProperties[.domain] = provider.cookieDomain
        cookieProperties[.path] = "/"
        cookieProperties[.secure] = true
        cookieProperties[.expires] = Date(timeIntervalSinceNow: 3600 * 24 * 30) // 30 days

        guard let cookie = HTTPCookie(properties: cookieProperties) else { return nil }
        return [cookie]
    }

    /// Saves authentication token for a provider.
    func saveToken(_ token: String, for provider: ServiceProvider) -> Bool {
        guard let keychain = keychainHelpers[provider] else {
            logger.error("No keychain helper found for \(provider.displayName)")
            return false
        }

        let success = keychain.saveToken(token)
        if success {
            logger.info("Auth token saved for \(provider.displayName)")
        } else {
            logger.error("Failed to save auth token for \(provider.displayName)")
        }
        return success
    }

    /// Deletes authentication token for a provider.
    func deleteToken(for provider: ServiceProvider) -> Bool {
        guard let keychain = keychainHelpers[provider] else {
            logger.error("No keychain helper found for \(provider.displayName)")
            return false
        }

        let success = keychain.deleteToken()
        if success {
            logger.info("Auth token deleted for \(provider.displayName)")
        } else {
            logger.error("Failed to delete auth token for \(provider.displayName)")
        }
        return success
    }

    /// Checks if token exists for a provider.
    func hasToken(for provider: ServiceProvider) -> Bool {
        getAuthToken(for: provider) != nil
    }

    // MARK: - Private Methods

    private static func createKeychainHelpers() -> [ServiceProvider: KeychainServicing] {
        var helpers: [ServiceProvider: KeychainServicing] = [:]
        let logger = Logger(subsystem: "com.vibemeter", category: "AuthTokenManager")

        for provider in ServiceProvider.allCases {
            let keychain = KeychainHelper(service: provider.keychainService)
            helpers[provider] = keychain
            let hasToken = keychain.getToken() != nil
            let keychainInfo = "Keychain check for \(provider.displayName): " +
                "service=\(provider.keychainService), hasToken=\(hasToken)"
            logger.debug(keychainInfo)
        }

        return helpers
    }
}
