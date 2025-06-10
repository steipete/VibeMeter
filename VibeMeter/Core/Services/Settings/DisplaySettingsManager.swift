import Foundation
import os.log

/// Manages display and UI preference settings.
///
/// This manager handles currency selection, refresh intervals,
/// and menu bar display mode preferences.
@Observable
@MainActor
public final class DisplaySettingsManager {
    // MARK: - Constants

    public static let refreshIntervalOptions = [1, 2, 5, 10, 15, 30, 60]

    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.vibemeter", category: "DisplaySettings")

    // MARK: - Keys

    private enum Keys {
        static let selectedCurrencyCode = "selectedCurrencyCode"
        static let refreshIntervalMinutes = "refreshIntervalMinutes"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let gaugeRepresents = "gaugeRepresents"
    }

    // MARK: - Display Preferences

    /// What the gauge icon represents
    public enum GaugeRepresentation: String, CaseIterable, Identifiable, Sendable {
        case totalSpending
        case claudeQuota

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .totalSpending: "Total Monthly Spending"
            case .claudeQuota: "Claude 5-Hour Quota"
            }
        }
    }

    /// Selected currency code for display
    public var selectedCurrencyCode: String {
        didSet {
            userDefaults.set(selectedCurrencyCode, forKey: Keys.selectedCurrencyCode)
            logger.debug("Currency updated: \(self.selectedCurrencyCode)")
        }
    }

    /// Data refresh interval in minutes
    public var refreshIntervalMinutes: Int {
        didSet {
            userDefaults.set(refreshIntervalMinutes, forKey: Keys.refreshIntervalMinutes)
            logger.debug("Refresh interval updated: \(self.refreshIntervalMinutes) minutes")
        }
    }

    /// Menu bar display mode (icon only, amount only, or both)
    public var menuBarDisplayMode: MenuBarDisplayMode {
        didSet {
            userDefaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode)
            logger.debug("Menu bar display mode: \(self.menuBarDisplayMode.displayName)")
        }
    }

    /// What the gauge icon represents (total spending or Claude quota)
    public var gaugeRepresentation: GaugeRepresentation {
        didSet {
            userDefaults.set(gaugeRepresentation.rawValue, forKey: Keys.gaugeRepresents)
            logger.debug("Gauge representation set to: \(self.gaugeRepresentation.displayName)")
        }
    }

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        // Load display settings with defaults
        selectedCurrencyCode = userDefaults.string(forKey: Keys.selectedCurrencyCode) ?? "USD"
        refreshIntervalMinutes = userDefaults.object(forKey: Keys.refreshIntervalMinutes) as? Int ?? 5

        // Initialize menu bar display mode
        if let displayModeString = userDefaults.object(forKey: Keys.menuBarDisplayMode) as? String,
           let displayMode = MenuBarDisplayMode(rawValue: displayModeString) {
            menuBarDisplayMode = displayMode
        } else {
            menuBarDisplayMode = .both // Default to "both" (icon + money)
        }

        // Initialize gauge representation
        if let gaugeRepString = userDefaults.string(forKey: Keys.gaugeRepresents),
           let gaugeRep = GaugeRepresentation(rawValue: gaugeRepString) {
            gaugeRepresentation = gaugeRep
        } else {
            gaugeRepresentation = .totalSpending // Default to total spending
        }

        // Validate refresh interval
        if !Self.refreshIntervalOptions.contains(refreshIntervalMinutes) {
            refreshIntervalMinutes = 5
        }

        logger
            .info(
                """
                DisplaySettingsManager initialized - \
                currency: \(self.selectedCurrencyCode), \
                refresh: \(self.refreshIntervalMinutes)min, \
                display: \(self.menuBarDisplayMode.displayName)
                """)
    }

    // MARK: - Public Methods

    /// Updates the selected currency and persists the change
    public func updateCurrency(to currencyCode: String) {
        selectedCurrencyCode = currencyCode
    }

    /// Updates the refresh interval and validates it against allowed options
    public func updateRefreshInterval(to minutes: Int) {
        guard Self.refreshIntervalOptions.contains(minutes) else {
            logger.warning("Invalid refresh interval: \(minutes), using default 5 minutes")
            refreshIntervalMinutes = 5
            return
        }
        refreshIntervalMinutes = minutes
    }

    /// Updates the menu bar display mode
    public func updateMenuBarDisplayMode(to mode: MenuBarDisplayMode) {
        menuBarDisplayMode = mode
    }

    /// Validates and corrects invalid settings
    public func validateSettings() {
        if !Self.refreshIntervalOptions.contains(refreshIntervalMinutes) {
            logger.warning("Invalid refresh interval detected: \(self.refreshIntervalMinutes), correcting to 5 minutes")
            refreshIntervalMinutes = 5
        }
    }
}
