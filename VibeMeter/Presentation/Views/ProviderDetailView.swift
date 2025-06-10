import SwiftUI

// MARK: - RadioButton Component

private struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 2)
                    .frame(width: 16, height: 16)

                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

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

    @State
    private var claudeAccountType: ClaudePricingTier = .pro

    @State
    private var showUsageReport = false

    @StateObject
    private var claudeLogManager = ClaudeLogManager.shared

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
        .frame(width: 600, height: provider == .claude ? 700 : 500)
        .task {
            // Load custom settings when view appears
            customSettings = providerRegistry.configuration(for: provider).customSettings

            // Load Claude account type if applicable
            if provider == .claude {
                claudeAccountType = (settingsManager as? SettingsManager)?.sessionSettingsManager
                    .claudeAccountType ?? .pro
            }
        }
        .onChange(of: provider) { _, newProvider in
            // Update settings if provider changes
            customSettings = providerRegistry.configuration(for: newProvider).customSettings
        }
        .sheet(isPresented: $showUsageReport) {
            ClaudeUsageReportView()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showClaudeUsageReport"))) { _ in
            if provider == .claude {
                showUsageReport = true
            }
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

                // Claude-specific settings
                if provider == .claude {
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Subscription Tier")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(ClaudePricingTier.allCases, id: \.self) { tier in
                                HStack(alignment: .top, spacing: 12) {
                                    RadioButton(isSelected: claudeAccountType == tier) {
                                        claudeAccountType = tier
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tier.displayName)
                                            .font(.system(.body))
                                            .fontWeight(claudeAccountType == tier ? .medium : .regular)

                                        Text(tier.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    claudeAccountType = tier
                                }
                            }
                        }
                        .padding(.leading, 4)

                        // Usage Report button
                        if claudeLogManager.hasAccess {
                            Divider()
                                .padding(.vertical, 4)

                            Button(action: {
                                showUsageReport = true
                            }) {
                                HStack {
                                    Image(systemName: "chart.bar.doc.horizontal")
                                    Text("View Token Usage Report")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .onChange(of: claudeAccountType) { _, newValue in
                        saveClaudeAccountType(newValue)
                    }
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

    // MARK: - Helper Methods

    private func saveClaudeAccountType(_ accountType: ClaudePricingTier) {
        if let settingsManager = settingsManager as? SettingsManager {
            settingsManager.sessionSettingsManager.claudeAccountType = accountType
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
