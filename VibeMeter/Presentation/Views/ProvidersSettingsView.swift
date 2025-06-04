import SwiftUI

/// Settings view for managing service provider connections and authentication.
///
/// This view displays all supported service providers with their connection status,
/// login/logout capabilities, and access to detailed provider information. Users can
/// manage multiple provider connections from this centralized interface.
struct ProvidersSettingsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    let orchestrator: MultiProviderDataOrchestrator?
    @Binding
    var showingProviderDetail: ServiceProvider?

    private let providerRegistry = ProviderRegistry.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(ServiceProvider.allCases) { provider in
                        ProviderRowView(
                            provider: provider,
                            userSessionData: userSessionData,
                            loginManager: loginManager,
                            providerRegistry: providerRegistry,
                            showDetail: {
                                showingProviderDetail = provider
                            })
                            .id({
                                let email = userSessionData.getSession(for: provider)?.userEmail ?? "none"
                                let isLoggedIn = userSessionData.isLoggedIn(to: provider)
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
                        Text("Support for more providers is coming soon. Help appreciated.")
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
        loginManager.onLoginSuccess = { provider in
            Task {
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

    ProvidersSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        orchestrator: nil,
        showingProviderDetail: $showingProviderDetail)
        .frame(width: 570, height: 400)
}

#Preview("Providers Settings - All Logged Out") {
    @Previewable @State
    var showingProviderDetail: ServiceProvider?

    ProvidersSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        orchestrator: nil,
        showingProviderDetail: $showingProviderDetail)
        .frame(width: 570, height: 400)
}
