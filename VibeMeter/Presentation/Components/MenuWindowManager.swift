import AppKit
import SwiftUI

/// Manages the custom menu window and popover behavior for the status bar.
///
/// This manager handles the creation, display, and lifecycle of the custom
/// menu window that appears when the user clicks the status bar item.
@MainActor
final class MenuWindowManager {
    // MARK: - Private Properties

    private var customMenuWindow: CustomMenuWindow?

    // Strong references to prevent deallocation in Release builds
    private var settingsManager: (any SettingsManagerProtocol)?
    private var userSession: MultiProviderUserSessionData?
    private var loginManager: MultiProviderLoginManager?
    private var spendingData: MultiProviderSpendingData?
    private var currencyData: CurrencyData?
    private var orchestrator: MultiProviderDataOrchestrator?

    // MARK: - Initialization

    init() {
        // Empty initializer - window will be created when needed
    }

    // MARK: - Public Methods

    /// Sets up the custom menu window with the provided content view
    func setupCustomMenu(
        settingsManager: any SettingsManagerProtocol,
        userSession: MultiProviderUserSessionData,
        loginManager: MultiProviderLoginManager,
        spendingData: MultiProviderSpendingData,
        currencyData: CurrencyData,
        orchestrator: MultiProviderDataOrchestrator) {
        // Store strong references to prevent deallocation in Release builds
        self.settingsManager = settingsManager
        self.userSession = userSession
        self.loginManager = loginManager
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.orchestrator = orchestrator

        let contentView = CustomMenuContainer {
            VibeMeterMainView(
                settingsManager: settingsManager,
                userSessionData: userSession,
                loginManager: loginManager,
                onRefresh: { [weak self] in
                    // Use strong reference to orchestrator
                    await self?.orchestrator?.refreshAllProviders(showSyncedMessage: true)
                })
                .environment(spendingData)
                .environment(currencyData)
                .environment(GravatarService.shared)
        }

        // Create and store the window
        let window = CustomMenuWindow(contentView: contentView)
        self.customMenuWindow = window

        // Force the window to load its view hierarchy immediately
        // This is crucial for Release builds where lazy loading might fail
        _ = window.contentView
    }

    /// Toggles the popover visibility
    func togglePopover(relativeTo button: NSStatusBarButton) {
        guard let window = customMenuWindow else { return }

        // Simple approach: just check if window thinks it's visible and hide/show accordingly
        // This avoids state tracking issues by being stateless
        if window.isVisible {
            window.hide()
        } else {
            window.show(relativeTo: button)
        }
    }

    /// Shows the popover menu (used for initial display when not logged in)
    func showPopover(relativeTo button: NSStatusBarButton) {
        guard let window = customMenuWindow else { return }

        if !window.isVisible {
            window.show(relativeTo: button)
        }
    }

    /// Hides the popover menu if it's currently visible
    func hidePopover() {
        guard let window = customMenuWindow else { return }

        if window.isVisible {
            window.hide()
        }
    }

    /// Returns whether the popover is currently visible
    var isPopoverVisible: Bool {
        customMenuWindow?.isVisible ?? false
    }

    /// Gets the current menu window for external access if needed
    var menuWindow: CustomMenuWindow? {
        customMenuWindow
    }
}
