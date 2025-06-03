import SwiftUI

// MARK: - Enhanced Settings View for Multi-Provider Support

/// Enhanced settings view that supports multiple service providers.
///
/// This view provides a comprehensive interface for managing:
/// - Multiple provider accounts (Cursor, Anthropic, etc.)
/// - Provider-specific settings and configurations
/// - General app preferences
/// - Spending limits per provider
/// - Provider selection and management
struct MultiProviderSettingsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @State
    private var showingProviderDetail: ServiceProvider?

    var body: some View {
        TabView {
            ProvidersSettingsView(
                settingsManager: settingsManager,
                userSessionData: userSessionData,
                loginManager: loginManager,
                showingProviderDetail: $showingProviderDetail)
                .tabItem {
                    Label("Providers", systemImage: "server.rack")
                }
                .tag(MultiProviderSettingsTab.providers)

            GeneralSettingsView(
                settingsManager: settingsManager as! SettingsManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(MultiProviderSettingsTab.general)

            SpendingLimitsView(
                settingsManager: settingsManager,
                userSessionData: userSessionData)
                .tabItem {
                    Label("Limits", systemImage: "exclamationmark.triangle")
                }
                .tag(MultiProviderSettingsTab.limits)

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(MultiProviderSettingsTab.advanced)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(MultiProviderSettingsTab.about)
        }
        .frame(width: 700, height: 500)
        .sheet(item: $showingProviderDetail) { provider in
            ProviderDetailView(
                provider: provider,
                settingsManager: settingsManager,
                userSessionData: userSessionData,
                loginManager: loginManager)
        }
    }
}

// MARK: - Settings Tabs

enum MultiProviderSettingsTab: CaseIterable {
    case providers, general, limits, advanced, about

    var title: String {
        switch self {
        case .providers: "Providers"
        case .general: "General"
        case .limits: "Limits"
        case .advanced: "Advanced"
        case .about: "About"
        }
    }
}

// MARK: - Providers Settings View

