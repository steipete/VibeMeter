import AppKit
import Observation
import SwiftUI

/// Manages the macOS status bar item using focused component managers.
///
/// StatusBarController coordinates between specialized managers for display,
/// animation, menu window, and observation to provide a clean separation
/// of concerns while maintaining the same functionality.
@MainActor
final class StatusBarController: NSObject {
    // MARK: - Core Properties

    private var statusItem: NSStatusItem?
    private let stateManager = MenuBarStateManager()
    private var trackingArea: NSTrackingArea?
    private var observableDisplayView: ObservableStatusBarDisplayView?

    // MARK: - Component Managers

    private let displayManager: StatusBarDisplayManager
    private let menuManager: StatusBarMenuManager
    private let animationController: StatusBarAnimationController
    private let observer: StatusBarObserver

    // MARK: - Dependencies

    private let settingsManager: any SettingsManagerProtocol
    private let userSession: MultiProviderUserSessionData
    private let loginManager: MultiProviderLoginManager
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private let orchestrator: MultiProviderDataOrchestrator

    init(settingsManager: any SettingsManagerProtocol,
         userSession: MultiProviderUserSessionData,
         loginManager: MultiProviderLoginManager,
         spendingData: MultiProviderSpendingData,
         currencyData: CurrencyData,
         orchestrator: MultiProviderDataOrchestrator) {
        self.settingsManager = settingsManager
        self.userSession = userSession
        self.loginManager = loginManager
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.orchestrator = orchestrator

        // Initialize component managers
        self.displayManager = StatusBarDisplayManager(
            stateManager: stateManager,
            settingsManager: settingsManager,
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData)

        self.menuManager = StatusBarMenuManager()

        self.animationController = StatusBarAnimationController(stateManager: stateManager)

        self.observer = StatusBarObserver(
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager)

        super.init()

        setupStatusItem()
        setupMenuManager()
        setupCallbacks()
        startComponents()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.imagePosition = .imageLeading
            button.action = #selector(handleClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])

            // Accessibility support for menu bar button
            button.setAccessibilityTitle("VibeMeter")
            button.setAccessibilityRole(.button)
            button.setAccessibilityHelp("Shows AI service spending information and opens VibeMeter menu")

            // Set up tracking area for dynamic tooltip updates
            setupTrackingArea(for: button)

            // Add observable display view to leverage automatic tracking
            observableDisplayView = ObservableStatusBarDisplayView(
                statusBarButton: button,
                displayManager: displayManager,
                stateManager: stateManager,
                userSession: userSession,
                spendingData: spendingData,
                currencyData: currencyData,
                settingsManager: settingsManager,
                orchestrator: orchestrator)
            if let observableDisplayView {
                observableDisplayView.frame = button.bounds
                observableDisplayView.autoresizingMask = [.width, .height]
                button.addSubview(observableDisplayView)
            }

            updateStatusItemDisplay()
        }
    }

    private func setupMenuManager() {
        let configuration = StatusBarMenuManager.Configuration(
            settingsManager: settingsManager,
            userSession: userSession,
            loginManager: loginManager,
            spendingData: spendingData,
            currencyData: currencyData,
            orchestrator: orchestrator)
        menuManager.setup(with: configuration)
    }

    private func setupCallbacks() {
        // Set up animation controller callback
        animationController.onDisplayUpdateNeeded = { [weak self] in
            self?.observableDisplayView?.setNeedsDisplayAndLayout()
        }

        // With automatic observation tracking, we don't need most callbacks
        // Keep observer for non-Observable notifications (UserDefaults, appearance)
        observer.onDataChanged = { [weak self] in
            self?.observableDisplayView?.setNeedsDisplayAndLayout()
        }
    }

    private func startComponents() {
        animationController.startTimers()
        observer.startObserving()
    }

    func updateStatusItemDisplay() {
        // With automatic observation tracking, this method is now much simpler
        // The ObservableStatusBarDisplayView will handle updates automatically
        observableDisplayView?.setNeedsDisplayAndLayout()
    }

    // State update logic moved to ObservableStatusBarDisplayView

    @objc
    private func handleClick(_ sender: NSStatusBarButton) {
        guard let currentEvent = NSApp.currentEvent else {
            // Fallback to left click behavior if we can't determine the event
            handleLeftClick(sender)
            return
        }

        switch currentEvent.type {
        case .leftMouseUp:
            handleLeftClick(sender)
        case .rightMouseUp:
            handleRightClick(sender)
        default:
            handleLeftClick(sender)
        }
    }

    private func handleLeftClick(_ button: NSStatusBarButton) {
        // Use toggle method which handles button highlighting
        menuManager.toggleCustomWindow(relativeTo: button)
    }

    private func handleRightClick(_ button: NSStatusBarButton) {
        guard let statusItem else { return }
        // This will hide the custom window if it's visible and show the context menu
        menuManager.showContextMenu(for: button, statusItem: statusItem)
    }

    @objc
    private func toggleCustomWindow() {
        guard let button = statusItem?.button else { return }
        handleLeftClick(button)
    }

    @objc
    private func showCustomMenu() {
        guard let button = statusItem?.button else { return }
        handleRightClick(button)
    }

    @objc
    private func openSettings() {
        NSApp.openSettings()
    }

    /// Shows the custom window menu (used for initial display when not logged in)
    func showCustomWindow() {
        guard let button = statusItem?.button else { return }
        menuManager.showCustomWindow(relativeTo: button)
    }

    // Calculation methods moved to ObservableStatusBarDisplayView

    private func setupTrackingArea(for button: NSStatusBarButton) {
        // Remove existing tracking area if any
        if let existingTrackingArea = trackingArea {
            button.removeTrackingArea(existingTrackingArea)
        }

        // Create new tracking area
        trackingArea = NSTrackingArea(
            rect: button.bounds,
            options: [.activeAlways, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil)

        if let trackingArea {
            button.addTrackingArea(trackingArea)
        }
    }

    @objc
    func mouseEntered(_: NSEvent) {
        // Force tooltip update when mouse enters the status bar button
        updateTooltipOnDemand()
    }

    @objc
    func mouseExited(_: NSEvent) {
        // Optional: Could implement if we want to do something on exit
    }

    private func updateTooltipOnDemand() {
        guard let button = statusItem?.button else { return }

        // Create tooltip provider and get fresh tooltip text
        let tooltipProvider = StatusBarTooltipProvider(
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager)

        let freshTooltip = tooltipProvider.createTooltipText()
        button.toolTip = freshTooltip
    }

    deinit {
        // Since deinit cannot be marked as @MainActor, we need to assume we're on the main actor
        // since StatusBarController is @MainActor and deinit is called when the actor is being deallocated
        MainActor.assumeIsolated {
            animationController.stopTimers()
            observer.stopObserving()

            // Clean up tracking area
            if let button = statusItem?.button, let trackingArea {
                button.removeTrackingArea(trackingArea)
            }
        }
    }
}
