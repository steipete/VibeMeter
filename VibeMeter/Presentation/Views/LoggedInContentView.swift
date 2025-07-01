import SwiftUI

/// Content view displayed when users are logged in to one or more service providers.
///
/// This view presents the complete spending dashboard including user header, cost breakdown,
/// provider details, spending limits, and action buttons. It provides a compact yet comprehensive
/// overview of current spending across all connected providers.
struct LoggedInContentView: View {
    @Environment(\.settingsManager)
    private var settingsManager: (any SettingsManagerProtocol)?
    @Environment(\.userSessionData)
    private var userSessionData: MultiProviderUserSessionData?
    @Environment(\.loginManager)
    private var loginManager: MultiProviderLoginManager?
    @Environment(\.refreshAction)
    private var onRefresh: (@Sendable () async -> Void)?

    @Environment(MultiProviderSpendingData.self)
    private var spendingData
    @Environment(\.colorScheme)
    private var colorScheme

    // Computed property for most recent refresh
    private var mostRecentRefresh: Date? {
        spendingData.providersWithData
            .compactMap { provider in
                spendingData.getSpendingData(for: provider)?.lastSuccessfulRefresh
            }
            .max()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title bar with settings and close buttons
            PopoverTitleBar()
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // Header section - better spacing
            UserHeaderView()
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("User account information")
                .accessibilityHint("Shows current user and connected providers")

            Divider()
                .overlay(Color.dividerOverlay(for: colorScheme))

            // Enhanced dashboard content
            EnhancedDashboardView()
                .frame(maxHeight: 500)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Enhanced spending dashboard")
                .accessibilityHint("Shows key metrics, provider breakdown, predictions, and spending limits")
                .animation(.easeInOut(duration: 0.2), value: spendingData.providersWithData.count)

        }
    }
}

// MARK: - Preview

#Preview("Logged In Content - With Data") {
    let bundle = PreviewData.loggedInWithSpending(cents: 4997)
    let userSession = bundle.userSession
    let spendingData = bundle.spendingData
    let currencyData = bundle.currencyData
    let services = MockServices.standard

    LoggedInContentView()
        .settingsManager(services.0)
        .userSessionData(userSession)
        .withCompleteEnvironment(spending: spendingData, currency: currencyData)
        .contentFrame()
        .materialBackground()
}

#Preview("Logged In Content - Loading") {
    let userSession = PreviewData.mockUserSession(email: "john.doe@company.com", teamName: "Company Team", teamId: 456)

    LoggedInContentView()
        .settingsManager(MockServices.settingsManager)
        .userSessionData(userSession)
        .standardPreviewEnvironment()
        .contentFrame()
        .materialBackground()
}
