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
    private var isWindowVisible = false

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
        orchestrator: MultiProviderDataOrchestrator?) {
        let contentView = CustomMenuContainer {
            VibeMeterMainView(
                settingsManager: settingsManager,
                userSessionData: userSession,
                loginManager: loginManager,
                onRefresh: { [weak orchestrator] in
                    await orchestrator?.refreshAllProviders(showSyncedMessage: true)
                })
                .environment(spendingData)
                .environment(currencyData)
                .environment(GravatarService.shared)
        }

        customMenuWindow = CustomMenuWindow(contentView: contentView)
        
        // Set up callback to track when window is hidden
        customMenuWindow?.onWindowHidden = { [weak self] in
            self?.isWindowVisible = false
        }
    }

    /// Toggles the popover visibility
    func togglePopover(relativeTo button: NSStatusBarButton) {
        guard let window = customMenuWindow else { return }

        if isWindowVisible {
            window.hide()
            isWindowVisible = false
        } else {
            window.show(relativeTo: button)
            isWindowVisible = true
        }
    }

    /// Shows the popover menu (used for initial display when not logged in)
    func showPopover(relativeTo button: NSStatusBarButton) {
        guard let window = customMenuWindow else { return }

        if !isWindowVisible {
            window.show(relativeTo: button)
            isWindowVisible = true
        }
    }

    /// Hides the popover menu if it's currently visible
    func hidePopover() {
        if isWindowVisible {
            customMenuWindow?.hide()
            isWindowVisible = false
        }
    }

    /// Returns whether the popover is currently visible
    var isPopoverVisible: Bool {
        isWindowVisible
    }

    /// Gets the current menu window for external access if needed
    var menuWindow: CustomMenuWindow? {
        customMenuWindow
    }

}
