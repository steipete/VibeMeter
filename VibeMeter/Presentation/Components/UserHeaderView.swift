import SwiftUI

struct UserHeaderView: View {
    let userSessionData: MultiProviderUserSessionData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                UserAvatarView(email: userSessionData.mostRecentSession?.userEmail)

                VStack(alignment: .leading, spacing: 6) {
                    if let email = userSessionData.mostRecentSession?.userEmail {
                        Text(email)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }

                    Text(providerCountText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var providerCountText: String {
        let count = userSessionData.loggedInProviders.count
        return "\(count) provider\(count == 1 ? "" : "s") connected"
    }
}
