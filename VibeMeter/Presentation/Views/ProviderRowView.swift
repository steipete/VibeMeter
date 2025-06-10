import AppKit
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
    let settingsManager: any SettingsManagerProtocol
    let showDetail: () -> Void

    @StateObject
    private var claudeLogManager = ClaudeLogManager.shared

    @State
    private var isExpanded = false

    @State
    private var claudeAccountType: ClaudePricingTier = .pro

    @Namespace
    private var animation

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
        VStack(spacing: 0) {
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

                // Status indicator
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

                    // Expand/collapse button
                    if isEnabled {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isEnabled {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Expandable details section
            if isExpanded, isEnabled {
                VStack(alignment: .leading, spacing: 16) {
                    Divider()
                        .padding(.horizontal, -16)

                    detailsContent
                }
                .padding(.top, 12)
                .padding(.bottom, 4)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)))
            }
        }
        .task {
            // Load Claude account type if applicable
            if provider == .claude {
                claudeAccountType = (settingsManager as? SettingsManager)?.sessionSettingsManager
                    .claudeAccountType ?? .pro
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

    @ViewBuilder
    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Connection Status
            if let session {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Connection Details")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("Last updated:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(session.lastUpdated, style: .relative)
                            .foregroundStyle(.tertiary)
                    }
                    .font(.caption)
                }
            }

            // Provider-specific settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Provider Settings")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("Default currency:")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(provider.defaultCurrency)
                }
                .font(.caption)

                if provider.supportsTeams {
                    HStack {
                        Text("Supports teams:")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Yes")
                    }
                    .font(.caption)
                }
            }

            // Claude-specific settings
            if provider == .claude {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Subscription Tier")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    ForEach(ClaudePricingTier.allCases, id: \.self) { tier in
                        HStack(alignment: .top, spacing: 12) {
                            RadioButton(isSelected: claudeAccountType == tier) {
                                claudeAccountType = tier
                                saveClaudeAccountType(tier)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(tier.displayName)
                                    .font(.caption)
                                    .fontWeight(claudeAccountType == tier ? .medium : .regular)

                                Text(tier.description)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            claudeAccountType = tier
                            saveClaudeAccountType(tier)
                        }
                    }

                    // Usage Report button
                    if claudeLogManager.hasAccess {
                        Button(action: {
                            ClaudeUsageReportWindowController.showWindow()
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
                        .font(.caption)
                    }
                }
            }
        }
    }

    private func saveClaudeAccountType(_ accountType: ClaudePricingTier) {
        if let settingsManager = settingsManager as? SettingsManager {
            settingsManager.sessionSettingsManager.claudeAccountType = accountType
        }
    }
}

// MARK: - RadioButton Component

private struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.5), lineWidth: 1.5)
                    .frame(width: 14, height: 14)

                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .buttonStyle(.plain)
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
        settingsManager: MockSettingsManager(),
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
        settingsManager: MockSettingsManager(),
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
        settingsManager: MockSettingsManager(),
        showDetail: {})
        .padding()
        .frame(width: 600)
        .background(Color(NSColor.windowBackgroundColor))
}
