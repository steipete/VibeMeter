import AppKit
import os.log
import SwiftUI

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
        let processInfo = ProcessInfo.processInfo
        let isRunningInTests = processInfo.isRunningInTests

        configureSingleInstanceAndNotifications(processInfo: processInfo)
        setupApplicationAndServices()
        initializeDataOrchestrator()

        guard let orchestrator = multiProviderOrchestrator else {
            logger.error("Failed to initialize MultiProviderDataOrchestrator")
            return
        }

        setupStatusBarController(orchestrator: orchestrator, isRunningInTests: isRunningInTests)
        checkApplicationLocation(processInfo: processInfo)

        logger.info("VibeMeter launched successfully")
    }

    private func configureSingleInstanceAndNotifications(processInfo: ProcessInfo) {
        let isRunningInPreview = processInfo.isRunningInPreview
        let isRunningInTests = processInfo.isRunningInTests
        let isRunningInDebug = processInfo.isRunningInDebug

        if !isRunningInPreview, !isRunningInTests, !isRunningInDebug {
            handleSingleInstanceCheck()
            registerForNotifications()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleCheckForUpdatesNotification),
            name: Notification.Name("checkForUpdates"),
            object: nil)
    }

    private func handleSingleInstanceCheck() {
        let runningApps = NSRunningApplication
            .runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")

        logRunningApplications(runningApps)

        if runningApps.count > 1 {
            Task {
                await notificationManager.showInstanceAlreadyRunningNotification()
            }

            DistributedNotificationCenter.default().post(name: Self.showSettingsNotification, object: nil)
            NSApp.terminate(nil)
            return
        }
    }

    private func logRunningApplications(_ apps: [NSRunningApplication]) {
        logger.info("All running applications:")
        for app in apps {
            if let bundleId = app.bundleIdentifier {
                logger.info("  - \(app.localizedName ?? "Unknown") (\(bundleId))")
            } else {
                logger.info("  - \(app.localizedName ?? "Unknown") (no bundle ID)")
            }
        }
    }

    private func registerForNotifications() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowSettingsNotification),
            name: Self.showSettingsNotification,
            object: nil)
    }

    private func setupApplicationAndServices() {
        logger.info("VibeMeter launching...")

        configureActivationPolicy()
        sparkleUpdaterManager = SparkleUpdaterManager()
        loginManager.refreshLoginStatesFromKeychain()
    }

    private func configureActivationPolicy() {
        if settingsManager.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }

        let policyDescription = settingsManager.showInDock ? "regular (show in dock)" : "accessory (menu bar only)"
        logger.info("Activation policy set to: \(policyDescription)")
    }

    private func initializeDataOrchestrator() {
        multiProviderOrchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: settingsManager,
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            loginManager: loginManager,
            spendingData: spendingData,
            userSessionData: userSession,
            currencyData: currencyData)
    }

    private func setupStatusBarController(orchestrator: MultiProviderDataOrchestrator, isRunningInTests: Bool) {
        if !isRunningInTests {
            statusBarController = StatusBarController(
                settingsManager: settingsManager,
                userSession: userSession,
                loginManager: loginManager,
                spendingData: spendingData,
                currencyData: currencyData,
                orchestrator: orchestrator)

            scheduleStartupUIDisplay()
        } else {
            logger.info("Running in test environment - skipping StatusBarController initialization")
        }
    }

    private func scheduleStartupUIDisplay() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))

            if !userSession.isLoggedInToAnyProvider {
                statusBarController?.showCustomWindow()
            }
        }
    }

    private func checkApplicationLocation(processInfo: ProcessInfo) {
        if !processInfo.isRunningInTests, !processInfo.isRunningInPreview {
            let applicationMover = ApplicationMover()
            applicationMover.checkAndOfferToMoveToApplications()
        }
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("VibeMeter terminating...")

        // Cleanup in proper order
        statusBarController = nil
        multiProviderOrchestrator = nil

        // Remove distributed-notification observer (only if we registered it)
        let processInfo = ProcessInfo.processInfo
        let isRunningInTests = processInfo.isRunningInTests
        let isRunningInPreview = processInfo.isRunningInPreview
        let isRunningInDebug = processInfo.isRunningInDebug

        if !isRunningInPreview, !isRunningInTests, !isRunningInDebug {
            DistributedNotificationCenter.default().removeObserver(
                self,
                name: Self.showSettingsNotification,
                object: nil)
        }

        // Remove update check notification observer
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("checkForUpdates"),
            object: nil)

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

    @objc
    private func handleCheckForUpdatesNotification(_: Notification) {
        if let sparkleManager = sparkleUpdaterManager {
            sparkleManager.updaterController.checkForUpdates(nil)
        }
    }
}
