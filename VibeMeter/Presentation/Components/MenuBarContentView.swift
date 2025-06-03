import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

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
    }
}

// MARK: - Logged In Content

struct LoggedInMenuContent: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // User info
            if let mostRecentSession = userSessionData.mostRecentSession,
               let email = mostRecentSession.userEmail {
                VStack(alignment: .leading, spacing: 2) {
                    Text(email.truncated(to: 20))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if userSessionData.loggedInProviders.count > 1 {
                        Text("\(userSessionData.loggedInProviders.count) providers")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(mostRecentSession.provider.displayName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Current spending
            if let totalSpending = currentSpendingDisplay {
                Text(totalSpending)
                    .font(.headline)
            } else {
                Text("No spending data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Limits (compact)
            HStack {
                Text("⚠️")
                Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedWarningLimit))")

                Spacer()

                Text("🚨")
                Text("\(currencyData.selectedSymbol)\(String(format: "%.0f", convertedUpperLimit))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            // Actions
            VStack(spacing: 4) {
                Button("Refresh") {
                    Task {
                        await refreshAllProviders()
                    }
                }
                .keyboardShortcut("r")

                Button("Settings...") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.openSettings()
                }
                .keyboardShortcut(",")

                Button("Log Out All") {
                    loginManager.logOutFromAll()
                }
                .keyboardShortcut("q")
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Button("Quit VibeMeter") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("Q")
            .buttonStyle(.plain)
        }
        .padding(12)
    }

    private var currentSpendingDisplay: String? {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return nil }

        let totalSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.currentExchangeRates)

        return "\(currencyData.selectedSymbol)\(String(format: "%.2f", totalSpending))"
    }

    private var convertedWarningLimit: Double {
        currencyData.convertAmount(
            settingsManager.warningLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.warningLimitUSD
    }

    private var convertedUpperLimit: Double {
        currencyData.convertAmount(
            settingsManager.upperLimitUSD,
            from: "USD",
            to: currencyData.selectedCode) ?? settingsManager.upperLimitUSD
    }

    private func refreshAllProviders() async {
        // In a full implementation, this would refresh data from all logged-in providers
        // For now, this is a placeholder
        // TODO: Implement multi-provider data refresh
    }
}

// MARK: - Logged Out Content

struct LoggedOutMenuContent: View {
    let loginManager: MultiProviderLoginManager

    var body: some View {
        VStack(spacing: 8) {
            Text("VibeMeter")
                .font(.headline)
                .padding(.top, 4)

            Text("Multi-Provider Cost Tracking")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Divider()

            Button("Login to Cursor") {
                loginManager.showLoginWindow(for: .cursor)
            }
            .keyboardShortcut("l")
            .buttonStyle(.borderedProminent)

            Divider()

            Button("Settings...") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.openSettings()
            }
            .keyboardShortcut(",")
            .buttonStyle(.plain)

            Divider()

            Button("Quit VibeMeter") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("Q")
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}

// MARK: - Helper Extension

private extension String {
    func truncated(to length: Int) -> String {
        if count > length {
            return String(prefix(length - 3)) + "..."
        }
        return self
    }
}

// MARK: - Previews

#Preview("Menu Bar - Logged Out") {
    MenuBarContentView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    )
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
        teamId: 123
    )
    
    let spendingData = MultiProviderSpendingData()
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "Usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025
        ),
        rates: [:],
        targetCurrency: "USD"
    )
    
    return MenuBarContentView(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    )
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
