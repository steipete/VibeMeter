import AppKit
import SwiftUI

/// Content view displayed when no service providers are connected.
///
/// This view provides the initial login interface for users to connect to supported
/// service providers like Cursor AI. It presents available providers with login buttons
/// and brief descriptions of the service integration.
struct LoggedOutContentView: View {
    let loginManager: MultiProviderLoginManager

    var body: some View {
        VStack(spacing: 0) {
            // Top section with padding matching logged-in content
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                // App icon and title
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityLabel("VibeMeter application icon")

                    Text("VibeMeter")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityAddTraits(.isHeader)

                    Text("Multi-Provider Cost Tracking")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityLabel("Application subtitle: Multi-Provider Cost Tracking")
                }

                // Login button
                Button(action: { loginManager.showLoginWindow(for: .cursor) }) {
                    Label("Login to Cursor", systemImage: "person.crop.circle.badge.plus")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProminentGlassButtonStyle())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityLabel("Login to Cursor AI")
                .accessibilityHint("Opens browser window to authenticate with Cursor service")

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)

            // Bottom buttons section matching logged-in layout
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Settings button
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings (⌘,)")
            .accessibilityLabel("Open settings")
            .accessibilityHint("Opens VibeMeter preferences and configuration options")

            Spacer()

            // Quit button
            Button(action: quit) {
                Image(systemName: "power")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(IconButtonStyle(isDestructive: true))
            .help("Quit VibeMeter (⌘Q)")
            .accessibilityLabel("Quit application")
            .accessibilityHint("Closes VibeMeter completely")
        }
    }

    private func openSettings() {
        NSApp.openSettings()
    }

    private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Preview

#Preview("Logged Out Content") {
    LoggedOutContentView(
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .frame(width: 300, height: 350)
        .background(.thickMaterial)
}
