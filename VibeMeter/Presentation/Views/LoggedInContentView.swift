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

    var body: some View {
        VStack(spacing: 0) {
            // Header section - more compact
            UserHeaderView(userSessionData: userSessionData)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 10)

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Content section - reduced spacing
            VStack(spacing: 6) {
                CostTableView(settingsManager: settingsManager, loginManager: loginManager)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Spacer(minLength: 8)

            // Action buttons footer - more compact
            VStack(spacing: 0) {
                Divider()
                    .overlay(Color.white.opacity(0.1))

                ActionButtonsView(onRefresh: onRefresh)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
    }
}
