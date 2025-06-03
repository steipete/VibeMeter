import AppKit
import SwiftUI

/// A custom window that appears below the menu bar without an arrow
@MainActor
final class CustomMenuWindow: NSPanel {
    private var eventMonitor: Any?
    private let hostingController: NSViewController

    init(contentView: some View) {
        // Create content view controller
        hostingController = NSHostingController(rootView: contentView)

        // Initialize window with appropriate style
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 400),
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
        // Calculate position below status item
        guard let window = statusItemButton.window else { return }
        let buttonFrame = statusItemButton.convert(statusItemButton.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrame)

        // Position window centered below the status item
        let windowWidth = frame.width
        let x = screenFrame.midX - windowWidth / 2
        let y = screenFrame.minY - frame.height - 5 // 5px gap

        setFrameOrigin(NSPoint(x: x, y: y))

        // Animate in
        alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }

        // Set up event monitoring after a short delay to avoid immediate dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupEventMonitoring()
        }
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

/// A visual effect view that provides the background for the custom menu
struct CustomMenuBackground: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {
        // No updates needed
    }
}

/// A wrapper view that applies the custom background to content
struct CustomMenuContainer<Content: View>: View {
    @ViewBuilder
    let content: Content

    var body: some View {
        ZStack {
            CustomMenuBackground()
                .ignoresSafeArea()

            content
        }
        .frame(width: 320, height: 400)
    }
}
