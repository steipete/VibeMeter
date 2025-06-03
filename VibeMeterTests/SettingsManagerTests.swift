@testable import VibeMeter
import XCTest

@MainActor
class SettingsManagerTests: XCTestCase, @unchecked Sendable {
    var settingsManager: SettingsManager!
    var testUserDefaults: UserDefaults!

    // Unique suite name for UserDefaults to avoid interference between tests and with the actual app
    let testSuiteName = "com.vibemeter.tests.SettingsManagerTests"

    override func setUp() {
        super.setUp()
        
        MainActor.assumeIsolated {
            // Clear any existing shared instance first
            SettingsManager._test_clearSharedInstance()
            
            // Use a specific UserDefaults suite for testing
            let suite = UserDefaults(suiteName: testSuiteName)
            suite?.removePersistentDomain(forName: testSuiteName)
            
            // Ensure we start fresh by clearing the suite entirely
            if let suite = suite {
                for key in Array(suite.dictionaryRepresentation().keys) {
                    suite.removeObject(forKey: key)
                }
            }
            
            testUserDefaults = suite
            // Configure the SettingsManager.shared instance to use our test UserDefaults
            SettingsManager._test_setSharedInstance(userDefaults: testUserDefaults, startupManager: StartupManagerMock())
            settingsManager = SettingsManager.shared
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            testUserDefaults = nil
            settingsManager = nil
            // Reset SettingsManager.shared to its default state after tests
            SettingsManager._test_clearSharedInstance()
        }
        super.tearDown()
    }

    // MARK: - Default Values Tests

    func testDefaultCurrencyIsUSD() {
        XCTAssertEqual(settingsManager.selectedCurrencyCode, "USD", "Default currency should be USD")
    }

    func testDefaultWarningLimit() {
        XCTAssertEqual(settingsManager.warningLimitUSD, 200.0, "Default warning limit USD should be 200.0")
    }

    func testDefaultUpperLimit() {
        XCTAssertEqual(settingsManager.upperLimitUSD, 1000.0, "Default upper limit USD should be 1000.0")
    }

    func testDefaultRefreshInterval() {
        XCTAssertEqual(settingsManager.refreshIntervalMinutes, 5, "Default refresh interval should be 5 minutes")
    }

    func testDefaultLaunchAtLogin() {
        XCTAssertFalse(settingsManager.launchAtLoginEnabled, "Default launch at login should be false")
    }

    func testDefaultShowCostInMenuBar() {
        XCTAssertTrue(settingsManager.showCostInMenuBar, "Default show cost in menu bar should be true")
    }

    func testDefaultShowInDock() {
        XCTAssertFalse(settingsManager.showInDock, "Default show in dock should be false")
    }

    func testDefaultEnabledProviders() {
        XCTAssertEqual(settingsManager.enabledProviders, [.cursor], "Default enabled providers should be [.cursor]")
    }

    // MARK: - Property Setting Tests

    func testSettingSelectedCurrency() {
        let newCurrency = "EUR"
        settingsManager.selectedCurrencyCode = newCurrency
        XCTAssertEqual(settingsManager.selectedCurrencyCode, newCurrency, "Selected currency should be updated")
    }

    func testSettingWarningLimitUSD() {
        let newLimit = 150.5
        settingsManager.warningLimitUSD = newLimit
        XCTAssertEqual(settingsManager.warningLimitUSD, newLimit, "Warning limit USD should be updated")
    }

    func testSettingUpperLimitUSD() {
        let newLimit = 800.75
        settingsManager.upperLimitUSD = newLimit
        XCTAssertEqual(settingsManager.upperLimitUSD, newLimit, "Upper limit USD should be updated")
    }

    func testSettingRefreshInterval() {
        let newInterval = 30
        settingsManager.refreshIntervalMinutes = newInterval
        XCTAssertEqual(settingsManager.refreshIntervalMinutes, newInterval, "Refresh interval should be updated")
    }

    func testSettingLaunchAtLogin() {
        settingsManager.launchAtLoginEnabled = true
        XCTAssertTrue(settingsManager.launchAtLoginEnabled, "Launch at login should be updated to true")

        settingsManager.launchAtLoginEnabled = false
        XCTAssertFalse(settingsManager.launchAtLoginEnabled, "Launch at login should be updated to false")
    }

    func testSettingShowCostInMenuBar() {
        settingsManager.showCostInMenuBar = false
        XCTAssertFalse(settingsManager.showCostInMenuBar, "Show cost in menu bar should be updated to false")

        settingsManager.showCostInMenuBar = true
        XCTAssertTrue(settingsManager.showCostInMenuBar, "Show cost in menu bar should be updated to true")
    }

    func testSettingShowInDock() {
        settingsManager.showInDock = true
        XCTAssertTrue(settingsManager.showInDock, "Show in dock should be updated to true")

        settingsManager.showInDock = false
        XCTAssertFalse(settingsManager.showInDock, "Show in dock should be updated to false")
    }

    func testSettingEnabledProviders() {
        let newProviders: Set<ServiceProvider> = []
        settingsManager.enabledProviders = newProviders
        XCTAssertEqual(settingsManager.enabledProviders, newProviders, "Enabled providers should be updated")

        let allProviders = Set(ServiceProvider.allCases)
        settingsManager.enabledProviders = allProviders
        XCTAssertEqual(settingsManager.enabledProviders, allProviders, "Enabled providers should include all providers")
    }

    // MARK: - Provider Session Management Tests

