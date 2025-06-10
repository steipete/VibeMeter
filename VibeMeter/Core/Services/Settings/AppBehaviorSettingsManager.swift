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
    private let logger = Logger.vibeMeter(category: "AppBehaviorSettings")

    // MARK: - Keys

    private enum Keys {
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let showInDock = "showInDock"
        static let updateChannel = "updateChannel"
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

    /// The update channel for receiving updates (stable vs pre-release)
    public var updateChannel: UpdateChannel {
        didSet {
            guard updateChannel != oldValue else { return }
            userDefaults.set(updateChannel.rawValue, forKey: Keys.updateChannel)

            // Notify that the update channel has changed so Sparkle can be reconfigured
            NotificationCenter.default.post(
                name: Notification.Name("UpdateChannelChanged"),
                object: nil,
                userInfo: ["channel": updateChannel])

            logger.debug("Update channel changed to: \(self.updateChannel.rawValue)")
        }
    }

    // MARK: - Initialization

    public init(userDefaults: UserDefaults = .standard, startupManager: StartupControlling = StartupManager()) {
        self.userDefaults = userDefaults
        self.startupManager = startupManager

        // Load app behavior settings with defaults
        launchAtLoginEnabled = userDefaults.bool(forKey: Keys.launchAtLoginEnabled)
        showInDock = userDefaults.object(forKey: Keys.showInDock) as? Bool ?? false // Default to false (menu bar only)

        // Load update channel with auto-detection based on current app version
        let currentVersion = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let defaultChannel = UpdateChannel.defaultChannel(for: currentVersion)
        let savedChannelRaw = userDefaults.string(forKey: Keys.updateChannel) ?? defaultChannel.rawValue
        updateChannel = UpdateChannel(rawValue: savedChannelRaw) ?? defaultChannel

        logger
            .info(
                """
                AppBehaviorSettingsManager initialized - \
                launch at login: \(self.launchAtLoginEnabled), \
                show in dock: \(self.showInDock), \
                update channel: \(self.updateChannel.rawValue)
                """)
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

    /// Updates the update channel setting
    public func updateUpdateChannel(_ channel: UpdateChannel) {
        updateChannel = channel
    }
}
