@testable import VibeMeter
import XCTest

// MARK: - Mock GravatarService

private final class MockGravatarService: GravatarService {
    var updateAvatarCallCount = 0
    var lastEmailForAvatar: String?

    override func updateAvatar(for email: String) {
        updateAvatarCallCount += 1
        lastEmailForAvatar = email
    }

    func reset() {
        updateAvatarCallCount = 0
        lastEmailForAvatar = nil
    }
}

// MARK: - Tests

@MainActor
final class DataProcessingServiceTests: XCTestCase {
    var sut: DataProcessingService!
    var mockSettingsManager: SettingsManager!
    var mockNotificationManager: NotificationManagerMock!
    var mockGravatarService: MockGravatarService!
    var userSessionData: MultiProviderUserSessionData!
    var spendingData: MultiProviderSpendingData!
    var testUserDefaults: UserDefaults!

    let testSuiteName = "com.vibemeter.tests.DataProcessingServiceTests"

    override func setUp() async throws {
        try await super.setUp()

        // Setup UserDefaults
        let suite = UserDefaults(suiteName: testSuiteName)
        suite?.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = suite

        // Setup mocks
        SettingsManager._test_setSharedInstance(
            userDefaults: testUserDefaults,
            startupManager: StartupManagerMock())
        mockSettingsManager = SettingsManager.shared
        mockNotificationManager = NotificationManagerMock()
        mockGravatarService = MockGravatarService()

        // Setup data models
        userSessionData = MultiProviderUserSessionData()
        spendingData = MultiProviderSpendingData()

        // Initialize SUT
        sut = DataProcessingService(
            settingsManager: mockSettingsManager,
            notificationManager: mockNotificationManager)

        // Reset defaults
        mockSettingsManager.warningLimitUSD = 200.0
        mockSettingsManager.upperLimitUSD = 1000.0
        mockNotificationManager.reset()
        mockGravatarService.reset()
    }

    override func tearDown() async throws {
        sut = nil
        mockSettingsManager = nil
        mockNotificationManager = nil
        mockGravatarService = nil
        userSessionData = nil
        spendingData = nil
        SettingsManager._test_clearSharedInstance()
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Process Provider Data Tests

    func testProcessProviderData_Success_UpdatesAllDataModels() {
        // Given
        let providerResult = createMockProviderResult()

        // When
        sut.processProviderData(
            providerResult,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then - Verify user session data updated
        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor))
        XCTAssertEqual(userSessionData.getSession(for: .cursor)?.userEmail, "test@example.com")
        XCTAssertEqual(userSessionData.getSession(for: .cursor)?.teamName, "Test Team")
        XCTAssertEqual(userSessionData.getSession(for: .cursor)?.teamId, 123)

        // Verify settings manager updated
        let storedSession = mockSettingsManager.getSession(for: .cursor)
        XCTAssertNotNil(storedSession)
        XCTAssertEqual(storedSession?.userEmail, "test@example.com")
        XCTAssertEqual(storedSession?.teamName, "Test Team")
        XCTAssertTrue(storedSession?.isActive ?? false)

        // Verify spending data updated
        let cursorData = spendingData.getSpendingData(for: .cursor)
        XCTAssertNotNil(cursorData)
        XCTAssertEqual(cursorData?.currentSpendingUSD ?? 0, 25.0, accuracy: 0.01)

        // Verify gravatar updated
        XCTAssertEqual(mockGravatarService.updateAvatarCallCount, 1)
        XCTAssertEqual(mockGravatarService.lastEmailForAvatar, "test@example.com")
    }

