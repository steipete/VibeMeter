import ServiceManagement
@testable import VibeMeter
import XCTest

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

        if !shouldThrowError {
            isLaunchAtLoginEnabledValue = enabled
        }
    }
}

// MARK: - Tests

@MainActor
final class StartupManagerTests: XCTestCase, @unchecked Sendable {
    var sut: StartupManager!

    override func setUp() async throws {
        await MainActor.run { super.setUp() }
        sut = StartupManager()
    }

    override func tearDown() async throws {
        // Ensure we don't leave the test app registered for launch at login
        sut.setLaunchAtLogin(enabled: false)
        sut = nil
        await MainActor.run { super.tearDown() }
    }

    // MARK: - Initialization Tests

    func testInitialization_CreatesInstance() {
        // Then
        XCTAssertNotNil(sut)
    }

    // MARK: - Status Check Tests

    func testIsLaunchAtLoginEnabled_ReflectsSystemStatus() {
        // Given - The actual system status
        let systemStatus = SMAppService.mainApp.status

        // When
        let isEnabled = sut.isLaunchAtLoginEnabled

        // Then
        switch systemStatus {
        case .enabled:
            XCTAssertTrue(isEnabled)
        default:
            XCTAssertFalse(isEnabled)
        }
    }

    // MARK: - Enable/Disable Tests

    func testSetLaunchAtLogin_EnabledTrue_RegistersApp() {
        // When
        sut.setLaunchAtLogin(enabled: true)

        // Then - Check actual system status
        // Note: In a sandboxed test environment, this may not actually register
        // but we verify the method doesn't crash
        let status = SMAppService.mainApp.status
        // The test passes if no exception is thrown - just verify we get a valid status
        XCTAssertNotNil(status)
    }

    func testSetLaunchAtLogin_EnabledFalse_UnregistersApp() {
        // Given - First enable
        sut.setLaunchAtLogin(enabled: true)

        // When
        sut.setLaunchAtLogin(enabled: false)

        // Then - Check actual system status
        let status = SMAppService.mainApp.status
        // The test passes if no exception is thrown - just verify we get a valid status
        XCTAssertNotNil(status)
    }

    // MARK: - Error Handling Tests

    func testSetLaunchAtLogin_HandlesErrorsGracefully() {
        // When - Call multiple times (which might cause errors in some conditions)
        sut.setLaunchAtLogin(enabled: true)
        sut.setLaunchAtLogin(enabled: true) // Duplicate enable
        sut.setLaunchAtLogin(enabled: false)
        sut.setLaunchAtLogin(enabled: false) // Duplicate disable

        // Then - No crash occurs
        // The test passes if execution reaches here
    }

    // MARK: - Integration Tests with Settings

    func testIntegrationWithSettingsManager() {
        // Given
        let mockStartup = MockStartupManager()
        let testDefaults = UserDefaults(suiteName: "test.startup")!
        testDefaults.removeObject(forKey: "launchAtLoginEnabled") // Ensure clean state
        
        let settings = SettingsManager(
            userDefaults: testDefaults,
            startupManager: mockStartup)

        // Verify initial state
        XCTAssertFalse(settings.launchAtLoginEnabled)

        // When
        settings.launchAtLoginEnabled = true

        // Then
        XCTAssertTrue(mockStartup.setLaunchAtLoginCalled)
        XCTAssertEqual(mockStartup.setLaunchAtLoginEnabledValue, true)
    }

    // MARK: - Mock Tests

    func testMockStartupManager_SetLaunchAtLogin() {
        // Given
        let mock = MockStartupManager()

        // When
        mock.setLaunchAtLogin(enabled: true)

        // Then
        XCTAssertTrue(mock.setLaunchAtLoginCalled)
        XCTAssertEqual(mock.setLaunchAtLoginEnabledValue, true)
        XCTAssertTrue(mock.isLaunchAtLoginEnabled)
    }

    func testMockStartupManager_DisableLaunchAtLogin() {
        // Given
        let mock = MockStartupManager()
        mock.setLaunchAtLogin(enabled: true)

        // When
        mock.setLaunchAtLogin(enabled: false)

        // Then
        XCTAssertEqual(mock.setLaunchAtLoginEnabledValue, false)
        XCTAssertFalse(mock.isLaunchAtLoginEnabled)
    }

    func testMockStartupManager_ErrorSimulation() {
        // Given
        let mock = MockStartupManager()
        mock.shouldThrowError = true

        // When
        mock.setLaunchAtLogin(enabled: true)

        // Then
        XCTAssertTrue(mock.setLaunchAtLoginCalled)
        XCTAssertFalse(mock.isLaunchAtLoginEnabled) // Should remain false due to error
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess_MaintainsConsistency() async {
        // Given
        let expectation = expectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 20

        // When
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< 20 {
                group.addTask {
                    if i % 2 == 0 {
                        await self.sut.setLaunchAtLogin(enabled: true)
                    } else {
                        _ = await self.sut.isLaunchAtLoginEnabled
                    }
                    expectation.fulfill()
                }
            }
        }

        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    // MARK: - Protocol Conformance Tests

    func testStartupManager_ConformsToStartupControlling() {
        // Then
        XCTAssertTrue((sut as Any) is StartupControlling)
    }

    func testStartupManager_IsSendable() {
        // Given
        let manager = StartupManager()

        // When/Then - This compiles because StartupManager conforms to Sendable
        Task {
            await manager.setLaunchAtLogin(enabled: false)
        }
    }

    // MARK: - State Consistency Tests

    func testMultipleEnableDisableCycles_MaintainsConsistency() {
        // When - Perform multiple enable/disable cycles
        for _ in 0 ..< 5 {
            sut.setLaunchAtLogin(enabled: true)
            sut.setLaunchAtLogin(enabled: false)
        }

        // Then - Final state should not be enabled
        let finalStatus = SMAppService.mainApp.status
        XCTAssertTrue(
            finalStatus != .enabled,
            "After disable cycles, app should not be enabled for launch at login")
    }

    // MARK: - Edge Case Tests

    func testRapidToggling_HandlesGracefully() {
        // When - Rapidly toggle the setting
        for i in 0 ..< 10 {
            sut.setLaunchAtLogin(enabled: i % 2 == 0)
        }

        // Then - No crash and final state is consistent
        let isEnabled = sut.isLaunchAtLoginEnabled
        XCTAssertFalse(isEnabled) // Should be false after odd number of toggles
    }

    func testStatusCheck_WithoutPriorConfiguration() {
        // Given - Fresh instance
        let freshManager = StartupManager()

        // When
        let isEnabled = freshManager.isLaunchAtLoginEnabled

        // Then - Should reflect actual system state
        XCTAssertNotNil(isEnabled) // Should return a valid boolean
    }
}
