import SwiftUI

struct ProviderDetailView: View {
    let provider: ServiceProvider
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @Environment(\.dismiss)
    private var dismiss
    @State
    private var isEnabled: Bool
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

        _isEnabled = State(initialValue: ProviderRegistry.shared.isEnabled(provider))
        _customSettings = State(initialValue: ProviderRegistry.shared.configuration(for: provider).customSettings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack(spacing: 12) {
                providerIcon(for: provider)
                    .font(.title2)
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
                Toggle("Enable \(provider.displayName) tracking", isOn: $isEnabled)

                if isEnabled, let session = userSessionData.getSession(for: provider) {
                    connectionStatusSection(session: session)
                    providerSettingsSection
                }
            }

            Spacer()

            // Footer buttons
            HStack {
                if isEnabled {
                    if userSessionData.isLoggedIn(to: provider) {
                        Button("Logout", role: .destructive) {
                            loginManager.logOut(from: provider)
                        }
                    } else {
                        Button("Login") {
                            loginManager.showLoginWindow(for: provider)
                        }
                        .buttonStyle(.borderedProminent)
                    }
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
        .onChange(of: isEnabled) { _, newValue in
            let configuration = ProviderConfiguration(
                provider: provider,
                isEnabled: newValue,
                customSettings: customSettings)

            if newValue {
                providerRegistry.enableProvider(provider)
            } else {
                providerRegistry.disableProvider(provider)
                loginManager.logOut(from: provider)
            }

            providerRegistry.updateConfiguration(configuration)
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

    private func providerIcon(for provider: ServiceProvider) -> Image {
        if provider.iconName.contains(".") {
            Image(systemName: provider.iconName)
        } else {
            Image(provider.iconName)
        }
    }
}