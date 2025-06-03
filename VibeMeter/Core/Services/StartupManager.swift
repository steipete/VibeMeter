import Foundation
import ServiceManagement

// Define a protocol that the StartupManager and its mock will conform to.
@MainActor
protocol StartupManagerProtocol {
    func setLaunchAtLogin(enabled: Bool)
    var isLaunchAtLoginEnabled: Bool { get }
    // Add other methods/properties if any
}

@MainActor
enum StartupManager {
    // Allow shared instance to be replaced for testing
    static var shared: StartupManagerProtocol = RealStartupManager()

    // Test-only method to inject a mock shared instance
    static func _test_setSharedInstance(instance: StartupManagerProtocol) {
        shared = instance
    }

    // Test-only method to reset to the real shared instance
    static func _test_resetSharedInstance() {
        shared = RealStartupManager()
    }
}

// The actual implementation
@MainActor
class RealStartupManager: StartupManagerProtocol {
    // No public init for singleton unless through `shared`
    fileprivate init() {}

    func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                LoggingService.info("Successfully registered for launch at login.", category: .startup)
            } else {
                try SMAppService.mainApp.unregister()
                LoggingService.info("Successfully unregistered for launch at login.", category: .startup)
            }
        } catch {
            LoggingService.error(
                "Failed to \(enabled ? "register" : "unregister") for launch at login",
                category: .startup,
                error: error)
        }
    }

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
