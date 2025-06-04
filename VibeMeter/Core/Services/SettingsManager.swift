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
    var menuBarDisplayMode: MenuBarDisplayMode { get set }
    var showInDock: Bool { get set }
    var updateChannel: UpdateChannel { get set }

    // Provider management
    var enabledProviders: Set<ServiceProvider> { get set }

    // Methods
    func clearUserSessionData()
    func clearUserSessionData(for provider: ServiceProvider)
    func getSession(for provider: ServiceProvider) -> ProviderSession?
    func updateSession(for provider: ServiceProvider, session: ProviderSession)
}

// MARK: - Modern Settings Manager

/// Manages persistent application settings using focused component managers.
///
/// SettingsManager coordinates between specialized managers for:
/// - Session management (provider sessions and authentication state)
/// - Display preferences (currency, refresh interval, menu bar mode)
/// - Spending limits (warning and upper thresholds in USD)
/// - App behavior (launch at login, dock visibility)
///
/// All properties are observable to enable reactive UI updates.
/// The manager follows the singleton pattern and is accessible via `SettingsManager.shared`.
@Observable
@MainActor
public final class SettingsManager: SettingsManagerProtocol {
    // MARK: - Constants

    public static let refreshIntervalOptions = DisplaySettingsManager.refreshIntervalOptions

    // MARK: - Component Managers

    private let sessionManager: SessionSettingsManager
    private let displayManager: DisplaySettingsManager
    private let limitsManager: SpendingLimitsManager
    private let behaviorManager: AppBehaviorSettingsManager

    private let logger = Logger(subsystem: "com.vibemeter", category: "Settings")

    // MARK: - Delegated Properties

    // Multi-provider sessions
    public var providerSessions: [ServiceProvider: ProviderSession] {
        get { sessionManager.providerSessions }
        set { sessionManager.providerSessions = newValue }
    }

    // Enabled providers
    public var enabledProviders: Set<ServiceProvider> {
        get { sessionManager.enabledProviders }
        set { sessionManager.enabledProviders = newValue }
    }

    // Display preferences
    public var selectedCurrencyCode: String {
        get { displayManager.selectedCurrencyCode }
        set { displayManager.selectedCurrencyCode = newValue }
    }

    public var refreshIntervalMinutes: Int {
        get { displayManager.refreshIntervalMinutes }
        set { displayManager.refreshIntervalMinutes = newValue }
    }

    public var menuBarDisplayMode: MenuBarDisplayMode {
        get { displayManager.menuBarDisplayMode }
        set { displayManager.menuBarDisplayMode = newValue }
    }

    // Spending limits
    public var warningLimitUSD: Double {
        get { limitsManager.warningLimitUSD }
        set { limitsManager.warningLimitUSD = newValue }
    }

    public var upperLimitUSD: Double {
        get { limitsManager.upperLimitUSD }
        set { limitsManager.upperLimitUSD = newValue }
    }

    // App behavior
    public var launchAtLoginEnabled: Bool {
        get { behaviorManager.launchAtLoginEnabled }
        set { behaviorManager.launchAtLoginEnabled = newValue }
    }

    public var showInDock: Bool {
        get { behaviorManager.showInDock }
        set { behaviorManager.showInDock = newValue }
    }

    public var updateChannel: UpdateChannel {
        get { behaviorManager.updateChannel }
        set { behaviorManager.updateChannel = newValue }
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
        self.sessionManager = SessionSettingsManager(userDefaults: userDefaults)
        self.displayManager = DisplaySettingsManager(userDefaults: userDefaults)
        self.limitsManager = SpendingLimitsManager(userDefaults: userDefaults)
        self.behaviorManager = AppBehaviorSettingsManager(userDefaults: userDefaults)

        logger.info("SettingsManager initialized with \(self.providerSessions.count) provider sessions")
        for (provider, session) in providerSessions {
            let sessionInfo = "  \(provider.displayName): email=\(session.userEmail ?? "none"), " +
                "teamId=\(session.teamId?.description ?? "none"), active=\(session.isActive)"
            logger.info("\(sessionInfo)")
        }
    }

    // For testing
    init(userDefaults: UserDefaults, startupManager: StartupControlling) {
        self.sessionManager = SessionSettingsManager(userDefaults: userDefaults)
        self.displayManager = DisplaySettingsManager(userDefaults: userDefaults)
        self.limitsManager = SpendingLimitsManager(userDefaults: userDefaults)
        self.behaviorManager = AppBehaviorSettingsManager(userDefaults: userDefaults, startupManager: startupManager)
    }

    // MARK: - Public Methods

    public func clearUserSessionData() {
        logger.info("clearUserSessionData called - delegating to session manager")
        sessionManager.clearAllSessions()
        logger.info("All user session data cleared")
    }

    public func clearUserSessionData(for provider: ServiceProvider) {
        logger.info("clearUserSessionData called for \(provider.displayName) - delegating to session manager")
        sessionManager.clearSession(for: provider)
        logger.info("User session data cleared for \(provider.displayName)")
    }

    public func getSession(for provider: ServiceProvider) -> ProviderSession? {
        sessionManager.getSession(for: provider)
    }

    public func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        logger.info("updateSession called for \(provider.displayName) - delegating to session manager")
        sessionManager.updateSession(for: provider, session: session)
        logger.info("Session successfully updated for \(provider.displayName)")
    }

    // MARK: - Validation and Utility Methods

    /// Validates all settings across all managers
    public func validateAllSettings() {
        displayManager.validateSettings()

        if !limitsManager.validateLimits() {
            logger.warning("Invalid spending limits detected, consider resetting to defaults")
        }
    }

    // MARK: - Testing Support

    /// Keys used by SettingsManager for UserDefaults storage.
    /// These are exposed for testing purposes to ensure consistent key usage.
    public enum Keys {
        // Display settings keys
        public static let selectedCurrencyCode = "selectedCurrencyCode"
        public static let refreshIntervalMinutes = "refreshIntervalMinutes"
        public static let menuBarDisplayMode = "menuBarDisplayMode"
        public static let hasUserCurrencyPreference = "hasUserCurrencyPreference"

        // Spending limits keys
        public static let warningLimitUSD = "warningLimitUSD"
        public static let upperLimitUSD = "upperLimitUSD"

        // App behavior keys
        public static let launchAtLoginEnabled = "launchAtLoginEnabled"
        public static let showInDock = "showInDock"

        // Session keys
        public static let enabledProviders = "enabledProviders"
        public static let providerSessions = "providerSessions"
    }

    private static var testInstance: SettingsManager?

    static func _test_setSharedInstance(userDefaults: UserDefaults, startupManager: StartupControlling) {
        testInstance = SettingsManager(userDefaults: userDefaults, startupManager: startupManager)
    }

    static func _test_clearSharedInstance() {
        testInstance = nil
    }
}
