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

                    Text("VibeMeter")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Multi-Provider Cost Tracking")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                // Login button
                Button(action: { loginManager.showLoginWindow(for: .cursor) }) {
                    Label("Login to Cursor", systemImage: "person.crop.circle.badge.plus")
                        .font(.system(size: 14, weight: .medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProminentGlassButtonStyle())

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
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings")

            Spacer()

            // Quit button
            Button(action: quit) {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(IconButtonStyle(isDestructive: true))
            .help("Quit VibeMeter")
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
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    )
    .frame(width: 300, height: 350)
    .background(.thickMaterial)
}
