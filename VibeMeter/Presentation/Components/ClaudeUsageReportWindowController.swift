import AppKit
import os.log
import SwiftUI

/// Window controller for displaying the Claude Usage Report in its own window
@MainActor
final class ClaudeUsageReportWindowController: NSWindowController {
    // MARK: - Properties

    private static var sharedWindow: ClaudeUsageReportWindowController?
    private let logger = Logger.vibeMeter(category: "ClaudeUsageReportWindow")

    // MARK: - Initialization

    convenience init() {
        let window = NSWindow()
        self.init(window: window)

        configureWindow()
        setupContentView()
    }

    // MARK: - Public Methods

    /// Shows the Claude Usage Report window, creating it if necessary
    static func showWindow() {
        if let existingWindow = sharedWindow {
            // Window already exists, just bring it to front
            existingWindow.showWindow(nil)
            if let window = existingWindow.window {
                // First, ensure the app is active
                NSApp.activate(ignoringOtherApps: true)
                // Make the window key and bring to front
                window.makeKeyAndOrderFront(nil)
                // Ensure window is on the active space
                window.collectionBehavior = [.moveToActiveSpace, .managed]
                // Force window to front by setting level temporarily
                window.level = .floating
                DispatchQueue.main.async {
                    window.level = .normal
                }
            }
        } else {
            // Create new window
            let windowController = ClaudeUsageReportWindowController()
            windowController.showWindow(nil)
            sharedWindow = windowController
            
            // Ensure new window appears in foreground
            if let window = windowController.window {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
                window.collectionBehavior = [.moveToActiveSpace, .managed]
                // Force window to front by setting level temporarily
                window.level = .floating
                DispatchQueue.main.async {
                    window.level = .normal
                }
            }
        }
    }

    // MARK: - Private Methods

    private func configureWindow() {
        guard let window else { return }

        window.title = "Claude Token Usage Report"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.isReleasedWhenClosed = false
        window.center()
        
        // Configure window behavior to ensure it appears in foreground
        window.collectionBehavior = [.moveToActiveSpace, .managed, .fullScreenAuxiliary]

        // Set minimum and initial size
        window.setContentSize(NSSize(width: 900, height: 650))
        window.minSize = NSSize(width: 700, height: 500)

        // Configure for toolbar
        window.titlebarAppearsTransparent = false
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = false
        window.toolbarStyle = .unified

        // Add visual effect to window
        window.backgroundColor = .clear

        // Set up delegate to handle window close
        window.delegate = self
    }

    private func setupContentView() {
        guard let window else { return }

        // Create the SwiftUI view with material background
        let contentView = NavigationStack {
            ZStack {
                // Material background
                VisualEffectBackground()

                // Main content
                ClaudeUsageReportView()
                    .background(.clear)
            }
        }
        .environment(SettingsManager.shared)

        // Create hosting controller and set as content
        let hostingController = NSHostingController(rootView: contentView)
        window.contentViewController = hostingController

        logger.info("Claude Usage Report window configured successfully")
    }
}

// MARK: - NSWindowDelegate

extension ClaudeUsageReportWindowController: NSWindowDelegate {
    func windowWillClose(_: Notification) {
        // Clear the shared reference when window closes
        Self.sharedWindow = nil
        logger.debug("Claude Usage Report window closed")
    }

    func windowShouldClose(_: NSWindow) -> Bool {
        // Allow window to close
        true
    }
}

// MARK: - Visual Effect Background

/// A SwiftUI view that provides a macOS material background with visual effects
private struct VisualEffectBackground: View {
    @Environment(\.colorScheme)
    var colorScheme

    var body: some View {
        // Use SwiftUI's built-in materials
        Rectangle()
            .fill(.regularMaterial)
            .ignoresSafeArea()
    }
}
