import AppKit
import SwiftUI

/// Window controller for the terminal-style view
@MainActor
final class TerminalWindowController: NSWindowController {
    private static var shared: TerminalWindowController?
    
    static func showWindow() {
        if let existingWindow = shared {
            existingWindow.showWindow(nil)
            existingWindow.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = TerminalStyleView()
            .settingsManager(SettingsManager.shared)
            .environment(MultiProviderDataOrchestrator.shared.spendingData)
            .environment(MultiProviderDataOrchestrator.shared.currencyData)
            .environment(\.userSessionData, MultiProviderDataOrchestrator.shared.userSessionData)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "VibeMeter Terminal"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("TerminalView")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 600, height: 400)
        
        // Set dark appearance for terminal feel
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
        
        // Remove toolbar for terminal aesthetic
        window.toolbar = nil
        window.standardWindowButton(.zoomButton)?.isHidden = true
        
        let windowController = TerminalWindowController(window: window)
        windowController.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        
        shared = windowController
        
        // Clean up when window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor in
                TerminalWindowController.shared = nil
            }
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
}