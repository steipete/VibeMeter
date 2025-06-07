import Foundation
@testable import VibeMeter

// StartupControlling is defined in VibeMeter/StartupManager.swift

@MainActor
class StartupManagerMock: StartupControlling {
    var setLaunchAtLoginCalledWith: Bool?
    var launchAtLoginEnabledValue: Bool = false
    var shouldThrowError: Bool = false

    init() {}

    func setLaunchAtLogin(enabled: Bool) {
        setLaunchAtLoginCalledWith = enabled
        if !shouldThrowError {
            launchAtLoginEnabledValue = enabled
        }
        LoggingService.debug("[StartupManagerMock] setLaunchAtLogin called with: \(enabled)", category: .general)
    }

    var isLaunchAtLoginEnabled: Bool {
        LoggingService.debug(
            "[StartupManagerMock] isLaunchAtLoginEnabled returning: \(launchAtLoginEnabledValue)",
            category: .general)
        return launchAtLoginEnabledValue
    }

    func reset() {
        setLaunchAtLoginCalledWith = nil
        launchAtLoginEnabledValue = false
    }
}
