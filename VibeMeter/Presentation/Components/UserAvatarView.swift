import SwiftUI

/// User avatar component displaying Gravatar images with fallback initials.
///
/// This view shows user avatars by fetching Gravatar images based on email addresses.
/// It includes fallback handling with user initials when Gravatar images are unavailable,
/// and supports configurable sizing for different use cases.
struct UserAvatarView: View {
    let email: String?
    let size: CGFloat

    init(email: String?, size: CGFloat = 40) {
        self.email = email
        self.size = size
    }

    var body: some View {
        Group {
            if let email,
               let gravatarURL = GravatarService.shared.gravatarURL(for: email) {
                AsyncImage(url: gravatarURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure(_), .empty:
                        fallbackAvatar
                    @unknown default:
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: size, height: size)
                    }
                }
            } else {
                fallbackAvatar
            }
        }
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(userInitial)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(.white))
    }

    private var userInitial: String {
        guard let email, let firstChar = email.first else { return "?" }
        return String(firstChar).uppercased()
    }
}
