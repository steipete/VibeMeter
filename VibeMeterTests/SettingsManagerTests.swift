@testable import VibeMeter
import Testing

@Suite("SettingsManager Tests")
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

    @Test("default currency is usd")
    func defaultCurrencyIsUSD() {
        #expect(settingsManager.selectedCurrencyCode == "USD")

    func defaultWarningLimit() {
        #expect(settingsManager.warningLimitUSD == 200.0)

    func defaultUpperLimit() {
        #expect(settingsManager.upperLimitUSD == 1000.0)

    func defaultRefreshInterval() {
        #expect(settingsManager.refreshIntervalMinutes == 5)

    func defaultLaunchAtLogin() {
        #expect(settingsManager.launchAtLoginEnabled == false)

    func defaultMenuBarDisplayMode() {
        #expect(settingsManager.menuBarDisplayMode == .both)

    func defaultShowInDock() {
        #expect(settingsManager.showInDock == false)

    func defaultEnabledProviders() {
        #expect(settingsManager.enabledProviders == [.cursor])

    func settingSelectedCurrency() {
        let newCurrency = "EUR"
        settingsManager.selectedCurrencyCode = newCurrency
        #expect(settingsManager.selectedCurrencyCode == newCurrency)

    func settingWarningLimitUSD() {
        let newLimit = 150.5
        settingsManager.warningLimitUSD = newLimit
        #expect(settingsManager.warningLimitUSD == newLimit)

    func settingUpperLimitUSD() {
        let newLimit = 800.75
        settingsManager.upperLimitUSD = newLimit
        #expect(settingsManager.upperLimitUSD == newLimit)

    func settingRefreshInterval() {
        let newInterval = 30
        settingsManager.refreshIntervalMinutes = newInterval
        #expect(settingsManager.refreshIntervalMinutes == newInterval)

    func settingLaunchAtLogin() {
        settingsManager.launchAtLoginEnabled = true
        #expect(settingsManager.launchAtLoginEnabled == true)
    }

    @Test("setting menu bar display mode")

    func settingMenuBarDisplayMode() {
        settingsManager.menuBarDisplayMode = .iconOnly
        #expect(
            settingsManager.menuBarDisplayMode == .iconOnly)

        settingsManager.menuBarDisplayMode = .both
        #expect(settingsManager.menuBarDisplayMode == .both)

    func settingShowInDock() {
        settingsManager.showInDock = true
        #expect(settingsManager.showInDock == true)
    }

    @Test("setting enabled providers")

    func settingEnabledProviders() {
        let newProviders: Set<ServiceProvider> = []
        settingsManager.enabledProviders = newProviders
        #expect(settingsManager.enabledProviders == newProviders)
        settingsManager.enabledProviders = allProviders
        #expect(settingsManager.enabledProviders == allProviders)

    func providerSessionStorage() {
        let session = ProviderSession(
            provider: .cursor,
            teamId: 12345,
            teamName: "Test Team",
            userEmail: "test@example.com",
            isActive: true)

        settingsManager.updateSession(for: .cursor, session: session)

        let retrievedSession = settingsManager.getSession(for: .cursor)
        #expect(retrievedSession != nil)
        #expect(retrievedSession?.teamId == 12345)
        #expect(retrievedSession?.userEmail == "test@example.com")
    }

    @Test("provider session overwrite")

    func providerSessionOverwrite() {
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
        #expect(retrievedSession?.teamId == 222)
        #expect(retrievedSession?.userEmail == "user2@example.com")
    }

    @Test("get session for non existent provider")

    func getSessionForNonExistentProvider() {
        let retrievedSession = settingsManager.getSession(for: .cursor)
        #expect(retrievedSession == nil)

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
        #expect(settingsManager.getSession(for: .cursor != nil)

        // Verify all sessions are cleared
        #expect(settingsManager.getSession(for: .cursor == nil)

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
        #expect(settingsManager.getSession(for: .cursor != nil)

        // Verify cursor session is cleared
        #expect(settingsManager.getSession(for: .cursor == nil)

    func refreshIntervalOptions() {
        let expectedOptions = [1, 2, 5, 10, 15, 30, 60]
        #expect(
            SettingsManager.refreshIntervalOptions == expectedOptions)

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
