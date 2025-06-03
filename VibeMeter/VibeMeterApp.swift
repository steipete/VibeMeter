import SwiftUI

@main
struct VibeMeterApp: App {
    // The AppDelegate will handle the setup of the menu bar item and other non-window-based app lifecycle events.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Vibe Meter is a menu bar only app, so it doesn't define a WindowGroup here.
        // The Settings window will be managed by SettingsWindowController.
        // If you wanted a main window, you would define it here:
        // WindowGroup {
        //     ContentView()
        // }

        // For a menu bar app that can open a settings window, ensure that the settings scene is defined
        // if using SwiftUI App lifecycle for settings window management is preferred over manual NSWindow.
        // However, since we are using SettingsWindowController (manual NSWindow), this is not strictly necessary here.
        // If we were to use SwiftUI Settings scene:
        // Settings {
        //     SettingsView(settingsManager: SettingsManager.shared, dataCoordinator: DataCoordinator.shared as! RealDataCoordinator)
        // }

        // An empty scene group or no scene group is fine if all windows are managed manually.
        // However, to ensure the app has a scene to keep it alive if all manual windows are closed
        // (and to provide a settings scene if we switch to SwiftUI handling for it):
        Settings { // This makes the "Settings" menu item in the App menu work if users expect it
            MacSettingsView(
                settingsManager: SettingsManager.shared,
                dataCoordinator: DataCoordinator.shared as! RealDataCoordinator
            )
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var sparkleUpdaterManager: SparkleUpdaterManager?
    // DataCoordinator is initialized as a shared instance and will initialize its dependencies.
    // We don't need to explicitly hold an instance here if MenuBarController uses DataCoordinator.shared

    func applicationDidFinishLaunching(_: Notification) {
        LoggingService.info("VibeMeter applicationDidFinishLaunching.", category: .lifecycle)

        // Initialize DataCoordinator and its dependencies.
        // This happens when DataCoordinator.shared is first accessed,
        // which will be by MenuBarController or SettingsView.
        // To be explicit, we can access it here to ensure it's up.
        _ = DataCoordinator.shared

        // Initialize MenuBarController
        menuBarController = MenuBarController() // It will use DataCoordinator.shared by default

        // Initialize Sparkle updater for auto-updates
        sparkleUpdaterManager = SparkleUpdaterManager()

        // Perform initial data load or check login status if needed explicitly here,
        // though DataCoordinator's init should handle its own startup logic.
        Task {
            // This will ensure data is fetched if logged in, or menu shows "Login Required"
            await DataCoordinator.shared.forceRefreshData(showSyncedMessage: false)
        }
    }

    func applicationWillTerminate(_: Notification) {
        LoggingService.info("VibeMeter applicationWillTerminate.", category: .lifecycle)
        // Clean up resources if necessary
    }

    // Optional: Handle app activation, e.g., when icon is clicked in Dock (if it appears)
    // For a pure menu bar app (LSUIElement = true), this might not be standard behavior.
    // func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    //     if !flag {
    //         SettingsWindowController.shared.showWindow(nil)
    //     }
    //     return true
    // }
}
