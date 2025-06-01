import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    private var settingsView: SettingsView?

    private init() {
        // Create the window itself. Content view will be set to NSHostingView<SettingsView>
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.title = "Vibe Meter Settings"
        super.init(window: window)

        // settingsView = SettingsView(settingsManager: SettingsManager.shared, dataCoordinator: DataCoordinator.shared)
        // let hostingView = NSHostingView(rootView: settingsView)
        // window.contentView = hostingView
        // For now, we'll set it up in showWindow to ensure DataCoordinator is fully up
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        if window?.contentView == nil || !(window?.contentView is NSHostingView<SettingsView>) {
            // Ensure DataCoordinator.shared is fully initialized before SettingsView tries to use it.
            // We pass DataCoordinator.shared to SettingsView if it needs more than just SettingsManager.
            settingsView = SettingsView(
                settingsManager: SettingsManager.shared,
                dataCoordinator: DataCoordinator.shared as! RealDataCoordinator
            )
            if let settingsView = settingsView {
                let hostingView = NSHostingView(rootView: settingsView)
                window?.contentView = hostingView
            }
        }
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
