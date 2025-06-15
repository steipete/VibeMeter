import SwiftUI

/// Main settings view containing tabbed interface for application configuration.
///
/// This view provides a comprehensive settings interface with separate tabs for
/// general preferences, provider management, and spending limits. It serves as
/// the primary configuration hub for the VibeMeter application.
struct MultiProviderSettingsView: View {
    // Support both initializer and environment injection patterns
    private let injectedSettingsManager: (any SettingsManagerProtocol)?
    private let injectedUserSessionData: MultiProviderUserSessionData?
    private let injectedLoginManager: MultiProviderLoginManager?
    private let injectedOrchestrator: MultiProviderDataOrchestrator?
    
    @Environment(\.settingsManager) private var envSettingsManager: (any SettingsManagerProtocol)?
    @Environment(\.userSessionData) private var envUserSessionData: MultiProviderUserSessionData?
    @Environment(\.loginManager) private var envLoginManager: MultiProviderLoginManager?
    @Environment(\.dataOrchestrator) private var envOrchestrator: MultiProviderDataOrchestrator?
    
    // Computed properties that prefer environment values but fall back to injected ones
    private var settingsManager: (any SettingsManagerProtocol)? {
        envSettingsManager ?? injectedSettingsManager
    }
    
    private var userSessionData: MultiProviderUserSessionData? {
        envUserSessionData ?? injectedUserSessionData
    }
    
    private var loginManager: MultiProviderLoginManager? {
        envLoginManager ?? injectedLoginManager
    }
    
    private var orchestrator: MultiProviderDataOrchestrator? {
        envOrchestrator ?? injectedOrchestrator
    }
    
    // New environment-based initializer
    init() {
        self.injectedSettingsManager = nil
        self.injectedUserSessionData = nil
        self.injectedLoginManager = nil
        self.injectedOrchestrator = nil
    }
    
    // Legacy initializer for backward compatibility
    init(
        settingsManager: any SettingsManagerProtocol,
        userSessionData: MultiProviderUserSessionData,
        loginManager: MultiProviderLoginManager,
        orchestrator: MultiProviderDataOrchestrator? = nil
    ) {
        self.injectedSettingsManager = settingsManager
        self.injectedUserSessionData = userSessionData
        self.injectedLoginManager = loginManager
        self.injectedOrchestrator = orchestrator
    }

    @State
    private var showingProviderDetail: ServiceProvider?

    @State
    private var selectedTab: MultiProviderSettingsTab = .general

    var body: some View {
        if let settingsManager = settingsManager,
           let userSessionData = userSessionData,
           let loginManager = loginManager {
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
        } else {
            // Fallback view when dependencies are missing
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                
                Text("Configuration Error")
                    .font(.headline)
                
                Text("Required dependencies are not available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 570, height: 500)
            .padding()
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
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
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
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())))
        .frame(width: 570, height: 500)
}
