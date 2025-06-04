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

    // MARK: - Initialization

    init() {
        // Empty initializer - components will be set up when needed
    }

    // MARK: - Setup

    /// Sets up the menu manager with required dependencies
    func setup(
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
    }

    // MARK: - Left-Click Popover Management (Placeholder)

    /// These methods are kept for compatibility but no longer manage a custom window
    func togglePopover(relativeTo _: NSStatusBarButton) {
        // No-op: Custom window functionality removed
    }

    func showPopover(relativeTo _: NSStatusBarButton) {
        // No-op: Custom window functionality removed
    }

    func hidePopover() {
        // No-op: Custom window functionality removed
    }

    var isPopoverVisible: Bool {
        false
    }

    // MARK: - Right-Click Context Menu

    /// Shows the context menu for right-click
    func showContextMenu(for button: NSStatusBarButton, statusItem: NSStatusItem) {
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
