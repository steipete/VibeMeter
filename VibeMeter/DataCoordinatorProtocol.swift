import Combine
import Foundation

// Protocol for DataCoordinator
@MainActor
protocol DataCoordinatorProtocol: ObservableObject {
    // Published properties for UI
    var isLoggedIn: Bool { get }
    var userEmail: String? { get }
    var currentSpendingUSD: Double? { get } // Internal USD amount
    var currentSpendingConverted: Double? { get }
    var warningLimitConverted: Double? { get }
    var upperLimitConverted: Double? { get }
    var teamName: String? { get }
    var selectedCurrencyCode: String { get }
    var selectedCurrencySymbol: String { get }
    var exchangeRatesAvailable: Bool { get }
    var menuBarDisplayText: String { get }
    var lastErrorMessage: String? { get } // For displaying errors in Settings or menu
    var teamIdFetchFailed: Bool { get } // Specific state for team ID fetch failure
    var currentExchangeRates: [String: Double] { get } // Expose current rates
    var settingsManager: any SettingsManagerProtocol { get } // Expose settings manager

    // Actions
    func forceRefreshData(showSyncedMessage: Bool) async
    func initiateLoginFlow()
    func userDidRequestLogout() // New method for user-initiated logout

    // Potentially direct access to settings for SettingsView, if not already covered by SettingsManager.shared
    // var settings: SettingsManagerProtocol { get } // If DataCoordinator exposes its SettingsManager instance
}

// Companion object for shared instance and testability
@MainActor
class DataCoordinator {
    static var shared: any DataCoordinatorProtocol = RealDataCoordinator(
        // Initialize with real shared instances of dependencies
        // These dependencies themselves are now using the shared/protocol pattern
        loginManager: LoginManager(
            settingsManager: SettingsManager.shared,
            apiClient: CursorAPIClient.shared,
            keychainService: KeychainHelper.shared
        ),
        settingsManager: SettingsManager.shared,
        exchangeRateManager: ExchangeRateManagerImpl.shared, // Corrected name
        apiClient: CursorAPIClient.shared,
        notificationManager: NotificationManager.shared
        // startupManager: StartupManager.shared // Not directly used by DataCoordinator currently
    )

    // Test-only method to inject a mock shared instance
    static func _test_setSharedInstance(instance: any DataCoordinatorProtocol) {
        shared = instance
    }

    // Test-only method to reset to the real shared instance
    static func _test_resetSharedInstance() {
        shared = RealDataCoordinator(
            loginManager: LoginManager(
                settingsManager: SettingsManager.shared,
                apiClient: CursorAPIClient.shared,
                keychainService: KeychainHelper.shared
            ),
            settingsManager: SettingsManager.shared,
            exchangeRateManager: ExchangeRateManagerImpl.shared,
            apiClient: CursorAPIClient.shared,
            notificationManager: NotificationManager.shared
        )
    }

    private init() {} // Prevent direct instantiation of the companion object
}
