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
                LoggedOutContentView(
                    loginManager: loginManager,
                    userSessionData: userSessionData,
                    onLoginTrigger: {
                        // Open login in separate window
                        loginManager.showLoginWindow(for: .cursor)
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
            if let customMenuWindow = NSApp.windows.first(where: { $0 is CustomMenuWindow }) as? CustomMenuWindow {
                customMenuWindow.hide()
                return .handled
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