struct ProvidersSettingsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    @Binding
    var showingProviderDetail: ServiceProvider?

    private let providerRegistry = ProviderRegistry.shared

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 8) {
                Text("Service Providers")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                
                Text("Manage your cost tracking service account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            
            Section {
                VStack(spacing: 1) {
                    ForEach(ServiceProvider.allCases) { provider in
                        ProviderRowView(
                            provider: provider,
                            userSessionData: userSessionData,
                            loginManager: loginManager,
                            providerRegistry: providerRegistry,
                            showDetail: {
                                showingProviderDetail = provider
                            })
                            .background(Color(NSColor.controlBackgroundColor))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(NSColor.separatorColor).opacity(0.3), lineWidth: 0.5)
                )
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear {
            setupLoginCallbacks()
        }
    }

    private func setupLoginCallbacks() {
        loginManager.onLoginSuccess = { provider in
            // When login succeeds, we need to fetch user data to update the UI
            Task {
                // This is a placeholder - in a real implementation, we'd fetch
                // user data from the provider API and update userSessionData
                await updateUserSessionForProvider(provider)
            }
        }

        loginManager.onLoginFailure = { provider, error in
            userSessionData.handleLoginFailure(for: provider, error: error)
        }

        loginManager.onLoginDismiss = { _ in
            // Handle login dismissal if needed
        }
    }

    private func updateUserSessionForProvider(_ provider: ServiceProvider) async {
        guard let token = loginManager.getAuthToken(for: provider) else {
            userSessionData.handleLoginFailure(for: provider,
                                               error: NSError(domain: "SettingsView", code: 1,
                                                              userInfo: [
                                                                  NSLocalizedDescriptionKey: "No auth token found",
                                                              ]))
            return
        }

        do {
            // Create provider instance and fetch user data
            let providerFactory = ProviderFactory(settingsManager: settingsManager)
            let providerClient = providerFactory.createProvider(for: provider)

            // Fetch user info
            let userInfo = try await providerClient.fetchUserInfo(authToken: token)

            // Fetch team info if available
            var teamName: String?
            var teamId: Int?

            if provider.supportsTeams {
                do {
                    let teamInfo = try await providerClient.fetchTeamInfo(authToken: token)
                    teamName = teamInfo.name
                    teamId = teamInfo.id
                } catch {
                    // Team info is optional, continue without it
                }
            }

            // Update user session data with real API data
            userSessionData.handleLoginSuccess(
                for: provider,
                email: userInfo.email,
                teamName: teamName,
                teamId: teamId)

        } catch {
            userSessionData.handleLoginFailure(for: provider, error: error)
        }
    }
}

// MARK: - Provider Row View

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
            Image(systemName: provider.iconName)
                .font(.title2)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)

            // Provider info
            VStack(alignment: .leading, spacing: 4) {
                Text(provider.displayName)
                    .font(.headline)

                if let session, isLoggedIn {
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
                if isEnabled, !isLoggedIn {
                    Button("Login") {
                        loginManager.showLoginWindow(for: provider)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                if isLoggedIn {
                    Button("Logout") {
                        loginManager.logOut(from: provider)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Button("Details") {
                    showDetail()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        if !isEnabled {
            .gray
        } else if isLoggedIn {
            .green
        } else {
            .orange
        }
    }
}

// MARK: - Provider Detail View

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
                Image(systemName: provider.iconName)
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
                    // Connection Status Section
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
                    
                    // Provider Settings Section
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

    private func saveAndDismiss() {
        dismiss()
    }
}

// MARK: - Spending Limits View

struct SpendingLimitsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData

    @State
    private var warningLimitUSD: Double
    @State
    private var upperLimitUSD: Double

    init(settingsManager: any SettingsManagerProtocol, userSessionData: MultiProviderUserSessionData) {
        self.settingsManager = settingsManager
        self.userSessionData = userSessionData

        _warningLimitUSD = State(initialValue: settingsManager.warningLimitUSD)
        _upperLimitUSD = State(initialValue: settingsManager.upperLimitUSD)
    }

    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 8) {
                Text("Spending Limits")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.top, 10)
                    .padding(.horizontal, 10)
                
                Text("Set spending thresholds that apply to all connected providers. Limits are stored in USD.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            
            Section {
                LabeledContent("Amount") {
                    TextField("", value: $warningLimitUSD, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
                
                Text("You'll receive a notification when spending exceeds this amount.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Warning Limit")
                    .font(.headline)
            }
            
            Section {
                LabeledContent("Amount") {
                    TextField("", value: $upperLimitUSD, format: .currency(code: "USD"))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                }
                
                Text("You'll receive a critical notification when spending exceeds this amount.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Upper Limit")
                    .font(.headline)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: warningLimitUSD) { _, newValue in
            settingsManager.warningLimitUSD = newValue
        }
        .onChange(of: upperLimitUSD) { _, newValue in
            settingsManager.upperLimitUSD = newValue
        }
    }
}

// MARK: - Preview

#Preview("Settings - Not Logged In") {
    MultiProviderSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
    .frame(width: 700, height: 500)
}

#Preview("Settings - Logged In") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123
    )
    
    return MultiProviderSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
    .frame(width: 700, height: 500)
}

// MARK: - Mock Settings Manager for Preview

@MainActor
private class MockSettingsManager: SettingsManagerProtocol {
    var providerSessions: [ServiceProvider: ProviderSession] = [:]
    var selectedCurrencyCode: String = "USD"
    var warningLimitUSD: Double = 200
    var upperLimitUSD: Double = 500
    var refreshIntervalMinutes: Int = 5
    var launchAtLoginEnabled: Bool = false
    var showCostInMenuBar: Bool = true
    var showInDock: Bool = false
    var enabledProviders: Set<ServiceProvider> = [.cursor]
    
    func clearUserSessionData() {
        providerSessions.removeAll()
    }
    
    func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }
    
    func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }
    
    func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
    }
}
