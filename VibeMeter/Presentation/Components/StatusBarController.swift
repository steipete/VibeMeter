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

    // MARK: - Component Managers

    private let displayManager: StatusBarDisplayManager
    private let menuWindowManager: MenuWindowManager
    private let animationController: StatusBarAnimationController
    private let observer: StatusBarObserver

    // MARK: - Dependencies

    private let settingsManager: any SettingsManagerProtocol
    private let userSession: MultiProviderUserSessionData
    private let loginManager: MultiProviderLoginManager
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private weak var orchestrator: MultiProviderDataOrchestrator?

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

        self.menuWindowManager = MenuWindowManager()

        self.animationController = StatusBarAnimationController(stateManager: stateManager)

        self.observer = StatusBarObserver(
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager)

        super.init()

        setupStatusItem()
        setupCustomMenu()
        setupCallbacks()
        startComponents()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.imagePosition = .imageLeading
            button.action = #selector(togglePopover)
            button.target = self

            // Accessibility support for menu bar button
            button.setAccessibilityTitle("VibeMeter")
            button.setAccessibilityRole(.button)
            button.setAccessibilityHelp("Shows AI service spending information and opens VibeMeter menu")

            updateStatusItemDisplay()
        }
    }

    private func setupCustomMenu() {
        menuWindowManager.setupCustomMenu(
            settingsManager: settingsManager,
            userSession: userSession,
            loginManager: loginManager,
            spendingData: spendingData,
            currencyData: currencyData,
            orchestrator: orchestrator)
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
        let isAuthenticating = userSession.providersWithSessions.contains { provider in
            userSession.getSession(for: provider)?.isAuthenticating ?? false
        }
        let providers = spendingData.providersWithData
        let hasData = !providers.isEmpty

        // Update state manager
        if isAuthenticating {
            // Show loading animation when authenticating
            stateManager.setState(.loading)
        } else if !isLoggedIn {
            stateManager.setState(.notLoggedIn)
        } else if !hasData {
            stateManager.setState(.loading)
        } else {
            let totalSpendingUSD = spendingData.totalSpendingConverted(
                to: "USD",
                rates: currencyData.effectiveRates)
            let gaugeValue = min(max(totalSpendingUSD / settingsManager.upperLimitUSD, 0.0), 1.0)

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
    private func togglePopover() {
        guard let button = statusItem?.button else { return }
        menuWindowManager.togglePopover(relativeTo: button)
    }

    /// Shows the popover menu (used for initial display when not logged in)
    func showPopover() {
        guard let button = statusItem?.button else { return }
        menuWindowManager.showPopover(relativeTo: button)
    }

    deinit {
        // Since deinit cannot be marked as @MainActor, we need to assume we're on the main actor
        // since StatusBarController is @MainActor and deinit is called when the actor is being deallocated
        MainActor.assumeIsolated {
            animationController.stopTimers()
            observer.stopObserving()
        }
    }
}
