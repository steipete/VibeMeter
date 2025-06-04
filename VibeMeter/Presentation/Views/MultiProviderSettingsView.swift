import SwiftUI

/// Main settings view containing tabbed interface for application configuration.
///
/// This view provides a comprehensive settings interface with separate tabs for
/// general preferences, provider management, and spending limits. It serves as
/// the primary configuration hub for the VibeMeter application.
struct MultiProviderSettingsView: View {
    let settingsManager: any SettingsManagerProtocol
    let userSessionData: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager
    let orchestrator: MultiProviderDataOrchestrator?

    @State
    private var showingProviderDetail: ServiceProvider?

    @State
    private var selectedTab: MultiProviderSettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
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
                orchestrator: orchestrator,
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
            
            AdvancedSettingsView(
                settingsManager: settingsManager as! SettingsManager)
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
                .tag(MultiProviderSettingsTab.advanced)

            AdvancedSettingsView(settingsManager: settingsManager as! SettingsManager)
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .tag(MultiProviderSettingsTab.advanced)

            AboutView(orchestrator: orchestrator)
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(MultiProviderSettingsTab.about)
        }
        .frame(width: 570, height: 500)
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsTab)) { notification in
            if let tab = notification.object as? MultiProviderSettingsTab {
                selectedTab = tab
            }
        }
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

// MARK: - Notification Names

extension Notification.Name {
    static let openSettingsTab = Notification.Name("openSettingsTab")
}

// MARK: - Preview

#Preview("Settings - Not Logged In") {
    MultiProviderSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        orchestrator: nil)
        .frame(width: 570, height: 500)
}

@MainActor
private func makeUserSessionData() -> MultiProviderUserSessionData {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123)
    return userSessionData
}

#Preview("Settings - Logged In") {
    MultiProviderSettingsView(
        settingsManager: MockSettingsManager(),
        userSessionData: makeUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())),
        orchestrator: nil)
        .frame(width: 570, height: 500)
}
