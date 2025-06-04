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

            VStack(alignment: .leading, spacing: 6) {
                if let email = userSessionData.mostRecentSession?.userEmail {
                    Text(email)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityLabel("User email: \(email)")
                }

                Text(providerCountText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(providerCountText)
            }
            .accessibilityElement(children: .combine)

            Spacer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("User account header")
        .accessibilityValue(userSessionData.mostRecentSession?.userEmail ?? "No user logged in")
    }

    private var providerCountText: String {
        let providers = userSessionData.loggedInProviders
        let count = providers.count
        
        if count == 1, let provider = providers.first, provider == .cursor {
            if let teamName = userSessionData.getSession(for: .cursor)?.teamName {
                return teamName
            }
        }
        
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
