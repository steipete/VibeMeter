import AppKit
import SwiftUI

/// Content view displayed when no providers are configured or logged in.
///
/// This view presents a friendly onboarding interface that guides users to configure
/// their first AI service provider. It opens the settings window directly to the
/// providers tab for easy setup.
struct NoProvidersConfiguredView: View {
    let onConfigureProviders: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top section with padding
            VStack(spacing: 20) {
                Spacer(minLength: 20)

                // App icon and title
                VStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityLabel("Vibe Meter application icon")

                    Text("Vibe Meter")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.primary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityAddTraits(.isHeader)

                    Text("Track Your AI Service Costs")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .accessibilityLabel("Application subtitle: Track Your AI Service Costs")
                }

                // Welcome message
                Text("Configure your first AI service provider to start tracking costs.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                // Configure providers button
                Button(action: onConfigureProviders) {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .font(.title3)

                        Text("Configure Providers")
                            .font(.title3.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ProminentGlassButtonStyle())
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .accessibilityLabel("Configure AI service providers")
                .accessibilityHint("Opens settings window to add and configure AI service providers")

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 20)

            // Bottom buttons section
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
                    .font(.title3.weight(.medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings (⌘,)")
            .accessibilityLabel("Open settings")
            .accessibilityHint("Opens Vibe Meter preferences and configuration options")

            Spacer()

            // Quit button
            Button(action: quit) {
                Image(systemName: "power")
                    .font(.title3.weight(.medium))
            }
            .buttonStyle(IconButtonStyle(isDestructive: true))
            .help("Quit Vibe Meter (⌘Q)")
            .accessibilityLabel("Quit application")
            .accessibilityHint("Closes Vibe Meter completely")
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

#Preview("No Providers Configured") {
    NoProvidersConfiguredView(
        onConfigureProviders: {
            print("Configure providers triggered - would open settings")
        })
        .frame(width: 300, height: 400)
        .background(.thickMaterial)
}
