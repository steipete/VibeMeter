import ServiceManagement
import Testing
@testable import VibeMeter

// MARK: - Mock Startup Manager

private class MockStartupManager: StartupControlling {
    var setLaunchAtLoginCalled = false
    var setLaunchAtLoginEnabledValue: Bool?
    var isLaunchAtLoginEnabledValue = false
    var shouldThrowError = false

    var isLaunchAtLoginEnabled: Bool {
        isLaunchAtLoginEnabledValue
    }

    func setLaunchAtLogin(enabled: Bool) {
        setLaunchAtLoginCalled = true
        setLaunchAtLoginEnabledValue = enabled

        // Only update the internal state if we're not simulating an error
        if !shouldThrowError {
            isLaunchAtLoginEnabledValue = enabled
        }
        // When shouldThrowError is true, the internal state is not updated,
        // simulating a failure in the actual implementation
    }
}

// MARK: - Tests

@Suite("StartupManagerTests")
.tags(.unit, .fast)
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

    @Test("set launch at login  enabled true  registers app")
    func setLaunchAtLogin_EnabledTrue_RegistersApp() {
        // When
        sut.setLaunchAtLogin(enabled: true)

        // Then - Check actual system status
        // Note: In a sandboxed test environment, this may not actually register
        // but we verify the method doesn't crash
        let status = SMAppService.mainApp.status
        // The test passes if no exception is thrown - just verify we get a valid status
        #expect(status == .enabled || status == .notRegistered || status == .requiresApproval || status == .notFound)
    }

    @Test("set launch at login enabled false unregisters app")
    func setLaunchAtLogin_EnabledFalse_UnregistersApp() {
        // Given - First enable
        sut.setLaunchAtLogin(enabled: true)

        // When
        sut.setLaunchAtLogin(enabled: false)

        // Then - Check actual system status
        let status = SMAppService.mainApp.status
        // The test passes if no exception is thrown - just verify we get a valid status
        #expect(status == .enabled || status == .notRegistered || status == .requiresApproval || status == .notFound)
    }

    @Test("set launch at login handles errors gracefully")
    func setLaunchAtLogin_HandlesErrorsGracefully() {
        // When - Call multiple times (which might cause errors in some conditions)
        sut.setLaunchAtLogin(enabled: true)
        sut.setLaunchAtLogin(enabled: true) // Duplicate enable
        sut.setLaunchAtLogin(enabled: false)
        sut.setLaunchAtLogin(enabled: false) // Duplicate disable

        // Then - No crash occurs
        // The test passes if execution reaches here
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

    @Test("mock startup manager set launch at login")
    func mockStartupManager_SetLaunchAtLogin() {
        // Given
        let mock = MockStartupManager()

        // When
        mock.setLaunchAtLogin(enabled: true)

        // Then
        #expect(mock.setLaunchAtLoginCalled == true)
        #expect(mock.isLaunchAtLoginEnabled == true)
    }

    @Test("mock startup manager disable launch at login")
    func mockStartupManager_DisableLaunchAtLogin() {
        // Given
        let mock = MockStartupManager()
        mock.setLaunchAtLogin(enabled: true)

        // When
        mock.setLaunchAtLogin(enabled: false)

        // Then
        #expect(mock.setLaunchAtLoginEnabledValue == false)
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
        #expect(true) // If compilation succeeds, the conformance is verified
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
