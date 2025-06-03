import Combine
import Foundation
import os.log

// MARK: - Settings Manager Protocol

@MainActor
public protocol SettingsManagerProtocol: AnyObject, Sendable {
    // User session
    var teamId: Int? { get set }
    var teamName: String? { get set }
    var userEmail: String? { get set }

    // Display preferences
    var selectedCurrencyCode: String { get set }
    var refreshIntervalMinutes: Int { get set }

    // Spending limits (stored in USD)
    var warningLimitUSD: Double { get set }
    var upperLimitUSD: Double { get set }

    // App behavior
    var launchAtLoginEnabled: Bool { get set }

    // Methods
    func clearUserSessionData()
}

// MARK: - Modern Settings Manager

@MainActor
public final class SettingsManager: SettingsManagerProtocol, ObservableObject {
    // MARK: - Constants

    public static let refreshIntervalOptions = [5, 10, 15, 30, 60]

    // Made internal for testing
    enum Keys {
        static let teamId = "teamId"
        static let teamName = "teamName"
        static let userEmail = "userEmail"
        static let selectedCurrencyCode = "selectedCurrencyCode"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let warningLimitUSD = "warningLimitUSD"
        static let upperLimitUSD = "upperLimitUSD"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
    }

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.vibemeter", category: "Settings")
    private let startupManager: StartupManagerProtocol

    // User session
    @Published public var teamId: Int? {
        didSet {
            userDefaults.set(teamId, forKey: Keys.teamId)
            logger.debug("Team ID updated: \(teamId ?? -1)")
        }
    }

    @Published public var teamName: String? {
        didSet {
            userDefaults.set(teamName, forKey: Keys.teamName)
            logger.debug("Team name updated: \(teamName ?? "nil")")
        }
    }

    @Published public var userEmail: String? {
        didSet {
            userDefaults.set(userEmail, forKey: Keys.userEmail)
            logger.debug("User email updated")
        }
    }

    // Display preferences
    @Published public var selectedCurrencyCode: String {
        didSet {
            userDefaults.set(selectedCurrencyCode, forKey: Keys.selectedCurrencyCode)
            logger.debug("Currency updated: \(selectedCurrencyCode)")
        }
    }

    @Published public var refreshIntervalMinutes: Int {
        didSet {
            userDefaults.set(refreshIntervalMinutes, forKey: Keys.refreshIntervalMinutes)
            logger.debug("Refresh interval updated: \(refreshIntervalMinutes) minutes")
        }
    }

    // Spending limits
    @Published public var warningLimitUSD: Double {
        didSet {
            userDefaults.set(warningLimitUSD, forKey: Keys.warningLimitUSD)
            logger.debug("Warning limit updated: $\(warningLimitUSD)")
        }
    }

    @Published public var upperLimitUSD: Double {
        didSet {
            userDefaults.set(upperLimitUSD, forKey: Keys.upperLimitUSD)
            logger.debug("Upper limit updated: $\(upperLimitUSD)")
        }
    }

    // App behavior
    @Published public var launchAtLoginEnabled: Bool {
        didSet {
            guard launchAtLoginEnabled != oldValue else { return }
            userDefaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)

            startupManager.setLaunchAtLogin(enabled: launchAtLoginEnabled)

            logger.debug("Launch at login: \(launchAtLoginEnabled)")
        }
    }

    // MARK: - Singleton

    public static let shared = MainActor.assumeIsolated {
        SettingsManager()
    }

    // MARK: - Initialization

    private init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        startupManager = StartupManager.shared

        // Load persisted values
        teamId = userDefaults.object(forKey: Keys.teamId) as? Int
        teamName = userDefaults.string(forKey: Keys.teamName)
        userEmail = userDefaults.string(forKey: Keys.userEmail)

        // Load with defaults
        selectedCurrencyCode = userDefaults.string(forKey: Keys.selectedCurrencyCode) ?? "USD"
        refreshIntervalMinutes = userDefaults.object(forKey: Keys.refreshIntervalMinutes) as? Int ?? 15
        warningLimitUSD = userDefaults.object(forKey: Keys.warningLimitUSD) as? Double ?? 200.0
        upperLimitUSD = userDefaults.object(forKey: Keys.upperLimitUSD) as? Double ?? 1000.0
        launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled)

        // Validate refresh interval
        if !Self.refreshIntervalOptions.contains(refreshIntervalMinutes) {
            refreshIntervalMinutes = 15
        }

        logger.info("SettingsManager initialized")
    }

    // For testing
    init(userDefaults: UserDefaults, startupManager: StartupManagerProtocol) {
        self.userDefaults = userDefaults
        self.startupManager = startupManager

        // Load persisted values
        teamId = userDefaults.object(forKey: Keys.teamId) as? Int
        teamName = userDefaults.string(forKey: Keys.teamName)
        userEmail = userDefaults.string(forKey: Keys.userEmail)

        // Load with defaults
        selectedCurrencyCode = userDefaults.string(forKey: Keys.selectedCurrencyCode) ?? "USD"
        refreshIntervalMinutes = userDefaults.object(forKey: Keys.refreshIntervalMinutes) as? Int ?? 15
        warningLimitUSD = userDefaults.object(forKey: Keys.warningLimitUSD) as? Double ?? 200.0
        upperLimitUSD = userDefaults.object(forKey: Keys.upperLimitUSD) as? Double ?? 1000.0
        launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled)
    }

    // MARK: - Public Methods

    public func clearUserSessionData() {
        teamId = nil
        teamName = nil
        userEmail = nil
        logger.info("User session data cleared")
    }

    // MARK: - Testing Support

    private static var testInstance: SettingsManager?

    static func _test_setSharedInstance(userDefaults: UserDefaults) {
        testInstance = SettingsManager(userDefaults: userDefaults)
    }

    static func _test_clearSharedInstance() {
        testInstance = nil
    }
}
