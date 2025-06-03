import AppKit
import Foundation
import os.log

// MARK: - Settings Manager Protocol

/// Protocol defining the interface for managing application settings.
@MainActor
public protocol SettingsManagerProtocol: AnyObject, Sendable {
    // Multi-provider user sessions
    var providerSessions: [ServiceProvider: ProviderSession] { get set }

    // Display preferences
    var selectedCurrencyCode: String { get set }
    var refreshIntervalMinutes: Int { get set }

    // Spending limits (stored in USD)
    var warningLimitUSD: Double { get set }
    var upperLimitUSD: Double { get set }

    // App behavior
    var launchAtLoginEnabled: Bool { get set }
    var showCostInMenuBar: Bool { get set }
    var showInDock: Bool { get set }

    // Provider management
    var enabledProviders: Set<ServiceProvider> { get set }

    // Methods
    func clearUserSessionData()
    func clearUserSessionData(for provider: ServiceProvider)
    func getSession(for provider: ServiceProvider) -> ProviderSession?
    func updateSession(for provider: ServiceProvider, session: ProviderSession)
}

// MARK: - Modern Settings Manager

/// Manages persistent application settings using UserDefaults.
///
/// SettingsManager handles:
/// - User session data (team ID, team name, email)
/// - Display preferences (currency, refresh interval)
/// - Spending limits (warning and upper thresholds in USD)
/// - Application behavior settings (launch at login)
///
/// All properties are observable to enable reactive UI updates.
/// The manager follows the singleton pattern and is accessible via `SettingsManager.shared`.
@Observable
@MainActor
public final class SettingsManager: SettingsManagerProtocol {
    // MARK: - Constants

    public static let refreshIntervalOptions = [1, 2, 5, 10, 15, 30, 60]

    // Made internal for testing
    enum Keys {
        // Multi-provider keys
        static let providerSessions = "providerSessions"
        static let enabledProviders = "enabledProviders"

        // App settings
        static let selectedCurrencyCode = "selectedCurrencyCode"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let warningLimitUSD = "warningLimitUSD"
        static let upperLimitUSD = "upperLimitUSD"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let showCostInMenuBar = "showCostInMenuBar"
        static let showInDock = "showInDock"
    }

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.vibemeter", category: "Settings")
    private let startupManager: StartupControlling

    // Multi-provider sessions
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

    // Enabled providers
    public var enabledProviders: Set<ServiceProvider> {
        didSet {
            let enabledArray = Array(enabledProviders).map(\.rawValue)
            userDefaults.set(enabledArray, forKey: Keys.enabledProviders)
            logger
                .debug("Enabled providers updated: \(self.enabledProviders.map(\.displayName).joined(separator: ", "))")
        }
    }

    // Display preferences
    public var selectedCurrencyCode: String {
        didSet {
            userDefaults.set(selectedCurrencyCode, forKey: Keys.selectedCurrencyCode)
            logger.debug("Currency updated: \(self.selectedCurrencyCode)")
        }
    }

    public var refreshIntervalMinutes: Int {
        didSet {
            userDefaults.set(refreshIntervalMinutes, forKey: Keys.refreshIntervalMinutes)
            logger.debug("Refresh interval updated: \(self.refreshIntervalMinutes) minutes")
        }
    }

    // Spending limits
    public var warningLimitUSD: Double {
        didSet {
            userDefaults.set(warningLimitUSD, forKey: Keys.warningLimitUSD)
            logger.debug("Warning limit updated: $\(self.warningLimitUSD)")
        }
    }

    public var upperLimitUSD: Double {
        didSet {
            userDefaults.set(upperLimitUSD, forKey: Keys.upperLimitUSD)
            logger.debug("Upper limit updated: $\(self.upperLimitUSD)")
        }
    }

