import SwiftUI

/// Settings view for managing service provider connections and authentication.
///
/// This view displays all supported service providers with their connection status,
/// login/logout capabilities, and access to detailed provider information. Users can
/// manage multiple provider connections from this centralized interface.
struct ProvidersSettingsView: View {
    @Environment(\.settingsManager) private var settingsManager: (any SettingsManagerProtocol)?
    @Environment(\.userSessionData) private var userSessionData: MultiProviderUserSessionData?
    @Environment(\.loginManager) private var loginManager: MultiProviderLoginManager?
    @Environment(\.dataOrchestrator) private var orchestrator: MultiProviderDataOrchestrator?
    @Environment(\.providerRegistry) private var providerRegistry: ProviderRegistry
    
    @Binding
    var showingProviderDetail: ServiceProvider?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ServiceProvider.allCases) { provider in
                        ProviderRowView(
                            provider: provider,
                            showDetail: {
                                showingProviderDetail = provider
                            })
                            .id({
                                let email = userSessionData?.getSession(for: provider)?.userEmail ?? "none"
                                let isLoggedIn = userSessionData?.isLoggedIn(to: provider) ?? false
                                return "\(provider.rawValue)-\(email)-\(isLoggedIn)"
                            }())
                    }
                } header: {
                    HStack {
                        Text("Service Providers")
                            .font(.headline)

                        Spacer()

                        if let orchestrator {
                            NetworkStatusIndicator(
                                networkStatus: orchestrator.networkStatus,
                                isConnected: orchestrator.isNetworkConnected,
                                compact: true)
                        }
                    }
                } footer: {
                    HStack {
                        Spacer()
                        Text(
                            "Currently supporting Cursor AI and Claude subscriptions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("Providers")
        }
        .onAppear {
            setupLoginCallbacks()
        }
    }

    private func setupLoginCallbacks() {
        guard let loginManager else { return }
        
        loginManager.onLoginSuccess = { provider in
            Task {
                await updateUserSessionForProvider(provider)
            }
        }

        loginManager.onLoginFailure = { provider, error in
            userSessionData?.handleLoginFailure(for: provider, error: error)
        }

        loginManager.onLoginDismiss = { _ in
            // Handle login dismissal if needed
        }
    }

    private func updateUserSessionForProvider(_ provider: ServiceProvider) async {
        // Claude uses folder access, not auth tokens
        if provider == .claude {
            // For Claude, we just mark it as logged in with a placeholder email
            userSessionData?.handleLoginSuccess(
                for: provider,
                email: "Local Claude User",
                teamName: nil,
                teamId: nil)
            return
        }

        guard let loginManager, let token = loginManager.getAuthToken(for: provider) else {
            userSessionData?.handleLoginFailure(for: provider,
                                               error: NSError(domain: "SettingsView", code: 1,
                                                              userInfo: [
                                                                  NSLocalizedDescriptionKey: "No auth token found",
                                                              ]))
            return
        }

        do {
            guard let settingsManager else { return }
            let providerFactory = ProviderFactory(settingsManager: settingsManager)
            let providerClient = providerFactory.createProvider(for: provider)

            let userInfo = try await providerClient.fetchUserInfo(authToken: token)

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

            userSessionData?.handleLoginSuccess(
                for: provider,
                email: userInfo.email,
                teamName: teamName,
                teamId: teamId)

        } catch {
            userSessionData?.handleLoginFailure(for: provider, error: error)
        }
    }
}

// MARK: - Preview

#Preview("Providers Settings - Multiple States") {
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
    @Previewable @State
    var showingProviderDetail: ServiceProvider?

    ProvidersSettingsView(showingProviderDetail: $showingProviderDetail)
        .settingsManager(MockSettingsManager())
        .userSessionData(userSessionData)
        .loginManager(MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .frame(width: 570, height: 400)
}

#Preview("Providers Settings - All Logged Out") {
    @Previewable @State
    var showingProviderDetail: ServiceProvider?

    ProvidersSettingsView(showingProviderDetail: $showingProviderDetail)
        .settingsManager(MockSettingsManager())
        .userSessionData(MultiProviderUserSessionData())
        .loginManager(MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .frame(width: 570, height: 400)
}
