import AppKit
import SwiftUI

/// Window controller for the analytics dashboard
@MainActor
final class AnalyticsDashboardWindowController: NSWindowController {
    private static var shared: AnalyticsDashboardWindowController?
    
    static func showWindow() {
        if let existingWindow = shared {
            existingWindow.showWindow(nil)
            existingWindow.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = AnalyticsDashboardView()
            .settingsManager(SettingsManager.shared)
            .environment(MultiProviderDataOrchestrator.shared.spendingData)
            .environment(MultiProviderDataOrchestrator.shared.currencyData)
            .environment(\.userSessionData, MultiProviderDataOrchestrator.shared.userSessionData)
        
        let hostingController = NSHostingController(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "VibeMeter Analytics"
        window.contentViewController = hostingController
        window.center()
        window.setFrameAutosaveName("AnalyticsDashboard")
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .visible
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 800, height: 600)
        
        // Set window appearance
        window.appearance = NSAppearance(named: .darkAqua)
        
        // Configure toolbar
        window.toolbar = NSToolbar()
        window.toolbar?.displayMode = .iconOnly
        window.toolbarStyle = .unified
        
        let windowController = AnalyticsDashboardWindowController(window: window)
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
                AnalyticsDashboardWindowController.shared = nil
            }
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
}