    func testProviderSessionStorage() {
        let session = ProviderSession(
            provider: .cursor,
            teamId: 12345,
            teamName: "Test Team",
            userEmail: "test@example.com",
            isActive: true)

        settingsManager.updateSession(for: .cursor, session: session)

        let retrievedSession = settingsManager.getSession(for: .cursor)
        XCTAssertNotNil(retrievedSession, "Should retrieve stored session")
        XCTAssertEqual(retrievedSession?.provider, .cursor)
        XCTAssertEqual(retrievedSession?.teamId, 12345)
        XCTAssertEqual(retrievedSession?.teamName, "Test Team")
        XCTAssertEqual(retrievedSession?.userEmail, "test@example.com")
        XCTAssertTrue(retrievedSession?.isActive ?? false)
    }

    func testProviderSessionOverwrite() {
        let session1 = ProviderSession(
            provider: .cursor,
            teamId: 111,
            teamName: "Team 1",
            userEmail: "user1@example.com",
            isActive: true)

        let session2 = ProviderSession(
            provider: .cursor,
            teamId: 222,
            teamName: "Team 2",
            userEmail: "user2@example.com",
            isActive: false)

        settingsManager.updateSession(for: .cursor, session: session1)
        settingsManager.updateSession(for: .cursor, session: session2)

        let retrievedSession = settingsManager.getSession(for: .cursor)
        XCTAssertEqual(retrievedSession?.teamId, 222)
        XCTAssertEqual(retrievedSession?.teamName, "Team 2")
        XCTAssertEqual(retrievedSession?.userEmail, "user2@example.com")
        XCTAssertFalse(retrievedSession?.isActive ?? true)
    }

    func testGetSessionForNonExistentProvider() {
        let retrievedSession = settingsManager.getSession(for: .cursor)
        XCTAssertNil(retrievedSession, "Should return nil for non-existent session")
    }

    // MARK: - Session Clearing Tests

    func testClearUserSessionData() {
        // Set up multiple provider sessions
        let cursorSession = ProviderSession(
            provider: .cursor,
            teamId: 123,
            teamName: "Cursor Team",
            userEmail: "cursor@example.com",
            isActive: true)

        settingsManager.updateSession(for: .cursor, session: cursorSession)

        // Verify sessions are set
        XCTAssertNotNil(settingsManager.getSession(for: .cursor))

        // Clear all sessions
        settingsManager.clearUserSessionData()

        // Verify all sessions are cleared
        XCTAssertNil(settingsManager.getSession(for: .cursor))
    }

    func testClearUserSessionDataForSpecificProvider() {
        // Set up session for cursor
        let cursorSession = ProviderSession(
            provider: .cursor,
            teamId: 123,
            teamName: "Cursor Team",
            userEmail: "cursor@example.com",
            isActive: true)

        settingsManager.updateSession(for: .cursor, session: cursorSession)

        // Verify session is set
        XCTAssertNotNil(settingsManager.getSession(for: .cursor))

        // Clear only cursor session
        settingsManager.clearUserSessionData(for: .cursor)

        // Verify cursor session is cleared
        XCTAssertNil(settingsManager.getSession(for: .cursor))
    }

    // MARK: - Refresh Interval Options Tests

    func testRefreshIntervalOptions() {
        let expectedOptions = [1, 2, 5, 10, 15, 30, 60]
        XCTAssertEqual(
            SettingsManager.refreshIntervalOptions,
            expectedOptions,
            "Refresh interval options should match expected values")
    }

    func testRefreshIntervalValidation() {
        // Test that all valid options can be set
        for option in SettingsManager.refreshIntervalOptions {
            settingsManager.refreshIntervalMinutes = option
            XCTAssertEqual(
                settingsManager.refreshIntervalMinutes,
                option,
                "Should be able to set valid refresh interval: \(option)")
        }
    }

    // MARK: - Initialization Tests

    func testInitializationWithExistingValuesInUserDefaults() {
        // Pre-populate UserDefaults
        let existingSuiteName = "com.vibemeter.tests.ExistingValues"
        let existingUserDefaults = UserDefaults(suiteName: existingSuiteName)!
        existingUserDefaults.removePersistentDomain(forName: existingSuiteName)

        existingUserDefaults.set("EUR", forKey: SettingsManager.Keys.selectedCurrencyCode)
        existingUserDefaults.set(150.0, forKey: SettingsManager.Keys.warningLimitUSD)
        existingUserDefaults.set(750.0, forKey: SettingsManager.Keys.upperLimitUSD)
        existingUserDefaults.set(15, forKey: SettingsManager.Keys.refreshIntervalMinutes)
        existingUserDefaults.set(true, forKey: SettingsManager.Keys.launchAtLoginEnabled)
        existingUserDefaults.set(false, forKey: SettingsManager.Keys.showCostInMenuBar)
        existingUserDefaults.set(true, forKey: SettingsManager.Keys.showInDock)

        // Initialize SettingsManager with these pre-populated UserDefaults
        let mockStartupManager = StartupManagerMock()
        let managerWithExistingValues = SettingsManager(
            userDefaults: existingUserDefaults,
            startupManager: mockStartupManager)

        XCTAssertEqual(managerWithExistingValues.selectedCurrencyCode, "EUR")
        XCTAssertEqual(managerWithExistingValues.warningLimitUSD, 150.0)
        XCTAssertEqual(managerWithExistingValues.upperLimitUSD, 750.0)
        XCTAssertEqual(managerWithExistingValues.refreshIntervalMinutes, 15)
        XCTAssertTrue(managerWithExistingValues.launchAtLoginEnabled)
        XCTAssertFalse(managerWithExistingValues.showCostInMenuBar)
        XCTAssertTrue(managerWithExistingValues.showInDock)

        existingUserDefaults.removePersistentDomain(forName: existingSuiteName)
    }
}
