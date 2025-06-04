import SwiftUI

/// User avatar component displaying Gravatar images with fallback initials.
///
/// This view shows user avatars by fetching Gravatar images based on email addresses.
/// It includes fallback handling with user initials when Gravatar images are unavailable,
/// and supports configurable sizing for different use cases.
struct UserAvatarView: View {
    let email: String?
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

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
                            .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
                            .accessibilityLabel("User avatar for \(email)")
                    default:
                        fallbackAvatar
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
                    .font(.system(size: size * 0.45, weight: .medium, design: .rounded))
                    .foregroundStyle(.white))
            .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
            .accessibilityLabel(email != nil ? "User avatar with initial \(userInitial)" : "Default user avatar")
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.5) : Color.black.opacity(0.2)
    }

    private var userInitial: String {
        guard let email, let firstChar = email.first else { return "?" }
        return String(firstChar).uppercased()
    }
}

// MARK: - Preview

#Preview("User Avatar - Different Sizes") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            UserAvatarView(email: "user@example.com", size: 20)
            UserAvatarView(email: "test@company.com", size: 40)
            UserAvatarView(email: "hello@world.com", size: 60)
            UserAvatarView(email: "john.doe@example.com", size: 80)
        }

        HStack(spacing: 20) {
            VStack {
                UserAvatarView(email: nil, size: 40)
                Text("No email")
                    .font(.caption)
            }

            VStack {
                UserAvatarView(email: "jane@example.com", size: 40)
                Text("With email")
                    .font(.caption)
            }
        }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}

#Preview("User Avatar - Loading States") {
    HStack(spacing: 20) {
        ForEach(["a@example.com", "b@test.com", "c@demo.com"], id: \.self) { email in
            VStack {
                UserAvatarView(email: email, size: 60)
                Text(email.prefix(1).uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
