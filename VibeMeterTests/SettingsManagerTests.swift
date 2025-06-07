import Foundation
import Testing
@testable import VibeMeter

@Suite("SettingsManager Tests", .tags(.settings, .unit, .fast))
@MainActor
struct SettingsManagerTests {
    let settingsManager: SettingsManager
    let testUserDefaults: UserDefaults

    init() {
        // Unique suite name for UserDefaults to avoid interference between tests and with the actual app
        let testSuiteName = "com.vibemeter.tests.SettingsManagerTests"
        let suite = UserDefaults(suiteName: testSuiteName)!

        // Clean up any existing test data
        suite.removePersistentDomain(forName: testSuiteName)

        self.testUserDefaults = suite
        // Configure the SettingsManager.shared instance to use our test UserDefaults
        SettingsManager._test_setSharedInstance(
            userDefaults: testUserDefaults,
            startupManager: StartupManagerMock())
        self.settingsManager = SettingsManager.shared
    }

    // MARK: - Default Values Tests

    struct DefaultValueTestCase: @unchecked Sendable {
        let name: String
        let getValue: @MainActor (SettingsManager) -> Any
        let expectedValue: Any
        let compare: (Any, Any) -> Bool
    }

    @Test("Default values", arguments: [
        DefaultValueTestCase(
            name: "Currency",
            getValue: { $0.selectedCurrencyCode },
            expectedValue: "USD",
            compare: { ($0 as? String) == ($1 as? String) }),
        DefaultValueTestCase(
            name: "Warning limit",
            getValue: { $0.warningLimitUSD },
            expectedValue: 200.0,
            compare: { ($0 as? Double) == ($1 as? Double) }),
        DefaultValueTestCase(
            name: "Upper limit",
            getValue: { $0.upperLimitUSD },
            expectedValue: 1000.0,
            compare: { ($0 as? Double) == ($1 as? Double) }),
        DefaultValueTestCase(
            name: "Refresh interval",
            getValue: { $0.refreshIntervalMinutes },
            expectedValue: 5,
            compare: { ($0 as? Int) == ($1 as? Int) }),
        DefaultValueTestCase(
            name: "Launch at login",
            getValue: { $0.launchAtLoginEnabled },
            expectedValue: false,
            compare: { ($0 as? Bool) == ($1 as? Bool) }),
        DefaultValueTestCase(
            name: "Menu bar display mode",
            getValue: { $0.menuBarDisplayMode },
            expectedValue: MenuBarDisplayMode.both,
            compare: { ($0 as? MenuBarDisplayMode) == ($1 as? MenuBarDisplayMode) }),
        DefaultValueTestCase(
            name: "Show in dock",
            getValue: { $0.showInDock },
            expectedValue: false,
            compare: { ($0 as? Bool) == ($1 as? Bool) }),
        DefaultValueTestCase(
            name: "Enabled providers",
            getValue: { $0.enabledProviders },
            expectedValue: Set([ServiceProvider.cursor]),
            compare: { ($0 as? Set<ServiceProvider>) == ($1 as? Set<ServiceProvider>) }),
    ])
    func defaultValues(testCase: DefaultValueTestCase) {
        let actualValue = testCase.getValue(settingsManager)
        #expect(testCase.compare(actualValue, testCase.expectedValue))
    }

    // MARK: - Setting Values Tests

    @Test("String property updates", arguments: [
        (property: "Currency", newValue: "EUR"),
        (property: "Currency", newValue: "GBP"),
        (property: "Currency", newValue: "JPY")
    ])
    func stringPropertyUpdates(property _: String, newValue: String) {
        settingsManager.selectedCurrencyCode = newValue
        #expect(settingsManager.selectedCurrencyCode == newValue)
    }

    @Test("Warning limit updates")
    func warningLimitUpdates() {
        let testValues = [150.5, 0.0, 999.99]
        for value in testValues {
            settingsManager.warningLimitUSD = value
            #expect(settingsManager.warningLimitUSD == value)
        }
    }

    @Test("Upper limit updates")
    func upperLimitUpdates() {
        let testValues = [800.75, 2000.0, 100.0]
        for value in testValues {
            settingsManager.upperLimitUSD = value
            #expect(settingsManager.upperLimitUSD == value)
        }
    }

    @Test("Integer property updates", arguments: [
        (property: "Refresh interval", value: 1),
        (property: "Refresh interval", value: 30),
        (property: "Refresh interval", value: 60),
        (property: "Refresh interval", value: 240)
    ])
    func integerPropertyUpdates(property _: String, value: Int) {
        settingsManager.refreshIntervalMinutes = value
        #expect(settingsManager.refreshIntervalMinutes == value)
    }

    @Test("Launch at login updates")
    func launchAtLoginUpdates() {
        settingsManager.launchAtLoginEnabled = true
        #expect(settingsManager.launchAtLoginEnabled == true)

        settingsManager.launchAtLoginEnabled = false
        #expect(settingsManager.launchAtLoginEnabled == false)
    }

    @Test("Show in dock updates")
    func showInDockUpdates() {
        settingsManager.showInDock = true
        #expect(settingsManager.showInDock == true)

        settingsManager.showInDock = false
        #expect(settingsManager.showInDock == false)
    }

    @Test("Menu bar display mode updates", arguments: [
        MenuBarDisplayMode.iconOnly,
        MenuBarDisplayMode.moneyOnly,
        MenuBarDisplayMode.both
    ])
    func menuBarDisplayModeUpdates(mode: MenuBarDisplayMode) {
        settingsManager.menuBarDisplayMode = mode
        #expect(settingsManager.menuBarDisplayMode == mode)
    }

