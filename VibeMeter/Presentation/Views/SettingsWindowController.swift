import AppKit
import SwiftUI

// Note: In modern SwiftUI apps, you typically use the Settings scene
// This controller is kept for backward compatibility if needed
@MainActor
final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false)
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.title = "VibeMeter Settings"
        window.titlebarAppearsTransparent = false
        window.isMovableByWindowBackground = true

        super.init(window: window)

        setupContentView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupContentView() {
        let settingsView = SettingsView(
            settingsManager: SettingsManager.shared,
            dataCoordinator: DataCoordinator.shared as! DataCoordinator)

        let hostingView = NSHostingView(rootView: settingsView)
        window?.contentView = hostingView
    }

    override func showWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
        NSApp.activate(ignoringOtherApps: true)
    }
}
