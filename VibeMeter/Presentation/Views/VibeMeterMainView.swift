import SwiftUI

/// Main view for the VibeMeter menu bar application that displays either logged-in or logged-out content.
///
/// This view serves as the primary interface for the application, conditionally showing
/// either the full spending dashboard when users are logged in to providers or a login
/// interface when no providers are connected.
@MainActor
struct VibeMeterMainView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    let onRefresh: () async -> Void

    var body: some View {
        Group {
            if userSessionData.isLoggedInToAnyProvider {
                LoggedInContentView(
                    settingsManager: settingsManager,
                    userSessionData: userSessionData,
                    loginManager: loginManager,
                    onRefresh: onRefresh)
            } else {
                NoProvidersConfiguredView(
                    onConfigureProviders: {
                        // Open settings window to the providers tab
                        openSettingsToProvidersTab()
                    })
            }
        }
        .frame(minWidth: 320)
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("VibeMeter main interface")
        .accessibilityHint(userSessionData.isLoggedInToAnyProvider ?
            "Shows AI service spending dashboard and controls" :
            "Shows login options for AI service providers")
        .onKeyPress(.escape) {
            // Modern key handling for ESC to close menu
            // Look for any borderless window that might be our menu
            for window in NSApp.windows {
                if window.styleMask.contains(.borderless), window.isVisible, window.level == .popUpMenu {
                    window.orderOut(nil)
                    return .handled
                }
            }
            return .ignored
        }
    }
}

// MARK: - Preview

#Preview("Logged Out") {
    VibeMeterMainView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        onRefresh: {})
        .environment(MultiProviderSpendingData())
        .environment(CurrencyData())
}

#Preview("Logged In") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123)

    let spendingData = MultiProviderSpendingData()
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "Usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025),
        rates: [:],
        targetCurrency: "USD")

    spendingData.updateUsage(
        for: .cursor,
        from: ProviderUsageData(
            currentRequests: 1535,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor))

    return VibeMeterMainView(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        onRefresh: {})
        .environment(spendingData)
        .environment(CurrencyData())
}

// MARK: - Helper Methods

private extension VibeMeterMainView {
    func handleEscapeKey() -> KeyPress.Result {
        for window in NSApp.windows {
            if window.styleMask.contains(.borderless), window.isVisible, window.level == .popUpMenu {
                window.orderOut(nil)
                return .handled
            }
        }
        return .ignored
    }

    func openSettingsToProvidersTab() {
        // Post notification to open providers tab
        NotificationCenter.default.post(
            name: .openSettingsTab,
            object: MultiProviderSettingsTab.providers)

        // Open settings window
        NSApp.openSettings()
    }
}