    @Test("Enabled providers updates", arguments: [
        Set<ServiceProvider>([]),
        Set<ServiceProvider>([.cursor]),
        Set<ServiceProvider>([])
    ])
    func enabledProvidersUpdates(providers: Set<ServiceProvider>) {
        settingsManager.enabledProviders = providers
        #expect(settingsManager.enabledProviders == providers)
    }

    // MARK: - Provider Session Tests

    struct SessionTestCase {
        let provider: ServiceProvider
        let teamId: Int
        let teamName: String
        let userEmail: String
        let isActive: Bool
        let description: String
    }

    @Test("Provider session operations", arguments: [
        SessionTestCase(
            provider: .cursor,
            teamId: 12345,
            teamName: "Test Team",
            userEmail: "test@example.com",
            isActive: true,
            description: "Basic session"),
        SessionTestCase(
            provider: .cursor,
            teamId: 999,
            teamName: "Another Team",
            userEmail: "another@example.com",
            isActive: false,
            description: "Inactive session"),
        SessionTestCase(
            provider: .cursor,
            teamId: 0,
            teamName: "Empty Team",
            userEmail: "empty@example.com",
            isActive: true,
            description: "Zero team ID"),
    ])
    func providerSessionOperations(testCase: SessionTestCase) {
        let session = ProviderSession(
            provider: testCase.provider,
            teamId: testCase.teamId,
            teamName: testCase.teamName,
            userEmail: testCase.userEmail,
            isActive: testCase.isActive)

        settingsManager.updateSession(for: testCase.provider, session: session)

        let retrievedSession = settingsManager.getSession(for: testCase.provider)
        #expect(retrievedSession != nil)
        #expect(retrievedSession?.teamId == testCase.teamId)
        #expect(retrievedSession?.teamName == testCase.teamName)
        #expect(retrievedSession?.userEmail == testCase.userEmail)
        #expect(retrievedSession?.isActive == testCase.isActive)
    }

    @Test("get session for non existent provider")
    func getSessionForNonExistentProvider() {
        let retrievedSession = settingsManager.getSession(for: .cursor)
        #expect(retrievedSession == nil)
    }

    @Test("clear user session data")
    func clearUserSessionData() {
        // Set up multiple provider sessions
        let cursorSession = ProviderSession(
            provider: .cursor,
            teamId: 123,
            teamName: "Cursor Team",
            userEmail: "cursor@example.com",
            isActive: true)

        settingsManager.updateSession(for: .cursor, session: cursorSession)

        // Verify sessions are set
        #expect(settingsManager.getSession(for: .cursor) != nil)

        // Clear all sessions
        settingsManager.clearUserSessionData()

        // Verify all sessions are cleared
        #expect(settingsManager.getSession(for: .cursor) == nil)
    }

    @Test("clear user session data for specific provider")
    func clearUserSessionDataForSpecificProvider() {
        // Set up session for cursor
        let cursorSession = ProviderSession(
            provider: .cursor,
            teamId: 123,
            teamName: "Cursor Team",
            userEmail: "cursor@example.com",
            isActive: true)

        settingsManager.updateSession(for: .cursor, session: cursorSession)

        // Verify session is set
        #expect(settingsManager.getSession(for: .cursor) != nil)

        // Clear specific session
        settingsManager.clearUserSessionData(for: .cursor)

        // Verify cursor session is cleared
        #expect(settingsManager.getSession(for: .cursor) == nil)
    }

    @Test("refresh interval options")
    func refreshIntervalOptions() {
        let expectedOptions = [1, 2, 5, 10, 15, 30, 60]
        #expect(
            SettingsManager.refreshIntervalOptions == expectedOptions)
    }

    @Test("refresh interval validation")
    func refreshIntervalValidation() {
        // Test that all valid options can be set
        for option in SettingsManager.refreshIntervalOptions {
            settingsManager.refreshIntervalMinutes = option
            #expect(
                settingsManager.refreshIntervalMinutes == option)
        }
    }

    // MARK: - Initialization Tests

    @Test("initialization with existing values in user defaults")
    func initializationWithExistingValuesInUserDefaults() {
        // Pre-populate UserDefaults
        let existingSuiteName = "com.vibemeter.tests.ExistingValues"
        let existingUserDefaults = UserDefaults(suiteName: existingSuiteName)!
        existingUserDefaults.removePersistentDomain(forName: existingSuiteName)

        existingUserDefaults.set("EUR", forKey: SettingsManager.Keys.selectedCurrencyCode)
        existingUserDefaults.set(150.0, forKey: SettingsManager.Keys.warningLimitUSD)
        existingUserDefaults.set(750.0, forKey: SettingsManager.Keys.upperLimitUSD)
        existingUserDefaults.set(15, forKey: SettingsManager.Keys.refreshIntervalMinutes)
        existingUserDefaults.set(true, forKey: SettingsManager.Keys.launchAtLoginEnabled)
        existingUserDefaults.set("icon", forKey: SettingsManager.Keys.menuBarDisplayMode)
        existingUserDefaults.set(true, forKey: SettingsManager.Keys.showInDock)

        // Initialize SettingsManager with these pre-populated UserDefaults
        let mockStartupManager = StartupManagerMock()
        let managerWithExistingValues = SettingsManager(
            userDefaults: existingUserDefaults,
            startupManager: mockStartupManager)

        #expect(managerWithExistingValues.selectedCurrencyCode == "EUR")
        #expect(managerWithExistingValues.upperLimitUSD == 750.0)
        #expect(managerWithExistingValues.launchAtLoginEnabled == true)
        #expect(managerWithExistingValues.showInDock == true)
    }
}
