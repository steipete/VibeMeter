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
    }

    /// Toggles the popover visibility
    func togglePopover(relativeTo button: NSStatusBarButton) {
        guard let window = customMenuWindow else { return }

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
        customMenuWindow?.hide()
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
