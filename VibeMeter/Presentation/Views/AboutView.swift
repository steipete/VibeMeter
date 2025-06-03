import AppKit
import SwiftUI

/// About view displaying application information, version details, and credits.
///
/// This view provides information about VibeMeter including version numbers,
/// build details, developer credits, and links to external resources like
/// GitHub repository and support channels.
struct AboutView: View {
    let orchestrator: MultiProviderDataOrchestrator?
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
            .navigationTitle("About VibeMeter")
        }
    }

    private var appInfoSection: some View {
        VStack(spacing: 16) {
            InteractiveAppIcon()

            Text("VibeMeter")
                .font(.largeTitle)
                .fontWeight(.medium)

            Text("Version \(appVersion)")
                .foregroundStyle(.secondary)
        }
        .padding(.top, 20)
    }

    private var descriptionSection: some View {
        Text("Monitor your monthly Cursor AI spending")
            .foregroundStyle(.secondary)
    }

    private var linksSection: some View {
        VStack(spacing: 12) {
            Link(destination: URL(string: "https://github.com/steipete/VibeMeter")!) {
                Label("View on GitHub", systemImage: "link")
            }
            .buttonStyle(.link)
            .pointingHandCursor()

            Link(destination: URL(string: "https://github.com/steipete/VibeMeter/issues")!) {
                Label("Report an Issue", systemImage: "exclamationmark.bubble")
            }
            .buttonStyle(.link)
            .pointingHandCursor()

            Link(destination: URL(string: "https://x.com/steipete")!) {
                Label("Follow @steipete on X", systemImage: "bird")
            }
            .buttonStyle(.link)
            .pointingHandCursor()
        }
    }

    private var copyrightSection: some View {
        Text("© 2025 Peter Steinberger • MIT Licensed")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.bottom, 32)
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
        Button(action: openWebsite) {
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
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .pointingHandCursor()
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

/// View modifier for handling press events on buttons.
struct PressEventModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() })
    }
}

/// View modifier for showing pointing hand cursor on hover.
struct PointingHandCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        modifier(PressEventModifier(onPress: onPress, onRelease: onRelease))
    }

    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}

// MARK: - Preview

#Preview("About View") {
    AboutView(orchestrator: nil)
        .frame(width: 570, height: 600)
}
