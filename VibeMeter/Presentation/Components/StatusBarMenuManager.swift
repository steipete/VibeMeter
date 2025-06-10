import AppKit
import SwiftUI

/// Manages status bar menu behavior, providing right-click context menu functionality.
///
/// This manager centralizes all context menu-related logic for the status bar, handling the creation and display
/// of the native context menu for right-click actions.
@MainActor
final class StatusBarMenuManager {
    // MARK: - Private Properties

    // Strong references to prevent deallocation in Release builds
    private var settingsManager: (any SettingsManagerProtocol)?
    private var userSession: MultiProviderUserSessionData?
    private var loginManager: MultiProviderLoginManager?
    private var spendingData: MultiProviderSpendingData?
    private var currencyData: CurrencyData?
    private var orchestrator: MultiProviderDataOrchestrator?

    // Custom window management
    private var customWindow: CustomMenuWindow?

    // MARK: - Initialization

    init() {
        // Empty initializer - components will be set up when needed
    }

    // MARK: - Configuration

    /// Configuration for menu manager setup
    struct Configuration {
        let settingsManager: any SettingsManagerProtocol
        let userSession: MultiProviderUserSessionData
        let loginManager: MultiProviderLoginManager
        let spendingData: MultiProviderSpendingData
        let currencyData: CurrencyData
        let orchestrator: MultiProviderDataOrchestrator
    }

    // MARK: - Setup

    /// Sets up the menu manager with required dependencies
    func setup(with configuration: Configuration) {
        // Store strong references to prevent deallocation in Release builds
        self.settingsManager = configuration.settingsManager
        self.userSession = configuration.userSession
        self.loginManager = configuration.loginManager
        self.spendingData = configuration.spendingData
        self.currencyData = configuration.currencyData
        self.orchestrator = configuration.orchestrator
    }

    // MARK: - Left-Click Custom Window Management

    func toggleCustomWindow(relativeTo button: NSStatusBarButton) {
        if let window = customWindow, window.isVisible {
            hideCustomWindow()
            button.highlight(false)
        } else {
            showCustomWindow(relativeTo: button)
            button.highlight(true)
        }
    }

    func showCustomWindow(relativeTo button: NSStatusBarButton) {
        guard let settingsManager,
              let userSession,
              let loginManager,
              let spendingData,
              let currencyData,
              let orchestrator else { return }

        // Hide any existing context menu first
        // Note: Context menu hiding is handled by the StatusBarController

        // Create the main view with all dependencies
        let mainView = VibeMeterMainView(
            settingsManager: settingsManager,
            userSessionData: userSession,
            loginManager: loginManager,
            onRefresh: {
                Task {
                    await orchestrator.refreshAllProviders(showSyncedMessage: true)
                }
            })
            .environment(spendingData)
            .environment(currencyData)

        // Wrap in custom container for proper styling
        let containerView = CustomMenuContainer {
            mainView
        }

        // Create custom window if needed
        if customWindow == nil {
            customWindow = CustomMenuWindow(contentView: containerView)

            // Set up callback to unhighlight button when window hides
            customWindow?.onHide = { [weak button] in
                button?.highlight(false)
            }
        }

        // Show the custom window
        customWindow?.show(relativeTo: button)

        // Highlight the button to show active state
        button.highlight(true)
    }

    func hideCustomWindow() {
        customWindow?.hide()
        // Note: The button unhighlighting is handled by the onHide callback
    }

    var isCustomWindowVisible: Bool {
        customWindow?.isVisible ?? false
    }

    // MARK: - Menu State Management

    /// Hides all menu types (custom window and context menu)
    func hideAllMenus() {
        hideCustomWindow()
        // Context menu is automatically hidden when statusItem.menu is set to nil
    }

    /// Checks if any menu is currently visible
    var isAnyMenuVisible: Bool {
        isCustomWindowVisible
    }

    // MARK: - Right-Click Context Menu

    /// Shows the context menu for right-click
    func showContextMenu(for button: NSStatusBarButton, statusItem: NSStatusItem) {
        // Hide custom window first if it's visible
        hideCustomWindow()

        let menu = NSMenu()

        // Add menu items based on current state
        if userSession?.isLoggedInToAnyProvider == true {
            let refreshItem = NSMenuItem(title: "Refresh Data", action: #selector(refreshData), keyEquivalent: "r")
            refreshItem.target = self
            menu.addItem(refreshItem)

            // Add total costs display
            if let spendingData, let currencyData, let settingsManager {
                let providers = spendingData.providersWithData
                if !providers.isEmpty {
                    let displayCurrency = settingsManager.selectedCurrencyCode
                    let totalSpendingDisplay = spendingData.totalSpendingConverted(
                        to: displayCurrency,
                        rates: currencyData.effectiveRates)

                    let formatter = NumberFormatter()
                    formatter.numberStyle = .currency
                    formatter.currencyCode = displayCurrency
                    formatter.maximumFractionDigits = 2

                    let formattedAmount = formatter
                        .string(from: NSNumber(value: totalSpendingDisplay)) ?? "\(displayCurrency) 0.00"

                    let totalCostsItem = NSMenuItem(title: "Total: \(formattedAmount)", action: nil, keyEquivalent: "")
                    totalCostsItem.isEnabled = false
                    menu.addItem(totalCostsItem)
                }
            }

            menu.addItem(NSMenuItem.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let checkForUpdatesItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: "")
        checkForUpdatesItem.target = self
        menu.addItem(checkForUpdatesItem)

        let aboutItem = NSMenuItem(title: "About VibeMeter", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit VibeMeter", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Show the context menu
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil // Clear the menu after use
    }

    // MARK: - Context Menu Actions

    @objc
    private func refreshData() {
        Task {
            await orchestrator?.refreshAllProviders(showSyncedMessage: true)
        }
    }

    @objc
    private func openSettings() {
        NSApp.openSettings()
    }

    @objc
    private func showAbout() {
        // Open settings window first
        NSApp.openSettings()

        // Send notification to switch to About tab
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            NotificationCenter.default.post(
                name: Notification.Name("openSettingsTab"),
                object: MultiProviderSettingsTab.about)
        }
    }

    @objc
    private func checkForUpdates() {
        // Check for updates using Sparkle
        if let appDelegate = NSApp.delegate as? AppDelegate,
           let sparkleManager = appDelegate.sparkleUpdaterManager {
            sparkleManager.updaterController.checkForUpdates(nil)
        }
    }

    @objc
    private func quitApp() {
        NSApp.terminate(nil)
    }
}