    // App behavior
    public var launchAtLoginEnabled: Bool {
        didSet {
            guard launchAtLoginEnabled != oldValue else { return }
            userDefaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)

            startupManager.setLaunchAtLogin(enabled: launchAtLoginEnabled)

            logger.debug("Launch at login: \(self.launchAtLoginEnabled)")
        }
    }

    public var showCostInMenuBar: Bool {
        didSet {
            userDefaults.set(showCostInMenuBar, forKey: Keys.showCostInMenuBar)
            logger.debug("Show cost in menu bar: \(self.showCostInMenuBar)")
        }
    }

    public var showInDock: Bool {
        didSet {
            guard showInDock != oldValue else { return }
            userDefaults.set(showInDock, forKey: Keys.showInDock)

            // Apply the dock visibility change
            if showInDock {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }

            logger.debug("Show in dock: \(self.showInDock)")
        }
    }

    // MARK: - Singleton

    public static var shared: SettingsManager {
        MainActor.assumeIsolated {
            // Return test instance if available, otherwise return the singleton
            if let testInstance {
                return testInstance
            }
            return _sharedInstance
        }
    }

    private static let _sharedInstance = MainActor.assumeIsolated {
        SettingsManager()
    }

    // MARK: - Initialization

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        startupManager = StartupManager()

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

        // Load app settings with defaults
        selectedCurrencyCode = userDefaults.string(forKey: Keys.selectedCurrencyCode) ?? "USD"
        refreshIntervalMinutes = userDefaults.object(forKey: Keys.refreshIntervalMinutes) as? Int ?? 5
        warningLimitUSD = userDefaults.object(forKey: Keys.warningLimitUSD) as? Double ?? 200.0
        upperLimitUSD = userDefaults.object(forKey: Keys.upperLimitUSD) as? Double ?? 1000.0
        launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled)
        showCostInMenuBar = userDefaults
            .object(forKey: Keys.showCostInMenuBar) as? Bool ?? false // Default to false (icon-only)
        showInDock = userDefaults.object(forKey: Keys.showInDock) as? Bool ?? false // Default to false (menu bar only)

        // Validate refresh interval
        if !Self.refreshIntervalOptions.contains(refreshIntervalMinutes) {
            refreshIntervalMinutes = 5
        }

        logger.info("SettingsManager initialized with \(self.providerSessions.count) provider sessions")
        for (provider, session) in providerSessions {
            logger
                .info(
                    "  \(provider.displayName): email=\(session.userEmail ?? "none"), teamId=\(session.teamId?.description ?? "none"), active=\(session.isActive)")
        }
    }

    // For testing
    init(userDefaults: UserDefaults, startupManager: StartupControlling) {
        self.userDefaults = userDefaults
        self.startupManager = startupManager

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

        // Load with defaults
        selectedCurrencyCode = userDefaults.string(forKey: Keys.selectedCurrencyCode) ?? "USD"
        refreshIntervalMinutes = userDefaults.object(forKey: Keys.refreshIntervalMinutes) as? Int ?? 5
        warningLimitUSD = userDefaults.object(forKey: Keys.warningLimitUSD) as? Double ?? 200.0
        upperLimitUSD = userDefaults.object(forKey: Keys.upperLimitUSD) as? Double ?? 1000.0
        launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled)
        showCostInMenuBar = userDefaults.object(forKey: Keys.showCostInMenuBar) as? Bool ?? false
        showInDock = userDefaults.object(forKey: Keys.showInDock) as? Bool ?? false
    }

    // MARK: - Public Methods

    public func clearUserSessionData() {
        logger.info("clearUserSessionData called - clearing all \(self.providerSessions.count) sessions")

        // Clear all provider sessions
        providerSessions.removeAll()
        saveProviderSessions()

        logger.info("All user session data cleared")
    }

    public func clearUserSessionData(for provider: ServiceProvider) {
        logger.info("clearUserSessionData called for \(provider.displayName)")

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

    public func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }

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

    // MARK: - Testing Support

    private static var testInstance: SettingsManager?

    static func _test_setSharedInstance(userDefaults: UserDefaults, startupManager: StartupControlling) {
        testInstance = SettingsManager(userDefaults: userDefaults, startupManager: startupManager)
    }

    static func _test_clearSharedInstance() {
        testInstance = nil
    }
}
