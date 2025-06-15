import SwiftUI

// MARK: - Environment Keys

/// Environment key for SettingsManager dependency
private struct SettingsManagerKey: EnvironmentKey {
    static let defaultValue: (any SettingsManagerProtocol)? = nil
}

/// Environment key for UserSessionData dependency
private struct UserSessionDataKey: EnvironmentKey {
    static let defaultValue: MultiProviderUserSessionData? = nil
}

/// Environment key for LoginManager dependency
private struct LoginManagerKey: EnvironmentKey {
    static let defaultValue: MultiProviderLoginManager? = nil
}

/// Environment key for DataOrchestrator dependency
private struct DataOrchestratorKey: EnvironmentKey {
    static let defaultValue: MultiProviderDataOrchestrator? = nil
}

/// Environment key for ProviderRegistry dependency
private struct ProviderRegistryKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: ProviderRegistry = .shared
}

/// Environment key for refresh action callback
private struct RefreshActionKey: EnvironmentKey {
    static let defaultValue: (@Sendable () async -> Void)? = nil
}

// MARK: - EnvironmentValues Extensions

extension EnvironmentValues {
    /// The app's settings manager for managing user preferences
    var settingsManager: (any SettingsManagerProtocol)? {
        get { self[SettingsManagerKey.self] }
        set { self[SettingsManagerKey.self] = newValue }
    }
    
    /// The user session data for all providers
    var userSessionData: MultiProviderUserSessionData? {
        get { self[UserSessionDataKey.self] }
        set { self[UserSessionDataKey.self] = newValue }
    }
    
    /// The login manager for handling provider authentication
    var loginManager: MultiProviderLoginManager? {
        get { self[LoginManagerKey.self] }
        set { self[LoginManagerKey.self] = newValue }
    }
    
    /// The main data orchestrator for coordinating provider operations
    var dataOrchestrator: MultiProviderDataOrchestrator? {
        get { self[DataOrchestratorKey.self] }
        set { self[DataOrchestratorKey.self] = newValue }
    }
    
    /// The provider registry for managing enabled/disabled providers
    var providerRegistry: ProviderRegistry {
        get { self[ProviderRegistryKey.self] }
        set { self[ProviderRegistryKey.self] = newValue }
    }
    
    /// The refresh action callback for triggering data updates
    var refreshAction: (@Sendable () async -> Void)? {
        get { self[RefreshActionKey.self] }
        set { self[RefreshActionKey.self] = newValue }
    }
}

// MARK: - View Extensions for Dependency Injection

extension View {
    /// Injects the settings manager into the environment
    func settingsManager(_ manager: any SettingsManagerProtocol) -> some View {
        environment(\.settingsManager, manager)
    }
    
    /// Injects the user session data into the environment
    func userSessionData(_ data: MultiProviderUserSessionData) -> some View {
        environment(\.userSessionData, data)
    }
    
    /// Injects the login manager into the environment
    func loginManager(_ manager: MultiProviderLoginManager) -> some View {
        environment(\.loginManager, manager)
    }
    
    /// Injects the data orchestrator into the environment
    func dataOrchestrator(_ orchestrator: MultiProviderDataOrchestrator) -> some View {
        environment(\.dataOrchestrator, orchestrator)
    }
    
    /// Injects the provider registry into the environment
    func providerRegistry(_ registry: ProviderRegistry) -> some View {
        environment(\.providerRegistry, registry)
    }
    
    /// Injects the refresh action into the environment
    func refreshAction(_ action: @escaping @Sendable () async -> Void) -> some View {
        environment(\.refreshAction, action)
    }
    
    /// Convenience method to inject all VibeMeter dependencies at once
    func vibeMeterEnvironment(
        settingsManager: any SettingsManagerProtocol,
        userSessionData: MultiProviderUserSessionData,
        loginManager: MultiProviderLoginManager,
        dataOrchestrator: MultiProviderDataOrchestrator? = nil,
        refreshAction: (@Sendable () async -> Void)? = nil
    ) -> some View {
        self
            .settingsManager(settingsManager)
            .userSessionData(userSessionData)
            .loginManager(loginManager)
            .environment(\.dataOrchestrator, dataOrchestrator)
            .environment(\.refreshAction, refreshAction)
    }
}

// MARK: - Environment Dependency Requirements

/// Protocol for views that require environment dependencies
protocol EnvironmentDependent {
    /// Called when required environment dependencies are missing
    /// Allows views to handle missing dependencies gracefully
    func handleMissingDependencies()
}

/// View modifier that validates required environment dependencies
struct RequireEnvironmentDependencies: ViewModifier {
    let requiredDependencies: [KeyPath<EnvironmentValues, Any?>]
    let onMissing: () -> Void
    
    @Environment(\.self) private var environment
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                validateDependencies()
            }
    }
    
    private func validateDependencies() {
        for keyPath in requiredDependencies {
            if environment[keyPath: keyPath] == nil {
                onMissing()
                break
            }
        }
    }
}

extension View {
    /// Validates that required environment dependencies are present
    func requireEnvironment(
        _ dependencies: KeyPath<EnvironmentValues, Any?>...,
        onMissing: @escaping () -> Void = {
            assertionFailure("Required environment dependencies are missing")
        }
    ) -> some View {
        modifier(RequireEnvironmentDependencies(
            requiredDependencies: dependencies,
            onMissing: onMissing
        ))
    }
}

// MARK: - Safe Environment Access

/// Property wrapper for safely accessing optional environment values with fallback
@propertyWrapper
struct SafeEnvironment<Value> {
    private let keyPath: KeyPath<EnvironmentValues, Value?>
    private let fallback: Value
    @Environment(\.self) private var environment
    
    init(_ keyPath: KeyPath<EnvironmentValues, Value?>, fallback: Value) {
        self.keyPath = keyPath
        self.fallback = fallback
    }
    
    var wrappedValue: Value {
        environment[keyPath: keyPath] ?? fallback
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension EnvironmentValues {
    /// Debug helper to print all custom VibeMeter environment values
    func debugPrintVibeMeterEnvironment() {
        print("=== VibeMeter Environment Values ===")
        print("SettingsManager: \(settingsManager != nil ? "✓" : "✗")")
        print("UserSessionData: \(userSessionData != nil ? "✓" : "✗")")
        print("LoginManager: \(loginManager != nil ? "✓" : "✗")")
        print("DataOrchestrator: \(dataOrchestrator != nil ? "✓" : "✗")")
        print("RefreshAction: \(refreshAction != nil ? "✓" : "✗")")
        print("===================================")
    }
}
#endif