import SwiftUI

/// Row view component for displaying provider information in settings lists.
///
/// This view shows provider details including name, icon, connection status, and
/// action buttons for login/logout. It's used in the providers settings section
/// to manage multiple service provider connections in a consistent list format.
struct ProviderRowView: View {
    let provider: ServiceProvider
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    let providerRegistry: ProviderRegistry
    let showDetail: () -> Void

    private var session: ProviderSessionState? {
        userSessionData.getSession(for: provider)
    }

    private var isLoggedIn: Bool {
        userSessionData.isLoggedIn(to: provider)
    }

    private var isEnabled: Bool {
        providerRegistry.isEnabled(provider)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Provider icon
            providerIcon(for: provider)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.headline)

                if provider == .claude {
                    // Claude shows folder access status
                    if ClaudeLogManager.shared.hasAccess {
                        Text("Folder access granted")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No folder access")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else if let session, isLoggedIn {
                    Text(session.userEmail ?? "Unknown user")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let teamName = session.teamName {
                        Text("Team: \(teamName)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } else if isEnabled {
                    Text("Not connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Disabled")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                if let errorMessage = session?.lastErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Action buttons
            HStack(spacing: 8) {
                if provider == .claude {
                    // Claude uses folder access instead of login
                    if !ClaudeLogManager.shared.hasAccess {
                        Button("Grant Access") {
                            Task {
                                _ = await ClaudeLogManager.shared.requestLogAccess()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Revoke Access") {
                            ClaudeLogManager.shared.revokeAccess()
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    // Other providers use login
                    if isEnabled, !isLoggedIn {
                        Button("Login") {
                            loginManager.showLoginWindow(for: provider)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if isLoggedIn {
                        Button("Logout") {
                            loginManager.logOut(from: provider)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Button("Details") {
                    showDetail()
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var statusColor: Color {
        if !isEnabled {
            .gray
        } else if provider == .claude {
            ClaudeLogManager.shared.hasAccess ? .green : .orange
        } else if isLoggedIn {
            .green
        } else {
            .orange
        }
    }

    private func providerIcon(for provider: ServiceProvider) -> some View {
        Group {
            if provider.iconName.contains(".") {
                // System symbol - use font sizing
                Image(systemName: provider.iconName)
                    .font(.title2)
            } else {
                // Custom asset - use resizable with explicit sizing
                Image(provider.iconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}

// MARK: - Preview

#Preview("Provider Row - Logged In") {
    @Previewable @State
    var userSessionData = {
        let data = MultiProviderUserSessionData()
        data.handleLoginSuccess(
            for: .cursor,
            email: "user@example.com",
            teamName: "Example Team",
            teamId: 123)
        return data
    }()

    ProviderRowView(
        provider: .cursor,
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        providerRegistry: ProviderRegistry.shared,
        showDetail: {})
        .padding()
        .frame(width: 600)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Provider Row - Not Connected") {
    ProviderRowView(
        provider: .cursor,
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        providerRegistry: ProviderRegistry.shared,
        showDetail: {})
        .padding()
        .frame(width: 600)
        .background(Color(NSColor.windowBackgroundColor))
}

#Preview("Provider Row - With Error") {
    @Previewable @State
    var userSessionData = {
        let data = MultiProviderUserSessionData()
        data.setErrorMessage(for: .cursor, message: "Authentication failed: Invalid credentials")
        return data
    }()

    ProviderRowView(
        provider: .cursor,
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        providerRegistry: ProviderRegistry.shared,
        showDetail: {})
        .padding()
        .frame(width: 600)
        .background(Color(NSColor.windowBackgroundColor))
}
