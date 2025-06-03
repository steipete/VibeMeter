import SwiftUI

struct LoggedInContentView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let onRefresh: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            UserHeaderView(userSessionData: userSessionData)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Divider()
                .overlay(Color.white.opacity(0.1))

            // Cost table
            CostTableView(settingsManager: settingsManager)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

            Spacer()

            // Action buttons
            ActionButtonsView(onRefresh: onRefresh)
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }
}