    func testProcessProviderData_WithCurrencyConversion_UpdatesCorrectly() {
        // Given
        let providerResult = ProviderDataResult(
            provider: .cursor,
            userInfo: ProviderUserInfo(email: "eur@example.com", teamId: 456, provider: .cursor),
            teamInfo: ProviderTeamInfo(id: 456, name: "EUR Team", provider: .cursor),
            invoice: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 5000, description: "API calls", provider: .cursor)],
                pricingDescription: nil,
                provider: .cursor,
                month: 5,
                year: 2025),
            usage: ProviderUsageData(
                provider: .cursor,
                currentRequests: 200,
                maxRequests: 2000,
                currentTokens: 100_000,
                maxTokens: 2_000_000),
            exchangeRates: ["USD": 1.0, "EUR": 0.85],
            targetCurrency: "EUR")

        // When
        sut.processProviderData(
            providerResult,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then
        let cursorData = spendingData.getSpendingData(for: .cursor)
        XCTAssertNotNil(cursorData)
        XCTAssertEqual(cursorData?.currentSpendingUSD ?? 0, 50.0, accuracy: 0.01) // 5000 cents = $50
        // Display spending should be converted to EUR
        XCTAssertNotNil(cursorData?.displaySpending)
    }

    func testProcessProviderData_NotMostRecentUser_DoesNotUpdateGravatar() {
        // Given
        // First, add a different user as most recent
        userSessionData.handleLoginSuccess(
            for: .cursor,
            email: "existing@example.com",
            teamName: "Existing Team",
            teamId: 999)

        let providerResult = createMockProviderResult(email: "new@example.com")

        // When
        sut.processProviderData(
            providerResult,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then - Gravatar should be updated because this becomes the new most recent
        XCTAssertEqual(mockGravatarService.updateAvatarCallCount, 1)
        XCTAssertEqual(mockGravatarService.lastEmailForAvatar, "new@example.com")
    }

    // MARK: - Process Multiple Provider Data Tests

    func testProcessMultipleProviderData_AllSuccess_ProcessesAll() {
        // Given
        let results: [ServiceProvider: Result<ProviderDataResult, Error>] = [
            .cursor: .success(createMockProviderResult(email: "cursor@example.com")),
        ]

        // When
        let errors = sut.processMultipleProviderData(
            results,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then
        XCTAssertTrue(errors.isEmpty)
        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor))
        XCTAssertEqual(mockGravatarService.updateAvatarCallCount, 1)
    }

    func testProcessMultipleProviderData_PartialFailure_ProcessesSuccessAndErrors() {
        // Given
        let results: [ServiceProvider: Result<ProviderDataResult, Error>] = [
            .cursor: .failure(ProviderError.networkError(message: "Connection failed", statusCode: 500)),
        ]

        // When
        let errors = sut.processMultipleProviderData(
            results,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then
        XCTAssertEqual(errors.count, 1)
        XCTAssertNotNil(errors[.cursor])
        XCTAssertTrue(errors[.cursor]!.contains("Connection failed"))
    }

    // MARK: - Error Handling Tests

    func testProcessMultipleProviderData_UnauthorizedError_LogsOutUser() {
        // Given
        userSessionData.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test Team", teamId: 123)
        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor)) // Precondition

        let results: [ServiceProvider: Result<ProviderDataResult, Error>] = [
            .cursor: .failure(ProviderError.unauthorized),
        ]

        // When
        let errors = sut.processMultipleProviderData(
            results,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then
        XCTAssertTrue(errors.isEmpty) // Unauthorized doesn't return error message
        XCTAssertFalse(userSessionData.isLoggedIn(to: .cursor)) // Should be logged out
    }

    func testProcessMultipleProviderData_NoTeamFoundError_SetsTeamError() {
        // Given
        let results: [ServiceProvider: Result<ProviderDataResult, Error>] = [
            .cursor: .failure(ProviderError.noTeamFound),
        ]

        // When
        let errors = sut.processMultipleProviderData(
            results,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then
        XCTAssertTrue(errors.isEmpty) // NoTeamFound doesn't return error message
        // Check that team error was set
        let session = userSessionData.getSession(for: .cursor)
        XCTAssertNotNil(session?.errorMessage)
        XCTAssertTrue(session?.errorMessage?.contains("team vibe") ?? false)
    }

    func testProcessMultipleProviderData_GenericError_SetsErrorMessage() {
        // Given
        struct GenericError: Error, LocalizedError {
            let errorDescription: String? = "Something went wrong"
        }

        let results: [ServiceProvider: Result<ProviderDataResult, Error>] = [
            .cursor: .failure(GenericError()),
        ]

        // When
        let errors = sut.processMultipleProviderData(
            results,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then
        XCTAssertEqual(errors.count, 1)
        XCTAssertNotNil(errors[.cursor])
        XCTAssertTrue(errors[.cursor]!.contains("Something went wrong"))

        // Check that error message was set in user session
        let session = userSessionData.getSession(for: .cursor)
        XCTAssertNotNil(session?.errorMessage)
    }

    // MARK: - Currency Conversion Tests

    func testUpdateCurrencyConversions_UpdatesExistingProviders() {
        // Given
        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 3000, description: "Usage", provider: .cursor)],
                pricingDescription: nil,
                provider: .cursor,
                month: 5,
                year: 2025),
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        let newRates = ["USD": 1.0, "EUR": 0.9]

        // When
        sut.updateCurrencyConversions(
            spendingData: spendingData,
            exchangeRates: newRates,
            targetCurrency: "EUR")

        // Then
        let cursorData = spendingData.getSpendingData(for: .cursor)
        XCTAssertNotNil(cursorData)
        // Limits should be updated with new currency conversion
    }

    func testUpdateCurrencyConversions_IgnoresProvidersWithoutData() {
        // Given - No providers with data
        let newRates = ["USD": 1.0, "EUR": 0.9]

        // When
        sut.updateCurrencyConversions(
            spendingData: spendingData,
            exchangeRates: newRates,
            targetCurrency: "EUR")

        // Then - Should not crash and should handle empty state gracefully
        XCTAssertTrue(spendingData.providersWithData.isEmpty)
    }

    // MARK: - Notification Tests

    func testCheckLimitsAndNotify_ExceedsUpperLimit_ShowsUpperLimitNotification() async {
        // Given
        mockSettingsManager.upperLimitUSD = 100.0
        mockSettingsManager.warningLimitUSD = 50.0

        // Add spending that exceeds upper limit
        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 15000, description: "Heavy usage", provider: .cursor)], // $150
                pricingDescription: nil,
                provider: .cursor,
                month: 5,
                year: 2025),
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        // When
        await sut.checkLimitsAndNotify(spendingData: spendingData)

        // Then
        XCTAssertTrue(mockNotificationManager.showUpperLimitNotificationCalled)
        XCTAssertFalse(mockNotificationManager.showWarningNotificationCalled)
        XCTAssertEqual(mockNotificationManager.lastUpperLimitAmount ?? 0, 100.0, accuracy: 0.01)
        XCTAssertEqual(mockNotificationManager.lastUpperLimitSpending ?? 0, 150.0, accuracy: 0.01)
    }

    func testCheckLimitsAndNotify_ExceedsWarningLimit_ShowsWarningNotification() async {
        // Given
        mockSettingsManager.upperLimitUSD = 1000.0
        mockSettingsManager.warningLimitUSD = 200.0

        // Add spending that exceeds warning but not upper limit
        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 25000, description: "Medium usage", provider: .cursor)], // $250
                pricingDescription: nil,
                provider: .cursor,
                month: 5,
                year: 2025),
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        // When
        await sut.checkLimitsAndNotify(spendingData: spendingData)

        // Then
        XCTAssertFalse(mockNotificationManager.showUpperLimitNotificationCalled)
        XCTAssertTrue(mockNotificationManager.showWarningNotificationCalled)
        XCTAssertEqual(mockNotificationManager.lastWarningLimitAmount ?? 0, 200.0, accuracy: 0.01)
        XCTAssertEqual(mockNotificationManager.lastWarningLimitSpending ?? 0, 250.0, accuracy: 0.01)
    }

    func testCheckLimitsAndNotify_BelowLimits_ShowsNoNotifications() async {
        // Given
        mockSettingsManager.upperLimitUSD = 1000.0
        mockSettingsManager.warningLimitUSD = 200.0

        // Add spending below warning limit
        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 5000, description: "Light usage", provider: .cursor)], // $50
                pricingDescription: nil,
                provider: .cursor,
                month: 5,
                year: 2025),
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        // When
        await sut.checkLimitsAndNotify(spendingData: spendingData)

        // Then
        XCTAssertFalse(mockNotificationManager.showUpperLimitNotificationCalled)
        XCTAssertFalse(mockNotificationManager.showWarningNotificationCalled)
    }

    // MARK: - Integration Tests

    func testCompleteDataProcessingFlow() {
        // Given
        let providerResult = createMockProviderResult()

        // When - Process the data
        sut.processProviderData(
            providerResult,
            userSessionData: userSessionData,
            spendingData: spendingData,
            gravatarService: mockGravatarService)

        // Then - Verify complete flow
        // 1. User session updated
        XCTAssertTrue(userSessionData.isLoggedIn(to: .cursor))

        // 2. Settings persisted
        XCTAssertNotNil(mockSettingsManager.getSession(for: .cursor))

        // 3. Spending data updated
        XCTAssertNotNil(spendingData.getSpendingData(for: .cursor))

        // 4. Gravatar updated
        XCTAssertEqual(mockGravatarService.updateAvatarCallCount, 1)

        // 5. No errors occurred
        XCTAssertEqual(userSessionData.getSession(for: .cursor)?.errorMessage, nil)
    }

    // MARK: - Helper Methods

    private func createMockProviderResult(
        email: String = "test@example.com",
        teamName: String = "Test Team",
        teamId: Int = 123,
        spendingCents: Int = 2500) -> ProviderDataResult {
        ProviderDataResult(
            provider: .cursor,
            userInfo: ProviderUserInfo(email: email, teamId: teamId, provider: .cursor),
            teamInfo: ProviderTeamInfo(id: teamId, name: teamName, provider: .cursor),
            invoice: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: spendingCents, description: "API usage", provider: .cursor)],
                pricingDescription: nil,
                provider: .cursor,
                month: 5,
                year: 2025),
            usage: ProviderUsageData(
                provider: .cursor,
                currentRequests: 150,
                maxRequests: 1500,
                currentTokens: 75000,
                maxTokens: 1_500_000),
            exchangeRates: ["USD": 1.0, "EUR": 0.85],
            targetCurrency: "USD")
    }
}
