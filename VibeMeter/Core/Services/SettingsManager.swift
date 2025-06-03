import Combine
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

    // Provider management
    var enabledProviders: Set<ServiceProvider> { get set }

    // Methods
    func clearUserSessionData()
    func clearUserSessionData(for provider: ServiceProvider)
    func getSession(for provider: ServiceProvider) -> ProviderSession?
    func updateSession(for provider: ServiceProvider, session: ProviderSession)
}

// MARK: - Provider Session Model

/// Represents user session data for a specific provider.
public struct ProviderSession: Codable, Sendable {
    public let provider: ServiceProvider
    public var teamId: Int?
    public var teamName: String?
    public var userEmail: String?
    public var isActive: Bool

    public init(
        provider: ServiceProvider,
        teamId: Int? = nil,
        teamName: String? = nil,
        userEmail: String? = nil,
        isActive: Bool = false) {
        self.provider = provider
        self.teamId = teamId
        self.teamName = teamName
        self.userEmail = userEmail
        self.isActive = isActive
    }
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
/// All properties are published to enable reactive UI updates via Combine.
/// The manager follows the singleton pattern and is accessible via `SettingsManager.shared`.
@MainActor
public final class SettingsManager: SettingsManagerProtocol, ObservableObject {
    // MARK: - Constants

    public static let refreshIntervalOptions = [5, 10, 15, 30, 60]

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
    }

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.vibemeter", category: "Settings")
    private let startupManager: StartupControlling

    // Multi-provider sessions
    @Published
    public var providerSessions: [ServiceProvider: ProviderSession] {
        didSet {
            saveProviderSessions()
            logger.debug("Provider sessions updated")
        }
    }

    // Enabled providers
    @Published
    public var enabledProviders: Set<ServiceProvider> {
        didSet {
            let enabledArray = Array(enabledProviders).map(\.rawValue)
            userDefaults.set(enabledArray, forKey: Keys.enabledProviders)
            logger
                .debug("Enabled providers updated: \(self.enabledProviders.map(\.displayName).joined(separator: ", "))")
        }
    }

    // Display preferences
    @Published
    public var selectedCurrencyCode: String {
        didSet {
            userDefaults.set(selectedCurrencyCode, forKey: Keys.selectedCurrencyCode)
            logger.debug("Currency updated: \(self.selectedCurrencyCode)")
        }
    }

    @Published
    public var refreshIntervalMinutes: Int {
        didSet {
            userDefaults.set(refreshIntervalMinutes, forKey: Keys.refreshIntervalMinutes)
            logger.debug("Refresh interval updated: \(self.refreshIntervalMinutes) minutes")
        }
    }

    // Spending limits
    @Published
    public var warningLimitUSD: Double {
        didSet {
            userDefaults.set(warningLimitUSD, forKey: Keys.warningLimitUSD)
            logger.debug("Warning limit updated: $\(self.warningLimitUSD)")
        }
    }

    @Published
    public var upperLimitUSD: Double {
        didSet {
            userDefaults.set(upperLimitUSD, forKey: Keys.upperLimitUSD)
            logger.debug("Upper limit updated: $\(self.upperLimitUSD)")
        }
    }

    // App behavior
    @Published
    public var launchAtLoginEnabled: Bool {
        didSet {
            guard launchAtLoginEnabled != oldValue else { return }
            userDefaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)

            startupManager.setLaunchAtLogin(enabled: launchAtLoginEnabled)

            logger.debug("Launch at login: \(self.launchAtLoginEnabled)")
        }
    }

    @Published
    public var showCostInMenuBar: Bool {
        didSet {
            userDefaults.set(showCostInMenuBar, forKey: Keys.showCostInMenuBar)
            logger.debug("Show cost in menu bar: \(self.showCostInMenuBar)")
        }
    }

    // MARK: - Singleton

    public static let shared = MainActor.assumeIsolated {
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
        showCostInMenuBar = userDefaults.object(forKey: Keys.showCostInMenuBar) as? Bool ?? false // Default to false (icon-only)

        // Validate refresh interval
        if !Self.refreshIntervalOptions.contains(refreshIntervalMinutes) {
            refreshIntervalMinutes = 5
        }

        logger.info("SettingsManager initialized with \(self.providerSessions.count) provider sessions")
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
    }

    // MARK: - Public Methods

    public func clearUserSessionData() {
        // Clear all provider sessions
        providerSessions.removeAll()
        saveProviderSessions()

        logger.info("All user session data cleared")
    }

    public func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
        saveProviderSessions()

        logger.info("User session data cleared for \(provider.displayName)")
    }

    public func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }

    public func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
        saveProviderSessions()

        logger.debug("Session updated for \(provider.displayName)")
    }

    // MARK: - Private Methods

    private func saveProviderSessions() {
        if let sessionsData = try? JSONEncoder().encode(providerSessions) {
            userDefaults.set(sessionsData, forKey: Keys.providerSessions)
        }
    }

    // MARK: - Testing Support

    private static var testInstance: SettingsManager?

    static func _test_setSharedInstance(userDefaults: UserDefaults) {
        testInstance = SettingsManager(userDefaults: userDefaults, startupManager: StartupManager())
    }

    static func _test_clearSharedInstance() {
        testInstance = nil
    }
}
