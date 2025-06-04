import AppKit
import Foundation
import os.log

/// Manages application behavior settings like startup and dock visibility.
///
/// This manager handles settings that affect how the application behaves
/// at the system level, including launch at login and dock visibility.
@Observable
@MainActor
public final class AppBehaviorSettingsManager {
    // MARK: - Properties

    private let userDefaults: UserDefaults
    private let startupManager: StartupControlling
    private let logger = Logger(subsystem: "com.vibemeter", category: "AppBehaviorSettings")

    // MARK: - Keys

    private enum Keys {
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let showInDock = "showInDock"
    }

    // MARK: - App Behavior Settings

    /// Whether the application should launch at login
    public var launchAtLoginEnabled: Bool {
        didSet {
            guard launchAtLoginEnabled != oldValue else { return }
            userDefaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled)

            startupManager.setLaunchAtLogin(enabled: launchAtLoginEnabled)

            logger.debug("Launch at login: \(self.launchAtLoginEnabled)")
        }
    }

    /// Whether the application should show in the dock
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

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard, startupManager: StartupControlling = StartupManager()) {
        self.userDefaults = userDefaults
        self.startupManager = startupManager

        // Load app behavior settings with defaults
        launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled)
        showInDock = userDefaults.object(forKey: Keys.showInDock) as? Bool ?? false // Default to false (menu bar only)

        logger
            .info(
                "AppBehaviorSettingsManager initialized - launch at login: \(self.launchAtLoginEnabled), show in dock: \(self.showInDock)")
    }

    // MARK: - Public Methods

    /// Updates the launch at login setting
    public func updateLaunchAtLogin(enabled: Bool) {
        launchAtLoginEnabled = enabled
    }

    /// Updates the dock visibility setting
    public func updateDockVisibility(show: Bool) {
        showInDock = show
    }

    /// Synchronizes startup manager state with current setting
    public func syncStartupManager() {
        startupManager.setLaunchAtLogin(enabled: launchAtLoginEnabled)
        logger.debug("Startup manager synchronized with current setting: \(self.launchAtLoginEnabled)")
    }

    /// Applies current dock visibility setting to the application
    public func applyDockVisibility() {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        logger.debug("Dock visibility applied: \(self.showInDock)")
    }
}
