import SwiftUI

/// Header component displaying user information and connection status.
///
/// This view shows the user's avatar, email address, and the number of connected providers.
/// It provides a quick overview of the current session state and user identity across
/// all connected service providers.
struct UserHeaderView: View {
    let userSessionData: MultiProviderUserSessionData

    var body: some View {
        HStack(spacing: 10) {
            UserAvatarView(email: userSessionData.mostRecentSession?.userEmail)

            VStack(alignment: .leading, spacing: 2) {
                if let email = userSessionData.mostRecentSession?.userEmail {
                    Text(email)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Text(providerCountText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var providerCountText: String {
        let count = userSessionData.loggedInProviders.count
        return "\(count) provider\(count == 1 ? "" : "s") connected"
    }
}

// MARK: - Preview

#Preview("User Header - Logged In") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123)

    return UserHeaderView(userSessionData: userSessionData)
        .padding()
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("User Header - Multiple Providers") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "john.doe@company.com",
        teamName: "Company Team",
        teamId: 123)

    return UserHeaderView(userSessionData: userSessionData)
        .padding()
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("User Header - No Session") {
    UserHeaderView(userSessionData: MultiProviderUserSessionData())
        .padding()
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
}
