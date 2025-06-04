import os
import Sparkle
import UserNotifications

/// Manages the Sparkle auto-update framework integration for VibeMeter.
///
/// SparkleUpdaterManager provides:
/// - Automatic update checking and installation
/// - Update UI presentation and user interaction
/// - Delegate callbacks for update lifecycle events
/// - Configuration of update channels and behavior
///
/// This manager wraps Sparkle's functionality to provide a clean
/// interface for the rest of the application while handling all
/// update-related delegate callbacks and UI presentation.
@MainActor
@Observable
public class SparkleUpdaterManager: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate,
    UNUserNotificationCenterDelegate {
    // MARK: - Static Logger for nonisolated methods

    private nonisolated static let staticLogger = Logger(subsystem: "com.steipete.vibemeter", category: "updates")

    // MARK: Lifecycle

    override init() {
        super.init()

        // Skip Sparkle initialization in test environment to avoid dialogs
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            Self.staticLogger.info("SparkleUpdaterManager initialized in test mode - Sparkle disabled")
            return
        }

        // Initialize the updater controller
        initializeUpdaterController()

        // Set up notification center for gentle reminders
        setupNotificationCenter()

        // Listen for update channel changes
        setupUpdateChannelListener()
        Self.staticLogger
            .info("SparkleUpdaterManager initialized. Updater controller initialization completed.")

        // Only schedule startup update check in release builds
        #if !DEBUG
            scheduleStartupUpdateCheck()
        #else
            Self.staticLogger.info("SparkleUpdaterManager: Running in DEBUG mode - automatic update checks disabled")
        #endif
    }

    // MARK: Public

    // Initialize controller after self is available
    public private(set) var updaterController: SPUStandardUpdaterController!

    private func initializeUpdaterController() {
        // Always start the updater to allow manual checks
        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: self)

        // Enable automatic update checks only in release builds
        #if DEBUG
            controller.updater.automaticallyChecksForUpdates = false
            controller.updater.automaticallyDownloadsUpdates = false
            Self.staticLogger.info("Automatic update checks disabled in DEBUG mode")
        #else
            controller.updater.automaticallyChecksForUpdates = true
            controller.updater.automaticallyDownloadsUpdates = true
            controller.updater.updateCheckInterval = 3600 * 1 // Check every hour
            Self.staticLogger.info("Automatic update checks and downloads enabled (interval: 1 hour)")
        #endif

        Self.staticLogger
            .info("SparkleUpdaterManager: SPUStandardUpdaterController initialized with self as delegates.")

        updaterController = controller
    }

    private func setupNotificationCenter() {
        // Set up notification center for gentle reminders
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        // Request notification permission
        Task {
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound])
                if granted {
                    Self.staticLogger.info("Notification permission granted for gentle reminders")
                } else {
                    Self.staticLogger.warning("Notification permission denied - gentle reminders will not work")
                }
            } catch {
                Self.staticLogger.error("Failed to request notification permission: \(error)")
            }
        }

        // Set up notification categories and actions
        let updateAction = UNNotificationAction(
            identifier: "UPDATE_NOW",
            title: "Update Now",
            options: .foreground)

        let laterAction = UNNotificationAction(
            identifier: "LATER",
            title: "Later",
            options: [])

        let updateCategory = UNNotificationCategory(
            identifier: "UPDATE_AVAILABLE",
            actions: [updateAction, laterAction],
            intentIdentifiers: [],
            options: [])

        center.setNotificationCategories([updateCategory])
        Self.staticLogger.info("Notification center configured for gentle reminders")
    }

    private func setupUpdateChannelListener() {
        // Listen for update channel changes
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UpdateChannelChanged"),
            object: nil,
            queue: .main) { [weak self] notification in
                guard let self,
                      let userInfo = notification.userInfo,
                      let channel = userInfo["channel"] as? UpdateChannel else { return }

                // Update feed URL for the new channel
                Task { @MainActor in
                    await self.updateFeedURL(for: channel)
                }
            }

        // Configure initial feed URL based on current settings
        Task { @MainActor in
            let currentChannel = SettingsManager.shared.updateChannel
            await self.updateFeedURL(for: currentChannel)
        }
    }

    // Store the current channel for the delegate method
    private var currentChannel: UpdateChannel = .stable

    @MainActor
    private func updateFeedURL(for channel: UpdateChannel) async {
        currentChannel = channel
        Self.staticLogger.info("Updated update channel to: \(channel.displayName)")

        // Optionally check for updates after changing the channel
        // This ensures users get immediate feedback when switching to pre-release
        if channel == .prerelease {
            Self.staticLogger.info("Checking for updates after switching to pre-release channel")
            updaterController.updater.checkForUpdatesInBackground()
        }
    }

    // MARK: Private

    private func scheduleStartupUpdateCheck() {
        Task { @MainActor in
            // Wait a moment for the app to finish launching before checking
            try? await Task.sleep(for: .seconds(2))
            Self.staticLogger.info("Checking for updates on startup")
            self.updaterController.updater.checkForUpdatesInBackground()
        }
    }

    // MARK: - SPUUpdaterDelegate

    // Handle when no update is found or when there's an error checking for updates
    public nonisolated func updater(_: SPUUpdater, didFinishUpdateCycleFor _: SPUUpdateCheck, error: Error?) {
        if let error = error as NSError? {
            let errorDetails = "Update cycle finished with error - Domain: \(error.domain), Code: \(error.code)"
            let fullDetails = "\(errorDetails), Description: \(error.localizedDescription)"
            Self.staticLogger.error("\(fullDetails)")

            // Check if it's a "no update found" error - this is normal and shouldn't be logged as an error
            if error.domain == "SUSparkleErrorDomain", error.code == 1001 {
                Self.staticLogger.debug("No updates available")
                return
            }

            // Check for appcast-related errors (missing file, parse errors, etc.)
            if error.domain == "SUSparkleErrorDomain",
               error.code == 2001 || // SUAppcastError
               error.code == 2002 || // SUAppcastParseError
               error.code == 2000 { // SUInvalidFeedURLError
                Self.staticLogger.warning("Appcast error (missing or invalid feed): \(error.localizedDescription)")
                // Suppress the error dialog - we'll handle this silently
                return
            }

            // For other network errors or missing appcast, log but don't show UI
            Self.staticLogger.warning("Update check failed: \(error.localizedDescription)")

            // Suppress default error dialog by not propagating the error
            return
        }

        Self.staticLogger.debug("Update check completed successfully")
    }

    // Called when an update is found
    public nonisolated func updater(_: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Self.staticLogger.info("Found valid update: \(item.displayVersionString) (build \(item.versionString))")
        Self.staticLogger.info("Update URL: \(item.fileURL?.absoluteString ?? "none")")
    }

    // Called when about to extract update
    public nonisolated func updater(_: SPUUpdater, willExtractUpdate item: SUAppcastItem) {
        Self.staticLogger.info("About to extract update: \(item.displayVersionString)")
    }

    // Called when about to install update
    public nonisolated func updater(_: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        Self.staticLogger.info("About to install update: \(item.displayVersionString)")
    }

    // Called if update installation fails
    public nonisolated func updater(_: SPUUpdater, failedToInstallUpdateWithError error: Error) {
        Self.staticLogger.error("Failed to install update: \(error.localizedDescription)")
    }

    // Prevent update checks if we know the appcast is not available
    public nonisolated func updater(_: SPUUpdater, mayPerform _: SPUUpdateCheck) throws {
        // You can add logic here to prevent update checks under certain conditions
        // For now, we'll allow all checks but handle errors gracefully in didFinishUpdateCycleFor
        Self.staticLogger.debug("Allowing update check")
    }

    // Handle when update is not found
    public nonisolated func updaterDidNotFindUpdate(_: SPUUpdater, error: Error) {
        let error = error as NSError
        Self.staticLogger.info("No update found: \(error.localizedDescription)")
    }

    // Provide dynamic feed URL based on current update channel
    public nonisolated func feedURLString(for _: SPUUpdater) -> String? {
        let channel = MainActor.assumeIsolated {
            self.currentChannel
        }
        Self.staticLogger.info("Providing feed URL for channel: \(channel.displayName)")
        return channel.appcastURL
    }

    // MARK: - SPUStandardUserDriverDelegate

    // Called before showing any modal alert
    public nonisolated func standardUserDriverWillShowModalAlert() {
        Self.staticLogger.debug("Sparkle will show modal alert")
    }

    // Called after showing any modal alert
    public nonisolated func standardUserDriverDidShowModalAlert() {
        Self.staticLogger.debug("Sparkle did show modal alert")
    }

    // MARK: - Gentle Reminders Implementation

    /// Handles gentle reminders for background update notifications
    /// This prevents the warning about background apps not implementing gentle reminders
    public nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool) -> Bool {
        Self.staticLogger.info("Handling scheduled update notification for version \(update.displayVersionString)")

        // For background apps (when not in immediate focus), we handle the gentle reminder ourselves
        if !immediateFocus {
            Self.staticLogger.info("App not in focus, scheduling gentle reminder for update")

            // Schedule a gentle reminder using the notification center
            let updateVersion = update.displayVersionString
            Task { @MainActor in
                await self.showGentleUpdateReminder(updateVersion: updateVersion)
            }

            // Return true to indicate we're handling this ourselves
            return true
        }

        // When app is in immediate focus, let Sparkle handle it normally
        Self.staticLogger.info("App in focus, letting Sparkle handle update notification")
        return false
    }

    /// Shows a gentle reminder notification for available updates
    @MainActor
    private func showGentleUpdateReminder(updateVersion: String) async {
        Self.staticLogger.info("Showing gentle reminder for update to version \(updateVersion)")

        // Import UserNotifications framework at the top if not already imported
        let content = UNMutableNotificationContent()
        content.title = "Update Available"
        content.body = "Vibe Meter \(updateVersion) is available. Click to update."
        content.sound = .default
        content.categoryIdentifier = "UPDATE_AVAILABLE"

        // Add user info to handle the action
        content.userInfo = ["updateVersion": updateVersion]

        let request = UNNotificationRequest(
            identifier: "sparkle-update-\(updateVersion)",
            content: content,
            trigger: nil // Show immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            Self.staticLogger.info("Gentle reminder notification scheduled successfully")
        } catch {
            Self.staticLogger.error("Failed to schedule gentle reminder notification: \(error)")

            // Fallback: let Sparkle handle it the normal way
            updaterController.updater.checkForUpdates()
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground for gentle reminders
        completionHandler([.banner, .sound])
        Self.staticLogger.debug("Presenting update notification while app in foreground")
    }

    /// Handle notification interaction (user tapped or used action)
    public nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier

        Task { @MainActor in
            switch actionIdentifier {
            case "UPDATE_NOW", UNNotificationDefaultActionIdentifier:
                Self.staticLogger.info("User chose to update now from notification")
                // Trigger the update UI
                self.updaterController.updater.checkForUpdates()

            case "LATER":
                Self.staticLogger.info("User chose to update later from notification")
                // Do nothing - user will be reminded later

            default:
                Self.staticLogger.debug("Unknown notification action: \(actionIdentifier)")
            }
        }

        // Call completion handler immediately to avoid race conditions
        completionHandler()
    }
}
