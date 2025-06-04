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
        // Store the content view to prevent deallocation in Release builds
        let wrappedView = AnyView(contentView)
        self.retainedContentView = wrappedView

        // Create content view controller with the wrapped view
        hostingController = NSHostingController(rootView: wrappedView)

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
        level = .popUpMenu // Use popUpMenu level for menu bar dropdowns
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isMovableByWindowBackground = false
        hidesOnDeactivate = false // Important for menu bar apps
        isReleasedWhenClosed = false // Keep window in memory

        // Window properties are configured by overriding computed properties

        // Set content view controller
        contentViewController = hostingController

        // IMPORTANT: Force the view to load immediately
        // This prevents issues in Release builds where the view might not be created
        _ = hostingController.view

        // Add visual effect background with rounded corners
        if let contentView = contentViewController?.view {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 12
            contentView.layer?.masksToBounds = true

            // Add subtle shadow
            contentView.shadow = NSShadow()
            contentView.shadow?.shadowOffset = NSSize(width: 0, height: -2)
            contentView.shadow?.shadowBlurRadius = 8
            contentView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.2)
        }

        // Event monitoring is set up after showing the window
    }

    func show(relativeTo statusItemButton: NSStatusBarButton) {
        // Use modern macOS 15 window positioning APIs for better reliability
        guard let statusWindow = statusItemButton.window else { return }

        // Get status item frame in screen coordinates using modern APIs
        let buttonBounds = statusItemButton.bounds
        let buttonFrameInWindow = statusItemButton.convert(buttonBounds, to: nil)
        let buttonFrameInScreen = statusWindow.convertToScreen(buttonFrameInWindow)

        // First, make sure the SwiftUI hierarchy has laid itself out so the
        // hosting view reports an accurate fitting size.
        hostingController.view.layoutSubtreeIfNeeded()

        // Determine the preferred size based on the content's intrinsic size
        let fittingSize = hostingController.view.fittingSize
        let preferredSize = NSSize(width: fittingSize.width, height: fittingSize.height)

        // Update the panel's content size so auto-layout inside the window gets
        // the right dimensions.
        setContentSize(preferredSize)

        // Calculate optimal position with screen boundary awareness using the
        // freshly computed preferred size.
        let targetFrame = calculateOptimalFrame(
            relativeTo: buttonFrameInScreen,
            preferredSize: preferredSize)

        setFrame(targetFrame, display: false)

        // Ensure the hosting controller's view is loaded
        // This is critical for Release builds
        _ = hostingController.view
        hostingController.view.needsLayout = true

        // Make the window visible and active
        // The orderFront nil pattern is more reliable than makeKeyAndOrderFront
        // for utility windows, ensuring the window shows even if the app isn't active
        orderFront(nil)

        // After showing, setup event monitoring for dismissal
        setupEventMonitoring()
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

        // Ensure window is actually visible before setting up monitoring
        guard isVisible else { return }

        // Monitor clicks outside the window with stronger reference management
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.isVisible else { return }

            // Get the mouse location in screen coordinates
            let mouseLocation = NSEvent.mouseLocation

            // Check if click is outside our window frame
            if !self.frame.contains(mouseLocation) {
                self.hide()
            }
        }

        isEventMonitoringActive = true
    }

    private func teardownEventMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
            isEventMonitoringActive = false
        }
    }

    override func resignKey() {
        super.resignKey()
        hide()
    }

    // Override computed properties for window behavior
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
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