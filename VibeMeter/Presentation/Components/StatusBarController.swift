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
            self?.updateStatusItemDisplay()
        }

        // Set up observer callbacks
        observer.onDataChanged = { [weak self] in
            self?.updateStatusItemDisplay()
        }

        observer.onStateUpdateNeeded = { [weak self] in
            self?.updateStatusItemState()
        }
    }

    private func startComponents() {
        animationController.startTimers()
        observer.startObserving()
    }

    func updateStatusItemDisplay() {
        guard let button = statusItem?.button else { return }

        // Update state manager first, then delegate display to DisplayManager
        updateStatusItemState()
        displayManager.updateDisplay(for: button)
    }

    private func updateStatusItemState() {
        let isLoggedIn = userSession.isLoggedInToAnyProvider
        let isFetchingData = orchestrator.isRefreshing.values.contains(true)
        let providers = spendingData.providersWithData
        let hasData = !providers.isEmpty

        // Update state manager
        if isFetchingData {
            // Show loading animation only when fetching data (not during authentication)
            stateManager.setState(.loading)
        } else if !isLoggedIn {
            stateManager.setState(.notLoggedIn)
        } else if !hasData {
            stateManager.setState(.loading)
        } else {
            let totalSpendingUSD = spendingData.totalSpendingConverted(
                to: "USD",
                rates: currencyData.effectiveRates)

            // Calculate gauge value based on whether money has been spent
            let gaugeValue: Double = {
                if settingsManager.gaugeRepresentation == .claudeQuota,
                   userSession.isLoggedIn(to: .claude) {
                    return calculateClaudeQuota()
                } else if totalSpendingUSD > 0 {
                    min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0)
                } else {
                    calculateRequestUsagePercentage()
                }
            }()

            // Only set new data state if the value has changed significantly
            if case .loading = stateManager.currentState {
                stateManager.setState(.data(value: gaugeValue))
            } else if case let .data(currentValue) = stateManager.currentState {
                if abs(currentValue - gaugeValue) > 0.01 {
                    stateManager.setState(.data(value: gaugeValue))
                }
            } else {
                stateManager.setState(.data(value: gaugeValue))
            }
        }
    }

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
        if menuManager.isCustomWindowVisible {
            // If custom window is visible, hide it
            menuManager.hideCustomWindow()
        } else {
            // If custom window is not visible, show it (this will hide context menu if it's showing)
            menuManager.showCustomWindow(relativeTo: button)
        }
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

    /// Calculates the request usage percentage across all providers
    private func calculateRequestUsagePercentage() -> Double {
        let providers = spendingData.providersWithData

        // Use same logic as ProviderUsageBadgeView for consistency
        for provider in providers {
            if let providerData = spendingData.getSpendingData(for: provider),
               let usageData = providerData.usageData,
               let maxRequests = usageData.maxRequests, maxRequests > 0 {
                // Calculate percentage using same formula as progress bar
                let progress = min(Double(usageData.currentRequests) / Double(maxRequests), 1.0)
                return progress
            }
        }

        return 0.0
    }

    private func calculateClaudeQuota() -> Double {
        // Very rough placeholder until detailed five-hour window is implemented
        // Simply returns 0 if unavailable or percentage used based on 5 hours
        let entries = ClaudeLogManager.shared
        let daily = await entries.getDailyUsage()
        let windowSeconds: Double = 5 * 60 * 60
        var usedSeconds: Double = 0
        for (_, list) in daily {
            usedSeconds += list.reduce(0) { $0 + Double($1.inputTokens + $1.outputTokens) / 15.0 }
        }
        return min(max(usedSeconds / windowSeconds, 0), 1)
    }

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
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            button.addTrackingArea(trackingArea)
        }
    }
    
    @objc func mouseEntered(_ event: NSEvent) {
        // Force tooltip update when mouse enters the status bar button
        updateTooltipOnDemand()
    }
    
    @objc func mouseExited(_ event: NSEvent) {
        // Optional: Could implement if we want to do something on exit
    }
    
    private func updateTooltipOnDemand() {
        guard let button = statusItem?.button else { return }
        
        // Create tooltip provider and get fresh tooltip text
        let tooltipProvider = StatusBarTooltipProvider(
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager
        )
        
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
            if let button = statusItem?.button, let trackingArea = trackingArea {
                button.removeTrackingArea(trackingArea)
            }
        }
    }
}
