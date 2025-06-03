import AppKit
import os.log
import SwiftUI

// MARK: - App Entry Point

@main
struct VibeMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    var body: some Scene {
        // MenuBarExtra for the status bar menu
        MenuBarExtra {
            MenuBarContentView(
                settingsManager: appDelegate.settingsManager,
                dataCoordinator: appDelegate.dataCoordinator)
        } label: {
            HStack(spacing: 4) {
                Image("menubar-icon")
                    .renderingMode(.template)

                if !appDelegate.dataCoordinator.menuBarDisplayText.isEmpty {
                    Text(appDelegate.dataCoordinator.menuBarDisplayText)
                        .font(.system(size: 13))
                }
            }
        }
        .menuBarExtraStyle(.window)

        // Settings window using modern SwiftUI
        Settings {
            SettingsView(
                settingsManager: appDelegate.settingsManager,
                dataCoordinator: appDelegate.dataCoordinator)
        }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    private(set) var sparkleUpdaterManager: SparkleUpdaterManager?

    // Expose for SwiftUI Scene
    let settingsManager = SettingsManager.shared
    lazy var dataCoordinator: DataCoordinator = {
        // Ensure we're accessing the shared instance safely
        guard let coordinator = DataCoordinator.shared as? DataCoordinator else {
            fatalError("DataCoordinator.shared must be of type DataCoordinator")
        }
        return coordinator
    }()

    private let logger = Logger(subsystem: "com.vibemeter", category: "AppLifecycle")

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_: Notification) {
        logger.info("VibeMeter launching...")

        // Initialize core services
        _ = DataCoordinator.shared

        // Initialize auto-updater
        #if !DEBUG
            sparkleUpdaterManager = SparkleUpdaterManager()
        #endif

        // Initial data refresh
        Task {
            await DataCoordinator.shared.forceRefreshData(showSyncedMessage: false)
        }

        logger.info("VibeMeter launched successfully")
    }

    func applicationWillTerminate(_: Notification) {
        logger.info("VibeMeter terminating...")

        // Cleanup
        DataCoordinator.shared.cleanup()

        logger.info("VibeMeter terminated")
    }

    func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
        true
    }
}
