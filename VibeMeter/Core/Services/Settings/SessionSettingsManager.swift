import Foundation
import os.log

/// Manages provider session settings and persistence.
///
/// This manager handles storage and retrieval of provider session data,
/// including user email, team information, and session state.
@Observable
@MainActor
public final class SessionSettingsManager {
    
    // MARK: - Properties
    
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.vibemeter", category: "SessionSettings")
    
    // MARK: - Keys
    
    private enum Keys {
        static let providerSessions = "providerSessions"
        static let enabledProviders = "enabledProviders"
    }
    
    // MARK: - Session Data
    
    /// Provider sessions mapped by service provider
    public var providerSessions: [ServiceProvider: ProviderSession] {
        didSet {
            saveProviderSessions()
            logger.info("Provider sessions updated: \(self.providerSessions.count) sessions")
            for (provider, session) in self.providerSessions {
                logger
                    .debug(
                        "  \(provider.displayName): email=\(session.userEmail ?? "none"), teamId=\(session.teamId?.description ?? "none"), active=\(session.isActive)")
            }
        }
    }
    
    /// Set of enabled service providers
    public var enabledProviders: Set<ServiceProvider> {
        didSet {
            let enabledArray = Array(enabledProviders).map(\.rawValue)
            userDefaults.set(enabledArray, forKey: Keys.enabledProviders)
            logger
                .debug("Enabled providers updated: \(self.enabledProviders.map(\.displayName).joined(separator: ", "))")
        }
    }
    
    // MARK: - Initialization
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load provider sessions
        if let sessionsData = userDefaults.data(forKey: Keys.providerSessions),
           let sessions = try? JSONDecoder().decode([ServiceProvider: ProviderSession].self, from: sessionsData) {
            self.providerSessions = sessions
        } else {
            self.providerSessions = [:]
        }
        
        // Load enabled providers
        if let enabledArray = userDefaults.array(forKey: Keys.enabledProviders) as? [String] {
            self.enabledProviders = Set(enabledArray.compactMap(ServiceProvider.init))
        } else {
            self.enabledProviders = [.cursor] // Default to Cursor enabled
        }
        
        logger.info("SessionSettingsManager initialized with \(self.providerSessions.count) provider sessions")
        for (provider, session) in providerSessions {
            logger
                .info(
                    "  \(provider.displayName): email=\(session.userEmail ?? "none"), teamId=\(session.teamId?.description ?? "none"), active=\(session.isActive)")
        }
    }
    
    // MARK: - Public Methods
    
    /// Clears all provider session data
    public func clearAllSessions() {
        logger.info("clearAllSessions called - clearing all \(self.providerSessions.count) sessions")
        
        providerSessions.removeAll()
        saveProviderSessions()
        
        logger.info("All user session data cleared")
    }
    
    /// Clears session data for a specific provider
    public func clearSession(for provider: ServiceProvider) {
        logger.info("clearSession called for \(provider.displayName)")
        
        if let session = providerSessions[provider] {
            logger
                .info(
                    "  Clearing session: email=\(session.userEmail ?? "none"), teamId=\(session.teamId?.description ?? "none")")
        } else {
            logger.info("  No existing session found for \(provider.displayName)")
        }
        
        providerSessions.removeValue(forKey: provider)
        saveProviderSessions()
        
        logger.info("User session data cleared for \(provider.displayName)")
    }
    
    /// Gets session data for a specific provider
    public func getSession(for provider: ServiceProvider) -> ProviderSession? {
        return providerSessions[provider]
    }
    
    /// Updates session data for a specific provider
    public func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        logger.info("updateSession called for \(provider.displayName)")
        logger
            .info(
                "  New session: email=\(session.userEmail ?? "none"), teamId=\(session.teamId?.description ?? "none"), active=\(session.isActive)")
        
        providerSessions[provider] = session
        saveProviderSessions()
        
        logger.info("Session successfully updated for \(provider.displayName)")
    }
    
    // MARK: - Private Methods
    
    private func saveProviderSessions() {
        logger.debug("saveProviderSessions called")
        if let sessionsData = try? JSONEncoder().encode(providerSessions) {
            userDefaults.set(sessionsData, forKey: Keys.providerSessions)
            logger.debug("Provider sessions saved to UserDefaults (\(sessionsData.count) bytes)")
        } else {
            logger.error("Failed to encode provider sessions")
        }
    }
}