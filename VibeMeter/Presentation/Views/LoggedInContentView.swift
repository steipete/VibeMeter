import SwiftUI

struct LoggedInContentView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header section - more compact
            UserHeaderView(userSessionData: userSessionData)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Content section - reduced spacing
            VStack(spacing: 8) {
                CostTableView(settingsManager: settingsManager)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Spacer(minLength: 8)

            // Action buttons footer - more compact
            VStack(spacing: 0) {
                Divider()
                    .overlay(Color.white.opacity(0.1))

                ActionButtonsView(onRefresh: onRefresh)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
    }
}
