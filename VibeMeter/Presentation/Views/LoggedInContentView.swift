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
            // Header section - more compact
            UserHeaderView(userSessionData: userSessionData)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Content section - tighter spacing
            VStack(spacing: 4) {
                CostTableView(settingsManager: settingsManager, loginManager: loginManager, showTimestamps: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Spacer(minLength: 4)

            // Last updated section at bottom
            if let lastUpdate = mostRecentRefresh {
                VStack(spacing: 2) {
                    Divider()
                        .overlay(Color.white.opacity(0.06))
                    
                    HStack {
                        RelativeTimeFormatter.RelativeTimestampView(
                            date: lastUpdate,
                            style: .withPrefix,
                            showFreshnessColor: false)
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                        
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
                    .padding(.vertical, 8)
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
