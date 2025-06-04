import AppKit
import SwiftUI

/// Content view displayed when no service providers are connected.
///
/// This view provides the initial login interface for users to connect to supported
/// service providers like Cursor AI. It presents available providers with login buttons
/// and brief descriptions of the service integration.
struct LoggedOutContentView: View {
    let loginManager: MultiProviderLoginManager
    let userSessionData: MultiProviderUserSessionData
    
    private var cursorSession: ProviderSessionState? {
        userSessionData.getSession(for: .cursor)
    }
    
    private var isAuthenticating: Bool {
        cursorSession?.isAuthenticating ?? false
    }
    
    private var errorMessage: String? {
        cursorSession?.lastErrorMessage
    }

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

                // Login button with loading state
                VStack(spacing: 12) {
                    Button(action: { 
                        userSessionData.setAuthenticating(for: .cursor)
                        loginManager.showLoginWindow(for: .cursor) 
                    }) {
                        HStack(spacing: 8) {
                            if isAuthenticating {
                                // Use a simple rotating icon for loading state
                                Image(systemName: "arrow.2.circlepath")
                                    .font(.title3)
                                    .rotationEffect(.degrees(isAuthenticating ? 360 : 0))
                                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isAuthenticating)
                            } else {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.title3)
                            }
                            
                            Text(isAuthenticating ? "Logging in..." : "Login to Cursor")
                                .font(.title3.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ProminentGlassButtonStyle())
                    .disabled(isAuthenticating)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityLabel(isAuthenticating ? "Logging in to Cursor AI" : "Login to Cursor AI")
                    .accessibilityHint("Opens browser window to authenticate with Cursor service")
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                            
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

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
                    .font(.title3.weight(.medium))
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings (⌘,)")
            .accessibilityLabel("Open settings")
            .accessibilityHint("Opens VibeMeter preferences and configuration options")

            Spacer()

            // Quit button
            Button(action: quit) {
                Image(systemName: "power")
                    .font(.title3.weight(.medium))
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
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        userSessionData: MultiProviderUserSessionData())
        .frame(width: 300, height: 350)
        .background(.thickMaterial)
}

#Preview("Logged Out Content - Authenticating") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.setAuthenticating(for: .cursor)
    
    return LoggedOutContentView(
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        userSessionData: userSessionData)
        .frame(width: 300, height: 350)
        .background(.thickMaterial)
}

#Preview("Logged Out Content - With Error") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.setErrorMessage(for: .cursor, message: "Authentication failed. Please try again.")
    
    return LoggedOutContentView(
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        userSessionData: userSessionData)
        .frame(width: 300, height: 350)
        .background(.thickMaterial)
}