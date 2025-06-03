import SwiftUI

struct UserHeaderView: View {
    let userSessionData: MultiProviderUserSessionData

    var body: some View {
        HStack(spacing: 12) {
            UserAvatarView(email: userSessionData.mostRecentSession?.userEmail)

            VStack(alignment: .leading, spacing: 4) {
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
