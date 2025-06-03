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
        .standardPadding(horizontal: 10, vertical: 10)
        .onAppear {
            // Logging removed for preview compatibility
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
                        let providerCount = userSessionData.loggedInProviders.count
                        Text("\(providerCount) providers")
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
            } else {
                Text("No spending data")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var spendingLimitsSection: some View {
        HStack {
            Text("⚠️")
            Text(warningLimitText)

            Spacer()

            Text("🚨")
            Text(upperLimitText)
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

        let formattedSpending = totalSpending.formatted(.number.precision(.fractionLength(2)))
        let spendingText = "\(currencyData.selectedSymbol)\(formattedSpending)"
        return spendingText
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

    private var warningLimitText: String {
        let formattedAmount = convertedWarningLimit.formatted(.number.precision(.fractionLength(0)))
        let symbol = currencyData.selectedSymbol
        return "\(symbol)\(formattedAmount)"
    }

    private var upperLimitText: String {
        let formattedAmount = convertedUpperLimit.formatted(.number.precision(.fractionLength(0)))
        let symbol = currencyData.selectedSymbol
        return "\(symbol)\(formattedAmount)"
    }

    private func refreshAllProviders() async {
        // In a full implementation, this would refresh data from all logged-in providers
        // For now, this is a placeholder
        // TODO: Implement multi-provider data refresh
    }
}

// MARK: - Preview

#Preview("Logged In Menu - With Data") {
    let (settingsManager, loginManager) = MockServices.standard
    let (userSessionData, spendingData, currencyData) = PreviewData.loggedInWithSpending(cents: 15750)

    return LoggedInMenuContent(
        settingsManager: settingsManager,
        userSessionData: userSessionData,
        loginManager: loginManager)
        .environment(spendingData)
        .environment(currencyData)
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Logged In Menu - No Data") {
    let (settingsManager, loginManager) = MockServices.standard
    let userSessionData = PreviewData.mockUserSession(
        email: "john.doe@company.com",
        teamName: "Company Team",
        teamId: 456)

    return LoggedInMenuContent(
        settingsManager: settingsManager,
        userSessionData: userSessionData,
        loginManager: loginManager)
        .environment(PreviewData.emptySpendingData())
        .environment(PreviewData.mockCurrencyData())
        .frame(width: 250)
        .background(Color(NSColor.windowBackgroundColor))
}
