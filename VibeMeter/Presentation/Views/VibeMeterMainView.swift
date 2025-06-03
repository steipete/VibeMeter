import SwiftUI

@MainActor
struct VibeMeterMainView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            if userSessionData.isLoggedInToAnyProvider {
                LoggedInContentView(
                    settingsManager: settingsManager,
                    userSessionData: userSessionData,
                    onRefresh: onRefresh)
            } else {
                LoggedOutContentView(loginManager: loginManager)
            }
        }
        .frame(width: 300, height: userSessionData.isLoggedInToAnyProvider ? 350 : 280)
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

// MARK: - Mock Settings Manager for Preview

@MainActor
private class MockSettingsManager: SettingsManagerProtocol {
    var providerSessions: [ServiceProvider: ProviderSession] = [:]
    var selectedCurrencyCode: String = "USD"
    var warningLimitUSD: Double = 200
    var upperLimitUSD: Double = 500
    var refreshIntervalMinutes: Int = 5
    var launchAtLoginEnabled: Bool = false
    var showCostInMenuBar: Bool = true
    var showInDock: Bool = false
    var enabledProviders: Set<ServiceProvider> = [.cursor]

    func clearUserSessionData() {
        providerSessions.removeAll()
    }

    func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }

    func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }

    func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
    }
}
