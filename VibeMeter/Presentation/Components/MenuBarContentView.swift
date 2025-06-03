import AppKit
import os.log
import SwiftUI

/// Main content view for the menu bar dropdown interface.
///
/// This view serves as the root content for the menu bar popover, containing
/// either the logged-in dashboard or logged-out login interface. It handles
/// the primary user interaction flow within the menu bar dropdown.
@MainActor
struct MenuBarContentView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    private let logger = Logger(subsystem: "com.vibemeter", category: "MenuBarContentView")

    var body: some View {
        VStack(spacing: 0) {
            if userSessionData.isLoggedInToAnyProvider {
                LoggedInMenuContent(
                    settingsManager: settingsManager,
                    userSessionData: userSessionData,
                    loginManager: loginManager)
            } else {
                LoggedOutMenuContent(loginManager: loginManager)
            }
        }
        .frame(minWidth: 200, maxWidth: 250)
        .environment(spendingData)
        .environment(currencyData)
        .onAppear {
            logger.info("MenuBarContentView appeared")
            logger
                .info(
                    "Logged in providers: \(userSessionData.loggedInProviders.map(\.displayName).joined(separator: ", "))")
            logger
                .info(
                    "Providers with data: \(spendingData.providersWithData.map(\.displayName).joined(separator: ", "))")
        }
    }
}

// MARK: - Previews

#Preview("Menu Bar - Logged Out") {
    MenuBarContentView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .environment(MultiProviderSpendingData())
        .environment(CurrencyData())
        .frame(width: 250)
}

#Preview("Menu Bar - Logged In") {
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

    return MenuBarContentView(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .environment(spendingData)
        .environment(CurrencyData())
        .frame(width: 250)
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
