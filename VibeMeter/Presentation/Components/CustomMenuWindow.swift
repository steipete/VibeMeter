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
    private var observableTrackingView: ObservableMenuWindowView?

    /// Closure to be called when window hides
    var onHide: (() -> Void)?

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
        hasShadow = true
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
            contentView.shadow?.shadowOffset = NSSize(width: 0, height: -1)
            contentView.shadow?.shadowBlurRadius = 12
            contentView.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.3)
        }

        // Event monitoring is set up after showing the window
    }

    func show(relativeTo statusItemButton: NSStatusBarButton) {
        // First, make sure the SwiftUI hierarchy has laid itself out so the
        // hosting view reports an accurate fitting size.
        hostingController.view.layoutSubtreeIfNeeded()

        // Determine the preferred size based on the content's intrinsic size
        let fittingSize = hostingController.view.fittingSize
        let preferredSize = NSSize(width: fittingSize.width, height: fittingSize.height)

        // Update the panel's content size so auto-layout inside the window gets
        // the right dimensions.
        setContentSize(preferredSize)

        // Check if we can get the status button's window and position
        if let statusWindow = statusItemButton.window {
            // Get status item frame in screen coordinates using modern APIs
            let buttonBounds = statusItemButton.bounds
            let buttonFrameInWindow = statusItemButton.convert(buttonBounds, to: nil)
            let buttonFrameInScreen = statusWindow.convertToScreen(buttonFrameInWindow)

            // Check if the button frame is valid and visible
            // When the icon is hidden by apps like Ice, the frame might have zero width/height
            // or be positioned off-screen. In these cases, we need to fall back to a fixed
            // position at the top right of the screen.
            if buttonFrameInScreen.width > 0, buttonFrameInScreen.height > 0 {
                // Normal case: Calculate optimal position relative to the status bar icon
                let targetFrame = calculateOptimalFrame(
                    relativeTo: buttonFrameInScreen,
                    preferredSize: preferredSize)

                setFrame(targetFrame, display: false)
            } else {
                // Fallback case: Icon is hidden by menu bar management apps
                // Position the popover at the top right of the screen instead
                // This ensures users can still access VibeMeter when the icon is not visible
                showAtTopRightFallback(withSize: preferredSize)
            }
        } else {
            // Fallback case: Can't get the status button's window at all
            // This is rare but can happen in certain edge cases
            showAtTopRightFallback(withSize: preferredSize)
        }

        // Ensure the hosting controller's view is loaded
        // This is critical for Release builds
        _ = hostingController.view

        // Robust window display approach to prevent hanging
        displayWindowSafely()
        
        // Set up observable tracking if we have Observable data to track
        setupObservableTracking(relativeTo: statusItemButton)
    }

    /// Safely displays the window using multiple fallback strategies to prevent hanging.
    ///
    /// This method implements a robust window display strategy to prevent the common
    /// hanging issue that occurs when mixing AppKit and SwiftUI, especially on first run.
    ///
    /// The approach uses multiple strategies:
    /// 1. `orderFrontRegardless()` - More reliable than `makeKeyAndOrderFront()`
    /// 2. App activation to ensure proper window ordering context
    /// 3. Async dispatch with verification to handle timing issues
    /// 4. Multiple fallback strategies to ensure window appears
    private func displayWindowSafely() {
        // Strategy 1: Try immediate display with orderFrontRegardless (most reliable)
        alphaValue = 0

        // First, ensure the app is active (this can prevent many display issues)
        NSApp.activate(ignoringOtherApps: true)

        // Small delay to ensure window is fully displayed before animation
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(10))

            // Verify window is actually visible before animating
            if self.isVisible {
                self.animateWindowIn()
                self.setupEventMonitoring()
            } else {
                // Fallback: retry with async
                await self.displayWindowFallback()
            }
        }
    }

    /// Fallback window display method using async
    private func displayWindowFallback() async {
        // Alternative approach: try makeKeyAndOrderFront with app activation
        NSApp.activate(ignoringOtherApps: true)
        self.makeKeyAndOrderFront(nil)

        // Final fallback after short delay
        try? await Task.sleep(for: .milliseconds(50))

        if self.isVisible {
            self.animateWindowIn()
            self.setupEventMonitoring()
        } else {
            // Last resort: force ordering front regardless of state
            self.orderFrontRegardless()
            self.alphaValue = 1.0 // Skip animation if there are issues
            self.setupEventMonitoring()
        }
    }

    /// Animates the window appearance
    private func animateWindowIn() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0) // Material Design easing
            context.allowsImplicitAnimation = true
            self.animator().alphaValue = 1
        }
    }

    /// Animates the window to a new size without flipping
    func animateToSize(_ newSize: NSSize, relativeTo statusItemButton: NSStatusBarButton) {
        guard let statusWindow = statusItemButton.window else { return }

        // Get status item frame for positioning
        let buttonBounds = statusItemButton.bounds
        let buttonFrameInWindow = statusItemButton.convert(buttonBounds, to: nil)
        let buttonFrameInScreen = statusWindow.convertToScreen(buttonFrameInWindow)

        // Calculate new frame with updated size
        let newFrame = calculateOptimalFrame(
            relativeTo: buttonFrameInScreen,
            preferredSize: newSize)

        // Animate the frame change
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0)
            context.allowsImplicitAnimation = true
            animator().setFrame(newFrame, display: true)
        }
    }

    /// Calculates optimal window frame position with screen boundary awareness
    private func calculateOptimalFrame(relativeTo statusFrame: NSRect, preferredSize: NSSize) -> NSRect {
        guard let screen = NSScreen.main else {
            // Fallback to simple positioning
            let x = statusFrame.midX - preferredSize.width / 2
            let y = statusFrame.minY - preferredSize.height - 5
            return NSRect(origin: NSPoint(x: x, y: y), size: preferredSize)
        }

        let screenFrame = screen.visibleFrame
        let gap: CGFloat = 5

        // Start with centered position below status item
        var x = statusFrame.midX - preferredSize.width / 2
        let y = statusFrame.minY - preferredSize.height - gap

        // Ensure window stays within screen bounds
        let minX = screenFrame.minX + 10 // 10px margin from screen edge
        let maxX = screenFrame.maxX - preferredSize.width - 10
        x = max(minX, min(maxX, x))

        // Ensure window doesn't go below screen
        let finalY = max(screenFrame.minY + 10, y)

        return NSRect(
            origin: NSPoint(x: x, y: finalY),
            size: preferredSize)
    }

    /// Shows the window at the top right of the screen as a fallback position.
    ///
    /// This fallback is used when the menu bar icon cannot be located, typically when:
    /// - The icon is hidden by menu bar management apps like Ice or Bartender
    /// - The status item frame has zero dimensions
    /// - The status button window is unavailable
    ///
    /// The window will appear at the top-right corner of the screen, just below
    /// the menu bar, ensuring users can still access VibeMeter even when the
    /// menu bar icon is not visible.
    private func showAtTopRightFallback(withSize preferredSize: NSSize) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let menuBarHeight: CGFloat = 25 // Standard menu bar height
        let rightMargin: CGFloat = 10
        let gap: CGFloat = 5

        // Position at top right, just below the menu bar
        let x = screenFrame.maxX - preferredSize.width - rightMargin
        let y = screenFrame.maxY - menuBarHeight - preferredSize.height - gap

        let fallbackFrame = NSRect(
            origin: NSPoint(x: x, y: y),
            size: preferredSize)

        setFrame(fallbackFrame, display: false)
    }

    func hide() {
        // Immediately remove from screen (no animation) to avoid toggle state issues
        orderOut(nil)
        teardownEventMonitoring()
        teardownObservableTracking()
        onHide?()
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        // Ensure onHide is called even if window is closed by system
        if isVisible == false {
            onHide?()
        }
    }

    private func setupEventMonitoring() {
        // Ensure we don't have duplicate monitors
        teardownEventMonitoring()

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
    
    // MARK: - Observable Tracking
    
    private func setupObservableTracking(relativeTo statusItemButton: NSStatusBarButton) {
        // Only set up tracking if we can access the app delegate's Observable data
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        
        observableTrackingView = ObservableMenuWindowView(
            menuWindow: self,
            statusBarButton: statusItemButton,
            userSession: appDelegate.userSession,
            spendingData: appDelegate.spendingData)
        
        if let trackingView = observableTrackingView,
           let contentView = contentView {
            trackingView.frame = contentView.bounds
            trackingView.autoresizingMask = [.width, .height]
            contentView.addSubview(trackingView)
        }
    }
    
    private func teardownObservableTracking() {
        observableTrackingView?.removeFromSuperview()
        observableTrackingView = nil
    }

    deinit {
        // Ensure proper cleanup of event monitoring
        // Since this class is @MainActor and deinit is called when deallocating,
        // we can assume we're on the main actor
        MainActor.assumeIsolated {
            teardownEventMonitoring()
            teardownObservableTracking()
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

    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        content
            // Let both width and height be dictated by the intrinsic size
            .fixedSize()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1))
    }

    private var borderColor: Color {
        switch colorScheme {
        case .dark:
            Color.white.opacity(0.1)
        case .light:
            Color.white.opacity(0.8)
        @unknown default:
            Color.white.opacity(0.5)
        }
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
