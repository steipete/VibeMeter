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

    @StateObject
    private var claudeLogManager = ClaudeLogManager.shared

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
            // Enable/disable toggle
            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { newValue in
                    if newValue {
                        providerRegistry.enableProvider(provider)
                    } else {
                        providerRegistry.disableProvider(provider)
                    }
                }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
            
            // Provider icon
            providerIcon(for: provider)
                .foregroundStyle(isEnabled ? .primary : .secondary)
                .frame(width: 32, height: 32)

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.headline)
                    .foregroundStyle(isEnabled ? .primary : .secondary)

                if provider == .claude {
                    // Claude shows folder access status
                    if claudeLogManager.hasAccess {
                        Text("Folder access granted")
                            .font(.subheadline)
                            .foregroundStyle(isEnabled ? .secondary : .tertiary)
                    } else {
                        Text("No folder access")
                            .font(.subheadline)
                            .foregroundStyle(isEnabled ? .secondary : .tertiary)
                    }
                } else if let session, isLoggedIn {
                    Text(session.userEmail ?? "Unknown user")
                        .font(.subheadline)
                        .foregroundStyle(isEnabled ? .secondary : .tertiary)

                    if let teamName = session.teamName {
                        Text("Team: \(teamName)")
                            .font(.caption)
                            .foregroundStyle(isEnabled ? .tertiary : .quaternary)
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
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            // Status indicatortest
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            // Action buttons
            HStack(spacing: 8) {
                if provider == .claude {
                    // Claude uses folder access instead of login
                    if !claudeLogManager.hasAccess {
                        Button("Grant Access") {
                            Task {
                                // Enable Claude first if disabled
                                if !isEnabled {
                                    ProviderRegistry.shared.enableProvider(provider)
                                }
                                
                                let granted = await claudeLogManager.requestLogAccess()
                                if granted {
                                    // Trigger login success flow for Claude
                                    loginManager.onLoginSuccess?(provider)
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    // Other providers use login
                    if !isLoggedIn {
                        Button("Login") {
                            // Enable provider first if disabled
                            if !isEnabled {
                                ProviderRegistry.shared.enableProvider(provider)
                            }
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
            claudeLogManager.hasAccess ? .green : .orange
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
