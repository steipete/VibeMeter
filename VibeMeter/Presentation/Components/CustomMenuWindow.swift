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
    private let hostingController: NSViewController

    init(contentView: some View) {
        // Create content view controller
        hostingController = NSHostingController(rootView: contentView)

        // Initialize window with appropriate style
        // Start with a minimal height – the real height will be determined from
        // the SwiftUI view's intrinsic content size before the panel is shown.
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)

        // Configure window appearance
        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false

        // Set content view controller
        contentViewController = hostingController

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

        // Determine the preferred height based on the content. We fix the
        // width to 300 pt for consistency with the design language.
        let preferredHeight = hostingController.view.fittingSize.height
        let preferredSize = NSSize(width: 300, height: preferredHeight)

        // Update the panel's content size so auto-layout inside the window gets
        // the right dimensions.
        setContentSize(preferredSize)

        // Calculate optimal position with screen boundary awareness using the
        // freshly computed preferred size.
        let targetFrame = calculateOptimalFrame(
            relativeTo: buttonFrameInScreen,
            preferredSize: preferredSize)

        setFrame(targetFrame, display: false)

        // Use modern animation APIs with better timing
        alphaValue = 0
        makeKeyAndOrderFront(nil)

        // Modern animation with improved easing
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.0, 0.2, 1.0) // Material Design easing
            context.allowsImplicitAnimation = true
            animator().alphaValue = 1
        }

        // Set up event monitoring with better timing
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            setupEventMonitoring()
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

    func hide() {
        // Animate out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.teardownEventMonitoring()
        })
    }

    private func setupEventMonitoring() {
        // Ensure we don't have duplicate monitors
        teardownEventMonitoring()

        // Monitor clicks outside the window
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }

            // Get the mouse location in screen coordinates
            let mouseLocation = NSEvent.mouseLocation

            // Check if click is outside our window frame
            if !self.frame.contains(mouseLocation) {
                self.hide()
            }
        }
    }

    private func teardownEventMonitoring() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    override func resignKey() {
        super.resignKey()
        hide()
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
            .frame(width: 300)
            // Let the height be dictated by the intrinsic size so the panel
            // grows or shrinks exactly to the content we supply.
            .fixedSize(horizontal: false, vertical: true)
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
