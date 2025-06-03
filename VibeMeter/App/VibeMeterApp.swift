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

    // Reactive computed property for menu bar display text  
    @ObservedObject private var settingsManager = SettingsManager.shared
    
    private var menuBarDisplayText: String {
        // Only show cost if setting is enabled and we have data
        guard settingsManager.showCostInMenuBar else {
            return "" // Empty string = icon only (default behavior)
        }
        
        let providers = appDelegate.spendingData.providersWithData
        guard !providers.isEmpty else {
            return "" // No data = icon only
        }

        let spending: Double = if providers.count == 1,
                                  let providerData = appDelegate.spendingData.getSpendingData(for: providers[0]),
                                  let providerSpending = providerData.displaySpending {
            providerSpending
        } else {
            // Show total across all providers
            appDelegate.spendingData.totalSpendingConverted(to: appDelegate.currencyData.selectedCode, rates: appDelegate.currencyData.currentExchangeRates)
        }

        return "\(appDelegate.currencyData.selectedSymbol)\(String(format: "%.2f", spending))"
    }

    var body: some Scene {
        // Settings window using multi-provider architecture
        Settings {
            MultiProviderSettingsView(
                settingsManager: settingsManager,
                userSessionData: appDelegate.userSession,
                loginManager: appDelegate.loginManager)
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
    private var multiProviderOrchestrator: MultiProviderDataOrchestrator?
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
        
        // Ensure only a single instance of VibeMeter is running. If another instance is
        // already active, notify it to display the Settings window and terminate this
        // process early.
        if !isRunningInPreview {
            let runningApps = NSRunningApplication
                .runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            if runningApps.count > 1 {
                DistributedNotificationCenter.default().post(name: Self.showSettingsNotification, object: nil)
                NSApp.terminate(nil)
                return
            }
        }

        // Register to listen for the settings-window request from any subsequent launches.
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleShowSettingsNotification),
            name: Self.showSettingsNotification,
            object: nil)

        logger.info("VibeMeter launching...")

        // Set activation policy based on user preference
        if settingsManager.showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        logger.info("Activation policy set to: \(self.settingsManager.showInDock ? "regular (show in dock)" : "accessory (menu bar only)")")

        // Initialize auto-updater
        #if !DEBUG
            sparkleUpdaterManager = SparkleUpdaterManager()
        #endif

        // Set up the status bar controller
        statusBarController = StatusBarController(
            settingsManager: settingsManager,
            userSession: userSession,
            loginManager: loginManager,
            spendingData: spendingData,
            currencyData: currencyData
        )

        // Initialize the data orchestrator
        multiProviderOrchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: settingsManager,
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            loginManager: loginManager,
            spendingData: spendingData,
            userSessionData: userSession,
            currencyData: currencyData
        )

        // Don't show login window automatically - wait for user to click login button

        logger.info("VibeMeter launched successfully")
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("VibeMeter terminating...")

        // Cleanup
        multiProviderOrchestrator = nil

        logger.info("VibeMeter terminated")

        // Remove distributed-notification observer
        DistributedNotificationCenter.default().removeObserver(self, name: Self.showSettingsNotification, object: nil)
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
