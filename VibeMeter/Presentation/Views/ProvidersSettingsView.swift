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
                    }
                } header: {
                    Text("Service Providers")
                        .font(.headline)
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
    let userSessionData = MultiProviderUserSessionData()
    @State var showingProviderDetail: ServiceProvider?
    
    // Set up one logged in provider
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123
    )
    
    return ProvidersSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        ),
        showingProviderDetail: $showingProviderDetail
    )
    .frame(width: 620, height: 400)
}

#Preview("Providers Settings - All Logged Out") {
    @State var showingProviderDetail: ServiceProvider?
    
    return ProvidersSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        ),
        showingProviderDetail: $showingProviderDetail
    )
    .frame(width: 620, height: 400)
}
