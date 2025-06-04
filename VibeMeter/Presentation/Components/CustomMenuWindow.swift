import AppKit
import SwiftUI

/// Custom borderless window that appears below the menu bar icon.
///
/// CustomMenuWindow provides a dropdown-style window for the menu bar application
/// without the standard macOS popover arrow. It handles automatic positioning below
/// the status item, click-outside dismissal, and proper window management for a
/// seamless menu bar app experience.
@MainActor
final class CustomMenuWindow: NSPanel {
    private var eventMonitor: Any?
    private let hostingController: NSHostingController<AnyView>
    private var retainedContentView: AnyView?
    private var isEventMonitoringActive = false

    init(contentView: some View) {
        // Create content view controller directly without extra wrapping
        hostingController = NSHostingController(rootView: AnyView(contentView))
        
        // Store reference to prevent deallocation
        self.retainedContentView = hostingController.rootView

        // Initialize window with appropriate style
        // Start with a minimal size – the real size will be determined from
        // the SwiftUI view's intrinsic content size before the panel is shown.
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 400),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false)

        // Configure window appearance
        isOpaque = false
        backgroundColor = .clear
        level = .floating // Use floating level instead of popUpMenu to avoid conflicts
        // Simplified collection behavior to avoid conflicts
        collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        
        // Disable animations which can cause hangs
        animationBehavior = .none

        // Set content view controller
        contentViewController = hostingController

        // Ensure the view is loaded and configured
        let contentView = hostingController.view
        contentView.wantsLayer = true
        
        // Apply styling to the content view
        if let layer = contentView.layer {
            layer.cornerRadius = 12
            layer.masksToBounds = true
            
            // Add subtle shadow
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -2)
            shadow.shadowBlurRadius = 8
            shadow.shadowColor = NSColor.black.withAlphaComponent(0.2)
            contentView.shadow = shadow
        }
    }

    func show(relativeTo statusItemButton: NSStatusBarButton) {
        // Use modern macOS 15 window positioning APIs for better reliability
        guard let statusWindow = statusItemButton.window else { return }

        // Get status item frame in screen coordinates using modern APIs
        let buttonBounds = statusItemButton.bounds
        let buttonFrameInWindow = statusItemButton.convert(buttonBounds, to: nil)
        let buttonFrameInScreen = statusWindow.convertToScreen(buttonFrameInWindow)

        // Ensure the hosting controller's view is properly loaded before any layout operations
        let view = hostingController.view
        view.layoutSubtreeIfNeeded()

        // Determine the preferred size based on the content's intrinsic size
        let fittingSize = view.fittingSize
        let preferredSize = NSSize(width: fittingSize.width, height: fittingSize.height)

        // Update the panel's content size
        setContentSize(preferredSize)

        // Calculate optimal position with screen boundary awareness
        let targetFrame = calculateOptimalFrame(
            relativeTo: buttonFrameInScreen,
            preferredSize: preferredSize)

        // Set frame without display to avoid flicker
        setFrame(targetFrame, display: false)

        // Defer window display to next run loop to avoid hangs
        // This ensures all window properties are properly set before display
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            // Make the window visible without making it key
            // For menu bar apps, we don't want to steal key status from other apps
            self.orderFrontRegardless()
            
            // Make it main to receive events
            self.makeMain()
            
            // Setup event monitoring after showing the window
            self.setupEventMonitoring()
        }
    }

    func hide() {
        // Tear down event monitoring first to prevent re-entrancy
        teardownEventMonitoring()

        // Using orderOut(nil) instead of close() allows the window to be reused
        orderOut(nil)
    }

    private func calculateOptimalFrame(relativeTo statusItemFrame: NSRect, preferredSize: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            // Fallback position if no screen available
            return NSRect(x: 100, y: 100, width: preferredSize.width, height: preferredSize.height)
        }

        let screenFrame = screen.visibleFrame
        let spacing: CGFloat = 8 // Gap between status item and window

        // Calculate horizontal position (centered under status item)
        let centeredX = statusItemFrame.midX - (preferredSize.width / 2)

        // Ensure window stays within screen bounds horizontally
        let minX = screenFrame.minX + 10
        let maxX = screenFrame.maxX - preferredSize.width - 10
        let constrainedX = max(minX, min(centeredX, maxX))

        // Position below status item
        let y = statusItemFrame.minY - preferredSize.height - spacing

        return NSRect(x: constrainedX, y: y, width: preferredSize.width, height: preferredSize.height)
    }

    private func setupEventMonitoring() {
        // Prevent duplicate monitors with explicit check
        guard !isEventMonitoringActive else { return }

        // Use local event monitor instead of global to avoid accessibility permission issues
        // This monitors events in the application's event stream only
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }

            // Check if click is outside our window
            let clickLocation = event.locationInWindow
            let windowFrame = self.frame
            let screenLocation = event.window?.convertPoint(toScreen: clickLocation) ?? clickLocation
            
            if !windowFrame.contains(screenLocation) {
                // Click is outside our window, hide it
                self.hide()
            }

            // Always return the event to allow normal processing
            return event
        }

        isEventMonitoringActive = true
    }

    private func teardownEventMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        isEventMonitoringActive = false
    }

    override func resignKey() {
        super.resignKey()
        hide()
    }
    
    // Override resignMain to handle when window loses main status
    override func resignMain() {
        super.resignMain()
        // Hide when we lose main status (clicked outside)
        hide()
    }

    // Override computed properties for window behavior
    override var canBecomeKey: Bool {
        // Don't become key window to avoid stealing focus
        false
    }

    override var canBecomeMain: Bool {
        // Allow becoming main for proper event handling
        true
    }

    deinit {
        // Ensure proper cleanup of event monitoring
        // Since this class is @MainActor and deinit is called when deallocating,
        // we can assume we're on the main actor
        MainActor.assumeIsolated {
            teardownEventMonitoring()
        }
    }
}

/// A wrapper view that applies modern SwiftUI material background to menu content.
///
/// This container provides consistent styling for menu content with proper sizing,
/// material background effects, and rounded corners. It ensures uniform appearance
/// across different menu states and content types.
struct CustomMenuContainer<Content: View>: View {
    @ViewBuilder
    let content: Content

    var body: some View {
        content
            // Let both width and height be dictated by the intrinsic size
            .fixedSize()
            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview("Custom Menu Container") {
    CustomMenuContainer {
        VStack(spacing: 16) {
            Text("VibeMeter")
                .font(.title2)
                .fontWeight(.semibold)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                Label("Settings", systemImage: "gear")
                Label("About", systemImage: "info.circle")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Spacer()

            Button("Log In") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            Spacer()
        }
        .padding()
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}

