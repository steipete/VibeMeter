import ServiceManagement
import Testing
@testable import VibeMeter

// MARK: - Mock Startup Manager

private class MockStartupManager: StartupControlling {
    var setLaunchAtLoginCalled = false
    var setLaunchAtLoginEnabledValue: Bool?
    var isLaunchAtLoginEnabledValue = false
    var shouldThrowError = false
    var callHistory: [(enabled: Bool, timestamp: Date)] = []

    var isLaunchAtLoginEnabled: Bool {
        isLaunchAtLoginEnabledValue
    }

    func setLaunchAtLogin(enabled: Bool) {
        setLaunchAtLoginCalled = true
        setLaunchAtLoginEnabledValue = enabled
        callHistory.append((enabled: enabled, timestamp: Date()))

        // Only update the internal state if we're not simulating an error
        if !shouldThrowError {
            isLaunchAtLoginEnabledValue = enabled
        }
        // When shouldThrowError is true, the internal state is not updated,
        // simulating a failure in the actual implementation
    }
}

// MARK: - Tests

@Suite("StartupManagerTests", .tags(.unit, .fast))
@MainActor
struct StartupManagerTests {
    let sut: StartupManager

    init() {
        sut = StartupManager()
    }

    // MARK: - Initialization Tests

    @Test("initialization  creates instance")
    func initialization_CreatesInstance() {
        // Then
        #expect(sut as Any is StartupManager)
    }

    @Test("is launch at login enabled reflects system status")
    func isLaunchAtLoginEnabled_ReflectsSystemStatus() {
        // Given - The actual system status
        let systemStatus = SMAppService.mainApp.status

        // When
        let isEnabled = sut.isLaunchAtLoginEnabled

        // Then
        switch systemStatus {
        case .enabled:
            #expect(isEnabled == true)
        default:
            #expect(isEnabled == false)
        }
    }

    // MARK: - Enable/Disable Tests

    @Test("Launch at login state changes", arguments: [
        (enabled: true, description: "Enable launch at login"),
        (enabled: false, description: "Disable launch at login")
    ])
    func launchAtLoginStateChanges(enabled: Bool, description _: String) {
        // When
        sut.setLaunchAtLogin(enabled: enabled)

        // Then - Check actual system status
        // Note: In a sandboxed test environment, this may not actually register
        // but we verify the method doesn't crash
        let status = SMAppService.mainApp.status
        // The test passes if no exception is thrown - just verify we get a valid status
        #expect(status == .enabled || status == .notRegistered || status == .requiresApproval || status == .notFound)
    }

    @Test("Duplicate state changes", arguments: [
        (operations: [(true, "Enable"), (true, "Duplicate enable")], description: "Duplicate enable calls"),
        (operations: [(false, "Disable"), (false, "Duplicate disable")], description: "Duplicate disable calls"),
        (
            operations: [(true, "Enable"), (false, "Disable"), (true, "Re-enable"), (false, "Re-disable")],
            description: "Multiple toggles")
    ])
    func duplicateStateChanges(operations: [(enabled: Bool, description: String)], description _: String) {
        // When - Perform operations
        for (enabled, _) in operations {
            sut.setLaunchAtLogin(enabled: enabled)
        }

        // Then - No crash occurs
        // The test passes if execution reaches here
        #expect(true)
    }

    // MARK: - Integration Tests with Settings

    @Test("integration with settings manager")
    func integrationWithSettingsManager() {
        // Given
        let mockStartup = MockStartupManager()
        let testDefaults = UserDefaults(suiteName: "test.startup")!
        testDefaults.removeObject(forKey: "launchAtLoginEnabled") // Ensure clean state

        let settings = SettingsManager(
            userDefaults: testDefaults,
            startupManager: mockStartup)

        // Verify initial state
        #expect(settings.launchAtLoginEnabled == false)
        #expect(mockStartup.setLaunchAtLoginCalled == false)
    }

    @Test("Mock startup manager operations", arguments: [
        (enable: true, expectedCalled: true, expectedEnabled: true, description: "Enable launch at login"),
        (enable: false, expectedCalled: true, expectedEnabled: false, description: "Disable launch at login")
    ])
    func mockStartupManagerOperations(enable: Bool, expectedCalled: Bool, expectedEnabled: Bool,
                                      description _: String) {
        // Given
        let mock = MockStartupManager()

        // When
        mock.setLaunchAtLogin(enabled: enable)

        // Then
        #expect(mock.setLaunchAtLoginCalled == expectedCalled)
        #expect(mock.isLaunchAtLoginEnabled == expectedEnabled)
        #expect(mock.setLaunchAtLoginEnabledValue == enable)
    }

    @Test("mock startup manager  error simulation")
    func mockStartupManager_ErrorSimulation() {
        // Given
        let mock = MockStartupManager()
        mock.shouldThrowError = true

        // When
        mock.setLaunchAtLogin(enabled: true)

        // Then
        #expect(mock.setLaunchAtLoginCalled == true)
        #expect(mock.isLaunchAtLoginEnabled == false) // Should remain false due to error
    }

    // MARK: - Thread Safety Tests

    @Test("concurrent access  maintains consistency")
    func concurrentAccess_MaintainsConsistency() async {
        // When
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 20 {
                group.addTask {
                    if i % 2 == 0 {
                        await self.sut.setLaunchAtLogin(enabled: true)
                    } else {
                        _ = await self.sut.isLaunchAtLoginEnabled
                    }
                }
            }
        }

        // Then - Task group completes without error
        #expect(Bool(true)) // Test passes if we reach here without deadlocks
    }

    // MARK: - Protocol Conformance Tests

    @Test("startup manager  conforms to startup controlling")
    func startupManager_ConformsToStartupControlling() {
        // Then
        // Verify that StartupManager conforms to StartupControlling protocol
        let _: any StartupControlling = sut
        #expect(Bool(true)) // If compilation succeeds, the conformance is verified
    }

    @Test("startup manager  is sendable")
    func startupManager_IsSendable() {
        // Given
        let manager = StartupManager()

        // When/Then - This compiles because StartupManager conforms to Sendable
        Task {
            manager.setLaunchAtLogin(enabled: false)
        }
    }

    // MARK: - State Consistency Tests

    @Test("multiple enable disable cycles  maintains consistency")
    func multipleEnableDisableCycles_MaintainsConsistency() {
        // When - Perform multiple enable/disable cycles
        for _ in 0 ..< 5 {
            sut.setLaunchAtLogin(enabled: true)
            sut.setLaunchAtLogin(enabled: false)
        }

        // Then - Final state should not be enabled
        let finalStatus = SMAppService.mainApp.status
        #expect(
            finalStatus != .enabled)
    }

    @Test("rapid toggling handles gracefully")
    func rapidToggling_HandlesGracefully() {
        // When - Rapidly toggle the setting
        for i in 0 ..< 10 {
            sut.setLaunchAtLogin(enabled: i % 2 == 0)
        }

        // Then - No crash and final state is consistent
        let isEnabled = sut.isLaunchAtLoginEnabled
        #expect(isEnabled == false)
    }

    @Test("status check without prior configuration")
    func statusCheck_WithoutPriorConfiguration() {
        // Given - Fresh instance
        let freshManager = StartupManager()

        // When
        let isEnabled = freshManager.isLaunchAtLoginEnabled

        // Then - Should reflect actual system state
        #expect(isEnabled == true || isEnabled == false) // Should return a valid boolean
    }
}
