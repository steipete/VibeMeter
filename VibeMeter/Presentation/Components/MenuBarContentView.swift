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

// MARK: - Logged In Content

struct LoggedInMenuContent: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(CurrencyData.self)
    private var currencyData

    private let logger = Logger(subsystem: "com.vibemeter", category: "LoggedInMenuContent")

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
                    .onAppear {
                        logger.info("Displaying spending: \(totalSpending)")
                    }
            } else {
                Text("No spending data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .onAppear {
                        logger.info("No spending data to display")
                    }
            }

            // Limits (compact)
            HStack {
                Text("⚠️")
                Text(
                    "\(currencyData.selectedSymbol)\(convertedWarningLimit.formatted(.number.precision(.fractionLength(0))))")

                Spacer()

                Text("🚨")
                Text(
                    "\(currencyData.selectedSymbol)\(convertedUpperLimit.formatted(.number.precision(.fractionLength(0))))")
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
                    NSApp.openSettings()
                }
                .keyboardShortcut(",")

                Button("Log Out All") {
                    logger.info("User requested logout from all providers")
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
        .onAppear {
            logger.info("LoggedInMenuContent appeared")
            logger.info("Most recent session: \(userSessionData.mostRecentSession?.provider.displayName ?? "none")")
            logger.info("Currency: \(currencyData.selectedCode), Symbol: \(currencyData.selectedSymbol)")
            if let spending = currentSpendingDisplay {
                logger.info("Current spending display: \(spending)")
            } else {
                logger.info("No spending data available")
            }
        }
    }

    private var currentSpendingDisplay: String? {
        let providers = spendingData.providersWithData
        guard !providers.isEmpty else { return nil }

        let totalSpending = spendingData.totalSpendingConverted(
            to: currencyData.selectedCode,
            rates: currencyData.effectiveRates)

        return "\(currencyData.selectedSymbol)\(totalSpending.formatted(.number.precision(.fractionLength(2))))"
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
    private let logger = Logger(subsystem: "com.vibemeter", category: "LoggedOutMenuContent")

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
                logger.info("User clicked login button for Cursor")
                loginManager.showLoginWindow(for: .cursor)
            }
            .keyboardShortcut("l")
            .buttonStyle(.borderedProminent)

            Divider()

            Button("Settings...") {
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
        .onAppear {
            logger.info("LoggedOutMenuContent appeared")
        }
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
