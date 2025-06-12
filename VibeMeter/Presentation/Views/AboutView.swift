import AppKit
import SwiftUI

/// About view displaying application information, version details, and credits.
///
/// This view provides information about VibeMeter including version numbers,
/// build details, developer credits, and links to external resources like
/// GitHub repository and support channels.
struct AboutView: View {
    let orchestrator: MultiProviderDataOrchestrator?
    var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ??
            Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "Vibe Meter"
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    appInfoSection
                    descriptionSection
                    linksSection

                    Spacer(minLength: 40)

                    copyrightSection
                }
                .frame(maxWidth: .infinity)
                .standardPadding()
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("About \(appName)")
        }
    }

    private var appInfoSection: some View {
        VStack(spacing: 16) {
            InteractiveAppIcon()

            Text(appName)
                .font(.largeTitle)
                .fontWeight(.medium)

            Text("Version \(appVersion)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var descriptionSection: some View {
        Text("Monitor your monthly Cursor AI spending")
            .font(.body)
            .foregroundStyle(.secondary)
    }

    private var linksSection: some View {
        VStack(spacing: 12) {
            HoverableLink(url: "https://github.com/steipete/VibeMeter", title: "View on GitHub", icon: "link")
            HoverableLink(
                url: "https://github.com/steipete/VibeMeter/issues",
                title: "Report an Issue",
                icon: "exclamationmark.bubble")
            HoverableLink(url: "https://x.com/steipete", title: "Follow @steipete on Twitter", icon: "bird")
        }
    }

    private var copyrightSection: some View {
        Text("© 2025 Peter Steinberger • MIT Licensed")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
    }
}

/// Hoverable link component with underline animation.
///
/// This component displays a link with an icon that shows an underline on hover
/// and changes the cursor to a pointing hand for better user experience.
struct HoverableLink: View {
    let url: String
    let title: String
    let icon: String

    @State
    private var isHovering = false

    var body: some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: icon)
                .underline(isHovering, color: .accentColor)
        }
        .buttonStyle(.link)
        .pointingHandCursor()
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

/// Interactive app icon component with shadow effects and website link.
///
/// This component displays the VibeMeter app icon with dynamic shadow effects that respond
/// to user interaction. It includes hover effects for visual feedback and opens the
/// VibeMeter website when clicked.
struct InteractiveAppIcon: View {
    @State
    private var isHovering = false
    @State
    private var isPressed = false
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        ZStack {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .scaleEffect(isPressed ? 0.95 : (isHovering ? 1.05 : 1.0))
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: 0,
                    y: shadowOffset)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
                .animation(.easeInOut(duration: 0.1), value: isPressed)

            // Invisible button overlay for click handling
            Button(action: openWebsite) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 128, height: 128)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .pointingHandCursor()
        .onHover { hovering in
            isHovering = hovering
        }
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: { isPressed = false })
    }

    private var shadowColor: Color {
        if colorScheme == .dark {
            .black.opacity(isHovering ? 0.6 : 0.4)
        } else {
            .black.opacity(isHovering ? 0.3 : 0.2)
        }
    }

    private var shadowRadius: CGFloat {
        isHovering ? 20 : 12
    }

    private var shadowOffset: CGFloat {
        isHovering ? 8 : 4
    }

    private func openWebsite() {
        guard let url = URL(string: "https://vibemeter.ai") else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Preview

#Preview("About View") {
    AboutView(orchestrator: nil)
        .frame(width: 570, height: 600)
}
