import SwiftUI

struct MultiProviderSettingsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    @State
    private var showingProviderDetail: ServiceProvider?

    var body: some View {
        TabView {
            GeneralSettingsView(
                settingsManager: settingsManager as! SettingsManager)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(MultiProviderSettingsTab.general)

            ProvidersSettingsView(
                settingsManager: settingsManager,
                userSessionData: userSessionData,
                loginManager: loginManager,
                showingProviderDetail: $showingProviderDetail)
                .tabItem {
                    Label("Providers", systemImage: "server.rack")
                }
                .tag(MultiProviderSettingsTab.providers)

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
    case general, providers, limits, advanced, about

    var title: String {
        switch self {
        case .general: "General"
        case .providers: "Providers"
        case .limits: "Limits"
        case .advanced: "Advanced"
        case .about: "About"
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
        teamId: 123)

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
