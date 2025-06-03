import SwiftUI

/// Content view displayed when users are logged in to one or more service providers.
///
/// This view presents the complete spending dashboard including user header, cost breakdown,
/// provider details, spending limits, and action buttons. It provides a compact yet comprehensive
/// overview of current spending across all connected providers.
struct LoggedInContentView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager?
    let onRefresh: () async -> Void

    @Environment(MultiProviderSpendingData.self)
    private var spendingData

    var body: some View {
        VStack(spacing: 0) {
            // Header section - better spacing
            UserHeaderView(userSessionData: userSessionData)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("User account information")
                .accessibilityHint("Shows current user and connected providers")

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Content section - improved spacing
            VStack(spacing: 6) {
                CostTableView(settingsManager: settingsManager, loginManager: loginManager, showTimestamps: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Spending dashboard")
            .accessibilityHint("Shows total spending, provider breakdown, and spending limits")
            .id("logged-in-content-\(spendingData.providersWithData.count)")

            // Last updated section at bottom
            if let lastUpdate = mostRecentRefresh {
                VStack(spacing: 2) {
                    HStack {
                        Text(RelativeTimeFormatter.string(from: lastUpdate, style: .withPrefix))
                            .font(.footnote)
                            .foregroundStyle(.quaternary)
                            .accessibilityLabel(
                                "Last updated \(RelativeTimeFormatter.string(from: lastUpdate, style: .withPrefix))")

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            }

            // Action buttons footer - more compact
            VStack(spacing: 0) {
                Divider()
                    .overlay(Color.white.opacity(0.1))

                ActionButtonsView(onRefresh: onRefresh)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Action buttons")
                    .accessibilityHint("Contains refresh, settings, and quit buttons")
            }
        }
    }

    /// Gets the most recent refresh timestamp across all providers
    private var mostRecentRefresh: Date? {
        spendingData.providersWithData
            .compactMap { provider in
                spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh
            }
            .max()
    }
}

// MARK: - Preview

#Preview("Logged In Content - With Data") {
    let (userSession, spendingData, currencyData) = PreviewData.loggedInWithSpending(cents: 4997)
    let services = MockServices.standard

    return LoggedInContentView(
        settingsManager: services.0,
        userSessionData: userSession,
        loginManager: nil,
        onRefresh: {})
        .withCompleteEnvironment(spending: spendingData, currency: currencyData)
        .contentFrame()
        .materialBackground()
}

#Preview("Logged In Content - Loading") {
    let userSession = PreviewData.mockUserSession(email: "john.doe@company.com", teamName: "Company Team", teamId: 456)

    return LoggedInContentView(
        settingsManager: MockServices.settingsManager,
        userSessionData: userSession,
        loginManager: nil,
        onRefresh: {})
        .standardPreviewEnvironment()
        .contentFrame()
        .materialBackground()
}
