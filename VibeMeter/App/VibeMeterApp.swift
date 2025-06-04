import SwiftUI

// MARK: - App Entry Point

/// The main entry point for the VibeMeter application.
///
/// VibeMeter is a macOS menu bar application that monitors monthly spending
/// on the Cursor AI service. It provides real-time spending tracking,
/// multi-currency support, and customizable spending alerts.
///
/// This modernized version uses SwiftUI's Environment system for dependency
/// injection and focused @Observable models instead of a monolithic coordinator.
@main
struct VibeMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    var appDelegate

    @State
    private var gravatarService = GravatarService.shared

    // Settings manager for reactive updates
    @State
    private var settingsManager = SettingsManager.shared

    @MainActor
    private var menuBarDisplayText: String {
        // Only show cost if setting is enabled and we have data
        guard settingsManager.menuBarDisplayMode.showsMoney else {
            return "" // Empty string = icon only (default behavior)
        }

        let providers = appDelegate.spendingData.providersWithData
        guard !providers.isEmpty else {
            return "" // No data = icon only
        }

        // Always use total spending for consistency with the popover
        let spending = appDelegate.spendingData.totalSpendingConverted(
            to: appDelegate.currencyData.selectedCode,
            rates: appDelegate.currencyData.effectiveRates)

        return "\(appDelegate.currencyData.selectedSymbol)\(spending.formatted(.number.precision(.fractionLength(2))))"
    }

    var body: some Scene {
        // Settings window using multi-provider architecture
        Settings {
            MultiProviderSettingsView(
                settingsManager: settingsManager,
                userSessionData: appDelegate.userSession,
                loginManager: appDelegate.loginManager,
                orchestrator: appDelegate.multiProviderOrchestrator)
                .environment(appDelegate.spendingData)
                .environment(appDelegate.currencyData)
                .environment(gravatarService)
        }
    }
}
