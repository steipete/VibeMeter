@testable import VibeMeter // Assuming your module is named VibeMeter
import XCTest

@MainActor
class SettingsManagerTests: XCTestCase, @unchecked Sendable {
    var settingsManager: SettingsManager! // This will now be the .shared instance, reconfigured for tests
    var testUserDefaults: UserDefaults!

    // Unique suite name for UserDefaults to avoid interference between tests and with the actual app
    let testSuiteName = "com.vibemeter.tests.SettingsManagerTests"

    override func setUp() {
        super.setUp()
        // Use a specific UserDefaults suite for testing - this is OK since UserDefaults is Sendable
        let suite = UserDefaults(suiteName: testSuiteName)
        suite?.removePersistentDomain(forName: testSuiteName) // Clear before each test

        MainActor.assumeIsolated {
            // Set the properties and configure manager on MainActor
            testUserDefaults = suite
            // Configure the SettingsManager.shared instance to use our test UserDefaults
            SettingsManager._test_setSharedInstance(userDefaults: testUserDefaults)
            settingsManager = SettingsManager.shared // Work with the shared instance that is now using testUserDefaults
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
        // The refactored init in SettingsManager ensures that if the key is not present (integer(forKey:) returns 0),
        // it defaults to 5. If the key is present and is 0, it would use 0, but our UI doesn't allow setting 0.
        XCTAssertEqual(settingsManager.refreshIntervalMinutes, 5, "Default refresh interval should be 5 minutes")
    }

    func testDefaultLaunchAtLogin() {
        XCTAssertFalse(settingsManager.launchAtLoginEnabled, "Default launch at login should be false")
    }

    func testSettingSelectedCurrency() {
        let newCurrency = "EUR"
        settingsManager.selectedCurrencyCode = newCurrency
        XCTAssertEqual(settingsManager.selectedCurrencyCode, newCurrency, "Selected currency should be updated")
        XCTAssertEqual(
            testUserDefaults.string(forKey: SettingsManager.Keys.selectedCurrencyCode),
            newCurrency,
            "UserDefaults should reflect the new currency"
        )
    }

    func testSettingWarningLimitUSD() {
        let newLimit = 150.5
        settingsManager.warningLimitUSD = newLimit
        XCTAssertEqual(settingsManager.warningLimitUSD, newLimit, "Warning limit USD should be updated")
        XCTAssertEqual(
            testUserDefaults.double(forKey: SettingsManager.Keys.warningLimitUSD),
            newLimit,
            "UserDefaults should reflect the new warning limit"
        )
    }

    func testSettingUpperLimitUSD() {
        let newLimit = 800.75
        settingsManager.upperLimitUSD = newLimit
        XCTAssertEqual(settingsManager.upperLimitUSD, newLimit, "Upper limit USD should be updated")
        XCTAssertEqual(
            testUserDefaults.double(forKey: SettingsManager.Keys.upperLimitUSD),
            newLimit,
            "UserDefaults should reflect the new upper limit"
        )
    }

    func testSettingRefreshInterval() {
        let newInterval = 30
        settingsManager.refreshIntervalMinutes = newInterval
        XCTAssertEqual(settingsManager.refreshIntervalMinutes, newInterval, "Refresh interval should be updated")
        XCTAssertEqual(
            testUserDefaults.integer(forKey: SettingsManager.Keys.refreshIntervalMinutes),
            newInterval,
            "UserDefaults should reflect the new refresh interval"
        )
    }

    func testSettingLaunchAtLogin() {
        // This test assumes StartupManager.setLaunchAtLogin is mocked or its side effects are acceptable in test.
        // For true unit testing, StartupManager interactions would be protocol-based and mocked.
        // For now, we acknowledge this might call the actual StartupManager.
        settingsManager.launchAtLoginEnabled = true
        XCTAssertTrue(settingsManager.launchAtLoginEnabled, "Launch at login should be updated to true")
        XCTAssertTrue(
            testUserDefaults.bool(forKey: SettingsManager.Keys.launchAtLoginEnabled),
            "UserDefaults should reflect launch at login true"
        )

        settingsManager.launchAtLoginEnabled = false
        XCTAssertFalse(settingsManager.launchAtLoginEnabled, "Launch at login should be updated to false")
        XCTAssertFalse(
            testUserDefaults.bool(forKey: SettingsManager.Keys.launchAtLoginEnabled),
            "UserDefaults should reflect launch at login false"
        )
    }

    func testTeamIdStorage() {
        let testTeamId = 12345
        settingsManager.teamId = testTeamId
        XCTAssertEqual(settingsManager.teamId, testTeamId, "Team ID should be stored and retrieved correctly")
        XCTAssertEqual(
            testUserDefaults.integer(forKey: SettingsManager.Keys.teamId),
            testTeamId,
            "UserDefaults should reflect the stored team ID"
        )

        settingsManager.teamId = nil
        XCTAssertNil(settingsManager.teamId, "Team ID should be nillable")
        XCTAssertNil(
            testUserDefaults.object(forKey: SettingsManager.Keys.teamId),
            "UserDefaults should have removed the team ID key"
        )
    }

    func testTeamIdIsNilWhenNotSet() {
        // Ensure that a fresh SettingsManager (with cleared UserDefaults) reports nil for teamId
        let freshManager = SettingsManager(userDefaults: testUserDefaults) // testUserDefaults is empty here
        XCTAssertNil(freshManager.teamId, "Team ID should be nil if not set in UserDefaults.")
    }

    func testTeamNameStorage() {
        let testTeamName = "Vibing Crew"
        settingsManager.teamName = testTeamName
        XCTAssertEqual(settingsManager.teamName, testTeamName, "Team name should be stored and retrieved correctly")
        XCTAssertEqual(
            testUserDefaults.string(forKey: SettingsManager.Keys.teamName),
            testTeamName,
            "UserDefaults should reflect the stored team name"
        )

        settingsManager.teamName = nil
        XCTAssertNil(settingsManager.teamName, "Team name should be nillable")
        XCTAssertNil(
            testUserDefaults.string(forKey: SettingsManager.Keys.teamName),
            "UserDefaults should reflect nil team name"
        )
    }

    func testUserEmailStorage() {
        let testUserEmail = "test@example.com"
        settingsManager.userEmail = testUserEmail
        XCTAssertEqual(settingsManager.userEmail, testUserEmail, "User email should be stored and retrieved correctly")
        XCTAssertEqual(
            testUserDefaults.string(forKey: SettingsManager.Keys.userEmail),
            testUserEmail,
            "UserDefaults should reflect the stored user email"
        )

        settingsManager.userEmail = nil
        XCTAssertNil(settingsManager.userEmail, "User email should be nillable")
        XCTAssertNil(
            testUserDefaults.string(forKey: SettingsManager.Keys.userEmail),
            "UserDefaults should reflect nil user email"
        )
    }

    func testClearUserSessionData() {
        settingsManager.teamId = 999
        settingsManager.teamName = "Temporary Team"
        settingsManager.userEmail = "temp@example.com"

        // Verify they are set before clearing
        XCTAssertNotNil(testUserDefaults.object(forKey: SettingsManager.Keys.teamId))
        XCTAssertNotNil(testUserDefaults.object(forKey: SettingsManager.Keys.teamName))
        XCTAssertNotNil(testUserDefaults.object(forKey: SettingsManager.Keys.userEmail))

        settingsManager.clearUserSessionData()

        XCTAssertNil(settingsManager.teamId, "Team ID should be cleared")
        XCTAssertNil(settingsManager.teamName, "Team name should be cleared")
        XCTAssertNil(settingsManager.userEmail, "User email should be cleared")

        XCTAssertNil(
            testUserDefaults.object(forKey: SettingsManager.Keys.teamId),
            "Team ID should be removed from UserDefaults"
        )
        XCTAssertNil(
            testUserDefaults.string(forKey: SettingsManager.Keys.teamName),
            "Team name should be removed from UserDefaults"
        )
        XCTAssertNil(
            testUserDefaults.string(forKey: SettingsManager.Keys.userEmail),
            "User email should be removed from UserDefaults"
        )
    }

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
        existingUserDefaults.set(5678, forKey: SettingsManager.Keys.teamId)
        existingUserDefaults.set("Test Team", forKey: SettingsManager.Keys.teamName)
        existingUserDefaults.set("existing@example.com", forKey: SettingsManager.Keys.userEmail)

        // Copy the existing user defaults to avoid data race
        let copiedDefaults = UserDefaults(suiteName: existingSuiteName)!
        // Initialize SettingsManager with these pre-populated UserDefaults
        let managerWithExistingValues = SettingsManager(userDefaults: copiedDefaults)

        XCTAssertEqual(managerWithExistingValues.selectedCurrencyCode, "EUR")
        XCTAssertEqual(managerWithExistingValues.warningLimitUSD, 150.0)
        XCTAssertEqual(managerWithExistingValues.upperLimitUSD, 750.0)
        XCTAssertEqual(managerWithExistingValues.refreshIntervalMinutes, 15)
        XCTAssertTrue(managerWithExistingValues.launchAtLoginEnabled)
        XCTAssertEqual(managerWithExistingValues.teamId, 5678)
        XCTAssertEqual(managerWithExistingValues.teamName, "Test Team")
        XCTAssertEqual(managerWithExistingValues.userEmail, "existing@example.com")

        existingUserDefaults.removePersistentDomain(forName: existingSuiteName)
    }
}
