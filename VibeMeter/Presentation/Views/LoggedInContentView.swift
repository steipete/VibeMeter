import SwiftUI

struct LoggedInContentView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header section
            UserHeaderView(userSessionData: userSessionData)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()
                .overlay(Color.white.opacity(0.08))

            // Content section with consistent spacing
            ScrollView {
                VStack(spacing: 16) {
                    CostTableView(settingsManager: settingsManager)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }

            Spacer(minLength: 0)

            // Action buttons footer
            VStack(spacing: 0) {
                Divider()
                    .overlay(Color.white.opacity(0.05))

                ActionButtonsView(onRefresh: onRefresh)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
            }
        }
    }
}
