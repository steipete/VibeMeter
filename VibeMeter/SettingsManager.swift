import Foundation

@MainActor
class SettingsManager: ObservableObject, SettingsManagerProtocol {
    // Make `shared` a computed property or a lazy var to allow for replacement in tests if needed,
    // or provide a test-only method to reset/replace it.
    // For simplicity here, we'll make it a settable static var for testing purposes.
    // In a production app, you might use a more sophisticated DI framework or approach.
    static var shared = SettingsManager(userDefaults: .standard)

    // The UserDefaults instance to use. Internal to allow replacement for testing.
    let userDefaults: UserDefaults

    // MARK: - Keys

    // Made internal for access from tests if needed, though direct key access in tests is less ideal than testing
    // behavior.
    enum Keys {
        static let selectedCurrencyCode = "selectedCurrencyCode"
        static let warningLimitUSD = "warningLimitUSD"
        static let upperLimitUSD = "upperLimitUSD"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        // For API Client related data, managed by DataCoordinator or similar
        static let teamId = "teamId"
        static let teamName = "teamName"
        static let userEmail = "userEmail"
    }

    // MARK: - Published Properties for SwiftUI

    @Published var selectedCurrencyCode: String {
        didSet { userDefaults.set(selectedCurrencyCode, forKey: Keys.selectedCurrencyCode) }
    }

    @Published var warningLimitUSD: Double {
        didSet { userDefaults.set(warningLimitUSD, forKey: Keys.warningLimitUSD) }
    }

    @Published var upperLimitUSD: Double {
        didSet { userDefaults.set(upperLimitUSD, forKey: Keys.upperLimitUSD) }
    }

    @Published var refreshIntervalMinutes: Int {
        didSet { userDefaults.set(refreshIntervalMinutes, forKey: Keys.refreshIntervalMinutes) }
    }

    @Published var launchAtLoginEnabled: Bool {
        didSet {
            userDefaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)
            StartupManager.shared.setLaunchAtLogin(enabled: launchAtLoginEnabled)
        }
    }

    var teamId: Int? {
        get {
            let id = userDefaults.integer(forKey: Keys.teamId)
            return id == 0 && userDefaults
                .object(forKey: Keys.teamId) == nil ? nil : id // Ensure 0 is nil only if not explicitly set
        }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: Keys.teamId)
            } else {
                userDefaults.removeObject(forKey: Keys.teamId)
            }
        }
    }

    var teamName: String? {
        get { userDefaults.string(forKey: Keys.teamName) }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: Keys.teamName)
            } else {
                userDefaults.removeObject(forKey: Keys.teamName)
            }
        }
    }

    var userEmail: String? {
        get { userDefaults.string(forKey: Keys.userEmail) }
        set {
            if let newValue {
                userDefaults.set(newValue, forKey: Keys.userEmail)
            } else {
                userDefaults.removeObject(forKey: Keys.userEmail)
            }
        }
    }

    // MARK: - Initialization & Defaults

    // Internal initializer for dependency injection (especially for testing)
    init(userDefaults: UserDefaults) {
        self.userDefaults = userDefaults

        // Load initial values or set defaults from the provided UserDefaults instance
        selectedCurrencyCode = userDefaults.string(forKey: Keys.selectedCurrencyCode) ?? "USD"
        warningLimitUSD = userDefaults.object(forKey: Keys.warningLimitUSD) as? Double ?? 200.0
        upperLimitUSD = userDefaults.object(forKey: Keys.upperLimitUSD) as? Double ?? 1000.0
        // Handle 0 value for refreshIntervalMinutes if not set, as integer(forKey:) returns 0 for non-existent keys.
        let storedInterval = userDefaults.integer(forKey: Keys.refreshIntervalMinutes)
        if userDefaults.object(forKey: Keys.refreshIntervalMinutes) == nil, storedInterval == 0 {
            // Key doesn't exist, use default
            refreshIntervalMinutes = 5
        } else if storedInterval == 0 {
            // Key exists but is 0 (shouldn't happen with current UI)
            refreshIntervalMinutes = 5
        } else {
            // Use stored value
            refreshIntervalMinutes = storedInterval
        }

        launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled) // Defaults to false if not set

        // Register default values to ensure they exist on first launch if not explicitly set above
        // These are registered against the *provided* userDefaults instance.
        userDefaults.register(defaults: [
            Keys.selectedCurrencyCode: "USD",
            Keys.warningLimitUSD: 200.0,
            Keys.upperLimitUSD: 1000.0,
            Keys.refreshIntervalMinutes: 5,
            Keys.launchAtLoginEnabled: false,
            // teamId, teamName, userEmail are not registered with defaults as they are user-specific
        ])
    }

    // Convenience init for production that uses UserDefaults.standard
    // This is what the `static var shared` uses by default.
    private convenience init() {
        self.init(userDefaults: .standard)
    }

    // MARK: - Clearing User Specific Data (related to login session)

    func clearUserSessionData() {
        userDefaults.removeObject(forKey: Keys.teamId)
        userDefaults.removeObject(forKey: Keys.teamName)
        userDefaults.removeObject(forKey: Keys.userEmail)
        LoggingService.info("User session related data cleared from UserDefaults.", category: .settings)
    }

    // MARK: - Refresh Intervals

    static let refreshIntervalOptions: [Int] = [1, 5, 10, 15, 30, 60] // in minutes

    // MARK: - Testability

    #if DEBUG // Or a custom build configuration like TESTING
        static func _test_clearSharedInstance() {
            // Replace the shared instance with a new one using standard UserDefaults
            // or a specific one if tests need further control over the "standard" shared instance.
            shared = SettingsManager(userDefaults: .standard)
        }

        // Allows tests to set a shared instance with specific UserDefaults
        static func _test_setSharedInstance(userDefaults: UserDefaults) {
            shared = SettingsManager(userDefaults: userDefaults)
        }
    #endif
}
