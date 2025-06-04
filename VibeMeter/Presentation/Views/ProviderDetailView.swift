import SwiftUI

/// Detailed view for a specific service provider showing connection status and management options.
///
/// This view displays comprehensive information about a selected provider including
/// connection status, user account details, login/logout capabilities, and provider-specific
/// settings. It appears as a sheet when users want to manage individual provider connections.
struct ProviderDetailView: View {
    let provider: ServiceProvider
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @Environment(\.dismiss)
    private var dismiss
    @State
    private var customSettings: [String: String] = [:]

    private let providerRegistry = ProviderRegistry.shared

    init(
        provider: ServiceProvider,
        settingsManager: any SettingsManagerProtocol,
        userSessionData: MultiProviderUserSessionData,
        loginManager: MultiProviderLoginManager) {
        self.provider = provider
        self.settingsManager = settingsManager
        self.userSessionData = userSessionData
        self.loginManager = loginManager
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack(spacing: 12) {
                providerIcon(for: provider)
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Link(provider.websiteURL.absoluteString, destination: provider.websiteURL)
                        .font(.subheadline)
                        .foregroundStyle(.link)
                }

                Spacer()
            }

            Divider()

            // Content
            VStack(alignment: .leading, spacing: 24) {
                if let session = userSessionData.getSession(for: provider) {
                    connectionStatusSection(session: session)
                    providerSettingsSection

                    // Logout button for logged in users
                    if userSessionData.isLoggedIn(to: provider) {
                        HStack {
                            Spacer()
                            Button("Log Out", role: .destructive) {
                                loginManager.logOut(from: provider)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Spacer()

            // Footer buttons
            HStack {
                if !userSessionData.isLoggedIn(to: provider) {
                    Button("Login") {
                        loginManager.showLoginWindow(for: provider)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()

                Button("Done") {
                    saveAndDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500, height: 520)
        .task {
            // Load custom settings when view appears
            customSettings = providerRegistry.configuration(for: provider).customSettings
        }
        .onChange(of: provider) { _, newProvider in
            // Update settings if provider changes
            customSettings = providerRegistry.configuration(for: newProvider).customSettings
        }
    }

    private func connectionStatusSection(session: ProviderSessionState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connection Status")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Status:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(session.isLoggedIn ? "Connected" : "Not connected")
                        .foregroundStyle(session.isLoggedIn ? .green : .orange)
                        .fontWeight(.medium)
                }

                if let email = session.userEmail {
                    HStack {
                        Text("Account:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(email)
                    }
                }

                if let teamName = session.teamName {
                    HStack {
                        Text("Team:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(teamName)
                    }
                }

                HStack {
                    Text("Last updated:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(session.lastUpdated, style: .relative)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var providerSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Provider Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Default currency:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(provider.defaultCurrency)
                }

                HStack {
                    Text("Supports teams:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(provider.supportsTeams ? "Yes" : "No")
                }

                HStack {
                    Text("Keychain service:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(provider.keychainService)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func saveAndDismiss() {
        dismiss()
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

#Preview("Provider Detail - Logged In") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123)

    return ProviderDetailView(
        provider: .cursor,
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
}

#Preview("Provider Detail - Not Logged In") {
    ProviderDetailView(
        provider: .cursor,
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
}
