import AppKit
import os.log
import SwiftUI

// MARK: - Logged In Menu Content

/// Menu content displayed when users are logged into at least one provider.
///
/// This view shows current spending information, user account details, spending limits,
/// and action buttons for logged-in users. It provides quick access to refresh data,
/// open settings, and logout functionality.
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
            userInfoSection
            currentSpendingSection
            spendingLimitsSection

            Divider()

            actionButtonsSection

            Divider()

            quitButtonSection
        }
        .standardPadding(horizontal: 12, vertical: 12)
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

    // MARK: - View Components

    private var userInfoSection: some View {
        Group {
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
        }
    }

    private var currentSpendingSection: some View {
        Group {
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
        }
    }

    private var spendingLimitsSection: some View {
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
    }

    private var actionButtonsSection: some View {
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
    }

    private var quitButtonSection: some View {
        Button("Quit VibeMeter") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("Q")
        .buttonStyle(.plain)
    }

    // MARK: - Helper Properties and Methods

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

// MARK: - Preview

#Preview("Logged In Menu - With Data") {
    let userSessionData = MultiProviderUserSessionData()
    let spendingData = MultiProviderSpendingData()
    let currencyData = CurrencyData()

    // Set up session
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123)

    // Add spending data
    spendingData.updateSpending(
        for: .cursor,
        from: ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 15750, description: "Pro Usage", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025),
        rates: [:],
        targetCurrency: "USD")

    return LoggedInMenuContent(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .environment(spendingData)
        .environment(currencyData)
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Logged In Menu - No Data") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "john.doe@company.com",
        teamName: "Company Team",
        teamId: 456)

    return LoggedInMenuContent(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .environment(MultiProviderSpendingData())
        .environment(CurrencyData())
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
}
