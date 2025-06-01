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
    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.example.VibeMeter" // Fallback

    // No public init for singleton unless through `shared`
    fileprivate init() {}

    func setLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
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
                    error: error
                )
            }
        } else {
            if SMLoginItemSetEnabled(bundleIdentifier as CFString, enabled) {
                LoggingService.info(
                    "SMLoginItemSetEnabled to \(enabled) succeeded for \(bundleIdentifier)",
                    category: .startup
                )
            } else {
                LoggingService.error(
                    "SMLoginItemSetEnabled to \(enabled) failed for \(bundleIdentifier)",
                    category: .startup
                )
            }
        }
    }

    var isLaunchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // This still relies on SettingsManager.shared, which is a slight coupling.
            // For pure StartupManager unit tests, this could be problematic.
            // However, in the context of the app, this might be an acceptable way to sync state for older OS.
            LoggingService.info(
                "isLaunchAtLoginEnabled check on pre-macOS 13.0 relies on SettingsManager.shared.launchAtLoginEnabled.",
                category: .startup
            )
            return SettingsManager.shared.launchAtLoginEnabled
        }
    }
}
