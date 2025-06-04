import AppKit
import os.log
import SwiftUI

// MARK: - App Entry Point

/// The main entry point for the VibeMeter application.
///
/// VibeMeter is a macOS menu bar application that monitors monthly spending
/// on the Cursor AI service. It provides real-time spending tracking,
/// multi-currency support, and customizable spending alerts.
///
/// This modernized version uses SwiftUI's Environment system for dependency
/// injection and focused @Observable models instead of a monolithic coordinator.
@main
struct VibeMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    @State
    private var gravatarService = GravatarService.shared

    // Settings manager for reactive updates
    @State
    private var settingsManager = SettingsManager.shared

    private var menuBarDisplayText: String {
        // Only show cost if setting is enabled and we have data
        guard settingsManager.menuBarDisplayMode.showsMoney else {
            return "" // Empty string = icon only (default behavior)
        }

        let providers = appDelegate.spendingData.providersWithData
        guard !providers.isEmpty else {
            return "" // No data = icon only
        }

        // Always use total spending for consistency with the popover
        let spending = appDelegate.spendingData.totalSpendingConverted(
            to: appDelegate.currencyData.selectedCode,
            rates: appDelegate.currencyData.effectiveRates)

        return "\(appDelegate.currencyData.selectedSymbol)\(spending.formatted(.number.precision(.fractionLength(2))))"
    }

    var body: some Scene {
        // Settings window using multi-provider architecture
        Settings {
            MultiProviderSettingsView(
                settingsManager: settingsManager,
                userSessionData: appDelegate.userSession,
                loginManager: appDelegate.loginManager,
                orchestrator: appDelegate.multiProviderOrchestrator)
                .environment(appDelegate.spendingData)
                .environment(appDelegate.currencyData)
                .environment(gravatarService)
        }
    }
}

// MARK: - App Delegate

/// The application delegate responsible for managing the app lifecycle and core services.
///
/// This delegate handles:
/// - Initialization of core services and focused observable models
/// - Auto-update functionality via Sparkle framework
/// - Data orchestration setup and lifecycle management
/// - Cleanup on termination
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private(set) var sparkleUpdaterManager: SparkleUpdaterManager?
    var multiProviderOrchestrator: MultiProviderDataOrchestrator?

    // Strong reference to prevent StatusBarController deallocation
    // This must be retained for the entire app lifecycle
    private var statusBarController: StatusBarController?

    // Observable models for SwiftUI
    let spendingData = MultiProviderSpendingData()
    let userSession = MultiProviderUserSessionData()
    let currencyData = CurrencyData()

    // Core services - multi-provider architecture
    let settingsManager = SettingsManager.shared
    lazy var providerFactory = ProviderFactory(settingsManager: settingsManager)
    lazy var loginManager = MultiProviderLoginManager(providerFactory: providerFactory)
    let exchangeRateManager: ExchangeRateManagerProtocol = ExchangeRateManager.shared
    let notificationManager: NotificationManagerProtocol = NotificationManager()

    private let logger = Logger(subsystem: "com.vibemeter", category: "AppLifecycle")

    /// Distributed notification name used to ask an existing instance to show the Settings window.
    private static let showSettingsNotification = Notification.Name("com.vibemeter.showSettings")

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        // Skip single instance check for SwiftUI previews
        let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"

        // Detect if running in test environment
        let isRunningInTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            NSClassFromString("XCTestCase") != nil

        // Detect if running in debug mode (Xcode debugging)
        let isRunningInDebug = _isDebugAssertConfiguration()

        // Ensure only a single instance of VibeMeter is running. If another instance is
        // already active, notify it to display the Settings window and terminate this
        // process early. Skip this entirely when running tests or in debug mode.
        if !isRunningInPreview, !isRunningInTests, !isRunningInDebug {
            let runningApps = NSRunningApplication
                .runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")

            // Log all running applications for debugging
            logger.info("All running applications:")
            for app in runningApps {
                if let bundleId = app.bundleIdentifier {
                    logger.info("  - \(app.localizedName ?? "Unknown") (\(bundleId))")
                } else {
                    logger.info("  - \(app.localizedName ?? "Unknown") (no bundle ID)")
                }
            }

            if runningApps.count > 1 {
                // Show user notification about existing instance
                Task {
                    await notificationManager.showInstanceAlreadyRunningNotification()
                }

                DistributedNotificationCenter.default().post(name: Self.showSettingsNotification, object: nil)
                NSApp.terminate(nil)
                return
            }

            // Register to listen for the settings-window request from any subsequent launches.
            DistributedNotificationCenter.default().addObserver(
                self,
                selector: #selector(handleShowSettingsNotification),
                name: Self.showSettingsNotification,
                object: nil)
        }

        logger.info("VibeMeter launching...")

        // Set activation policy based on user preference
        if settingsManager.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        logger
            .info(
                "Activation policy set to: \(self.settingsManager.showInDock ? "regular (show in dock)" : "accessory (menu bar only)")")

        // Initialize auto-updater
        sparkleUpdaterManager = SparkleUpdaterManager()

        // Ensure login states are properly synchronized with keychain
        loginManager.refreshLoginStatesFromKeychain()

        // Initialize the data orchestrator first
        multiProviderOrchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: settingsManager,
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            loginManager: loginManager,
            spendingData: spendingData,
            userSessionData: userSession,
            currencyData: currencyData)

        // Set up the status bar controller with orchestrator access (skip in tests)
        guard let orchestrator = multiProviderOrchestrator else {
            logger.error("Failed to initialize MultiProviderDataOrchestrator")
            return
        }

        // Only create status bar controller if not running in tests
        if !isRunningInTests {
            statusBarController = StatusBarController(
                settingsManager: settingsManager,
                userSession: userSession,
                loginManager: loginManager,
                spendingData: spendingData,
                currencyData: currencyData,
                orchestrator: orchestrator)

            // Show popover on startup if user is not logged in to any provider
            Task { @MainActor in
                // Add a short delay to ensure the UI is fully initialized
                try? await Task.sleep(for: .milliseconds(500))

                if !userSession.isLoggedInToAnyProvider {
                    statusBarController?.showPopover()
                }
            }
        } else {
            logger.info("Running in test environment - skipping StatusBarController initialization")
        }

        // Check if app should be moved to Applications (skip in tests and previews)
        if !isRunningInTests, !isRunningInPreview {
            let applicationMover = ApplicationMover()
            applicationMover.checkAndOfferToMoveToApplications()
        }

        logger.info("VibeMeter launched successfully")
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("VibeMeter terminating...")

        // Cleanup in proper order
        statusBarController = nil
        multiProviderOrchestrator = nil

        // Remove distributed-notification observer (only if we registered it)
        let isRunningInTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
            NSClassFromString("XCTestCase") != nil
        let isRunningInPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let isRunningInDebug = _isDebugAssertConfiguration()

        if !isRunningInPreview, !isRunningInTests, !isRunningInDebug {
            DistributedNotificationCenter.default().removeObserver(
                self,
                name: Self.showSettingsNotification,
                object: nil)
        }

        logger.info("VibeMeter terminated")
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }

    // MARK: - Distributed Notification Handling

    /// Shows the Settings window when another VibeMeter instance asks us to.
    @objc
    private func handleShowSettingsNotification(_: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.openSettings()
    }
}
