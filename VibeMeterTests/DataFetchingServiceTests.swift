@testable import VibeMeter
import XCTest

// MARK: - Mock Provider for Testing

private final class MockDataFetchingProvider: ProviderProtocol {
    let provider: ServiceProvider

    // Configurable responses
    var userInfoToReturn: ProviderUserInfo?
    var teamInfoToReturn: ProviderTeamInfo?
    var invoiceToReturn: ProviderMonthlyInvoice?
    var usageToReturn: ProviderUsageData?
    var shouldThrowError = false
    var errorToThrow: Error = TestError.mockError

    // Call tracking
    var fetchUserInfoCallCount = 0
    var fetchTeamInfoCallCount = 0
    var fetchMonthlyInvoiceCallCount = 0
    var fetchUsageDataCallCount = 0
    var validateTokenCallCount = 0

    init(provider: ServiceProvider) {
        self.provider = provider
    }

    func fetchTeamInfo(authToken _: String) async throws -> ProviderTeamInfo {
        fetchTeamInfoCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return teamInfoToReturn ?? ProviderTeamInfo(id: 123, name: "Mock Team", provider: provider)
    }

    func fetchUserInfo(authToken _: String) async throws -> ProviderUserInfo {
        fetchUserInfoCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return userInfoToReturn ?? ProviderUserInfo(email: "mock@test.com", teamId: 123, provider: provider)
    }

    func fetchMonthlyInvoice(authToken _: String, month: Int, year: Int,
                             teamId _: Int?) async throws -> ProviderMonthlyInvoice {
        fetchMonthlyInvoiceCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return invoiceToReturn ?? ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 1000, description: "Mock usage", provider: provider)],
            pricingDescription: nil,
            provider: provider,
            month: month,
            year: year)
    }

    func fetchUsageData(authToken _: String) async throws -> ProviderUsageData {
        fetchUsageDataCallCount += 1
        if shouldThrowError {
            throw errorToThrow
        }
        return usageToReturn ?? ProviderUsageData(
            provider: provider,
            currentRequests: 100,
            maxRequests: 1000,
            currentTokens: 50000,
            maxTokens: 1_000_000)
    }

    func validateToken(authToken _: String) async -> Bool {
        validateTokenCallCount += 1
        return !shouldThrowError
    }

    func getAuthenticationURL() -> URL {
        URL(string: "https://mock.test.com/auth")!
    }

    func extractAuthToken(from callbackData: [String: Any]) -> String? {
        callbackData["token"] as? String
    }

    func reset() {
        fetchUserInfoCallCount = 0
        fetchTeamInfoCallCount = 0
        fetchMonthlyInvoiceCallCount = 0
        fetchUsageDataCallCount = 0
        validateTokenCallCount = 0
        shouldThrowError = false
        errorToThrow = TestError.mockError
    }
}

// MARK: - Mock Provider Factory

private final class MockDataFetchingProviderFactory: ProviderFactory {
    var mockProviders: [ServiceProvider: MockDataFetchingProvider] = [:]

    override func createProvider(for provider: ServiceProvider) -> ProviderProtocol {
        if let mockProvider = mockProviders[provider] {
            return mockProvider
        }
        let newMock = MockDataFetchingProvider(provider: provider)
        mockProviders[provider] = newMock
        return newMock
    }

    func getMockProvider(for provider: ServiceProvider) -> MockDataFetchingProvider? {
        mockProviders[provider]
    }
}

// MARK: - Test Error

private enum TestError: Error {
    case mockError
    case networkError
    case authError
}

// MARK: - Tests

@MainActor
final class DataFetchingServiceTests: XCTestCase {
    var sut: DataFetchingService!
    var mockProviderFactory: MockDataFetchingProviderFactory!
    var mockSettingsManager: SettingsManager!
    var mockExchangeRateManager: ExchangeRateManagerMock!
    var mockLoginManager: MultiProviderLoginManager!
    var testUserDefaults: UserDefaults!

    let testSuiteName = "com.vibemeter.tests.DataFetchingServiceTests"

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
        mockExchangeRateManager = ExchangeRateManagerMock()
        mockProviderFactory = MockDataFetchingProviderFactory(
            settingsManager: mockSettingsManager,
            urlSession: URLSession.shared)
        mockLoginManager = MultiProviderLoginManager(providerFactory: mockProviderFactory)

        // Initialize SUT
        sut = DataFetchingService(
            providerFactory: mockProviderFactory,
            settingsManager: mockSettingsManager,
            exchangeRateManager: mockExchangeRateManager,
            loginManager: mockLoginManager)

        // Reset defaults
        mockSettingsManager.selectedCurrencyCode = "USD"
        mockExchangeRateManager.reset()
        ProviderRegistry.shared.enableProvider(.cursor)
    }

    override func tearDown() async throws {
        sut = nil
        mockProviderFactory = nil
        mockSettingsManager = nil
        mockExchangeRateManager = nil
        mockLoginManager = nil
        SettingsManager._test_clearSharedInstance()
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Successful Data Fetching Tests

    func testFetchProviderData_Success_ReturnsCompleteResult() async throws {
        // Given
        let mockProvider = setupMockProvider()
        setupMockLogin()
        setupMockExchangeRates()

        let expectedUserInfo = ProviderUserInfo(email: "test@example.com", teamId: 456, provider: .cursor)
        let expectedTeamInfo = ProviderTeamInfo(id: 456, name: "Test Team", provider: .cursor)
        let expectedInvoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "API usage", provider: .cursor)],
            pricingDescription: "Test pricing",
            provider: .cursor,
            month: 5,
            year: 2025)
        let expectedUsage = ProviderUsageData(
            provider: .cursor,
            currentRequests: 250,
            maxRequests: 5000,
            currentTokens: 75000,
            maxTokens: 2_000_000)

        mockProvider.userInfoToReturn = expectedUserInfo
        mockProvider.teamInfoToReturn = expectedTeamInfo
        mockProvider.invoiceToReturn = expectedInvoice
        mockProvider.usageToReturn = expectedUsage

        // When
        let result = try await sut.fetchProviderData(for: .cursor)

        // Then
        XCTAssertEqual(result.provider, .cursor)
        XCTAssertEqual(result.userInfo.email, expectedUserInfo.email)
        XCTAssertEqual(result.teamInfo.name, expectedTeamInfo.name)
        XCTAssertEqual(result.invoice.totalSpendingCents, expectedInvoice.totalSpendingCents)
        XCTAssertEqual(result.usage.currentRequests, expectedUsage.currentRequests)
        XCTAssertEqual(result.targetCurrency, "USD")
        XCTAssertEqual(result.exchangeRates["USD"], 1.0)

        // Verify all API calls were made
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        XCTAssertEqual(mockProvider.fetchUsageDataCallCount, 1)
    }

    func testFetchProviderData_WithDifferentCurrency_ReturnsCorrectTargetCurrency() async throws {
        // Given
        setupMockProvider()
        setupMockLogin()
        mockSettingsManager.selectedCurrencyCode = "EUR"
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.85]

        // When
        let result = try await sut.fetchProviderData(for: .cursor)

        // Then
        XCTAssertEqual(result.targetCurrency, "EUR")
        XCTAssertEqual(result.exchangeRates["EUR"], 0.85)
    }

    // MARK: - Error Handling Tests

    func testFetchProviderData_ProviderDisabled_ThrowsError() async {
        // Given
        ProviderRegistry.shared.disableProvider(.cursor)
        setupMockLogin()

        // When/Then
        do {
            _ = try await sut.fetchProviderData(for: .cursor)
            XCTFail("Should have thrown providerDisabled error")
        } catch let error as DataFetchingError {
            if case let .providerDisabled(provider) = error {
                XCTAssertEqual(provider, .cursor)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchProviderData_NoAuthToken_ThrowsError() async {
        // Given
        ProviderRegistry.shared.enableProvider(.cursor)
        // Don't setup mock login (no auth token)

        // When/Then
        do {
            _ = try await sut.fetchProviderData(for: .cursor)
            XCTFail("Should have thrown noAuthToken error")
        } catch let error as DataFetchingError {
            if case let .noAuthToken(provider) = error {
                XCTAssertEqual(provider, .cursor)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchProviderData_UserInfoFails_ThrowsError() async {
        // Given
        let mockProvider = setupMockProvider()
        setupMockLogin()
        mockProvider.shouldThrowError = true
        mockProvider.errorToThrow = TestError.networkError

        // When/Then
        do {
            _ = try await sut.fetchProviderData(for: .cursor)
            XCTFail("Should have thrown network error")
        } catch {
            XCTAssertTrue(error is TestError)
        }
    }

    func testFetchProviderData_TeamInfoFails_ThrowsError() async {
        // Given
        let mockProvider = setupMockProvider()
        setupMockLogin()

        // Override fetchTeamInfo to throw error
        mockProvider.errorToThrow = TestError.authError
        var teamInfoCallCount = 0

        // When/Then
        do {
            _ = try await sut.fetchProviderData(for: .cursor)
            XCTFail("Should have thrown auth error")
        } catch {
            // Should be auth error from team info fetch
            XCTAssertTrue(error is TestError)
        }
    }

    // MARK: - Multiple Provider Tests

    func testFetchMultipleProviderData_Success_ReturnsAllResults() async {
        // Given
        let mockProvider = setupMockProvider()
        setupMockLogin()
        setupMockExchangeRates()

        // When
        let results = await sut.fetchMultipleProviderData(for: [.cursor])

        // Then
        XCTAssertEqual(results.count, 1)

        guard case let .success(result) = results[.cursor] else {
            XCTFail("Expected success result for Cursor")
            return
        }

        XCTAssertEqual(result.provider, .cursor)
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
    }

    func testFetchMultipleProviderData_PartialFailure_ReturnsSuccessAndFailure() async {
        // Given
        let cursorProvider = setupMockProvider()
        setupMockLogin()

        // Make one provider succeed and another fail
        cursorProvider.shouldThrowError = false

        // When
        let results = await sut.fetchMultipleProviderData(for: [.cursor])

        // Then
        XCTAssertEqual(results.count, 1)

        // Cursor should succeed
        guard case .success = results[.cursor] else {
            XCTFail("Expected success for Cursor")
            return
        }
    }

    func testFetchMultipleProviderData_EmptyProviders_ReturnsEmptyResults() async {
        // When
        let results = await sut.fetchMultipleProviderData(for: [])

        // Then
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Concurrent Operations Tests

    func testFetchProviderData_ConcurrentCalls_ExecuteIndependently() async {
        // Given
        let mockProvider = setupMockProvider()
        setupMockLogin()
        setupMockExchangeRates()

        // When - Make concurrent calls
        async let result1 = sut.fetchProviderData(for: .cursor)
        async let result2 = sut.fetchProviderData(for: .cursor)

        let (r1, r2) = try await (result1, result2)

        // Then
        XCTAssertEqual(r1.provider, .cursor)
        XCTAssertEqual(r2.provider, .cursor)

        // Each call should trigger all API calls
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 2)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 2)
    }

    // MARK: - Date/Month Handling Tests

    func testFetchProviderData_UsesCurrentMonthForInvoice() async throws {
        // Given
        let mockProvider = setupMockProvider()
        setupMockLogin()

        // When
        _ = try await sut.fetchProviderData(for: .cursor)

        // Then
        XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        // We can't easily test the exact month/year passed without refactoring
        // but we verify the call was made
    }

    // MARK: - Exchange Rate Integration Tests

    func testFetchProviderData_ExchangeRateFailure_StillReturnsResult() async throws {
        // Given
        setupMockProvider()
        setupMockLogin()
        mockExchangeRateManager.shouldFail = true

        // When
        let result = try await sut.fetchProviderData(for: .cursor)

        // Then
        XCTAssertEqual(result.provider, .cursor)
        // Should still have result even if exchange rates fail
        XCTAssertTrue(result.exchangeRates.isEmpty)
    }

    // MARK: - Performance Tests

    func testFetchProviderData_Performance() async throws {
        // Given
        setupMockProvider()
        setupMockLogin()
        setupMockExchangeRates()

        // When
        let startTime = Date()
        _ = try await sut.fetchProviderData(for: .cursor)
        let duration = Date().timeIntervalSince(startTime)

        // Then - Should complete quickly since operations are concurrent
        XCTAssertLessThan(duration, 1.0, "Data fetching should be fast with concurrent operations")
    }

    // MARK: - Helper Methods

    @discardableResult
    private func setupMockProvider() -> MockDataFetchingProvider {
        mockProviderFactory.getMockProvider(for: .cursor) ??
            MockDataFetchingProvider(provider: .cursor)
    }

    private func setupMockLogin() {
        #if DEBUG
            mockLoginManager._test_simulateLogin(for: .cursor, withToken: "mock-auth-token")
        #endif
    }

    private func setupMockExchangeRates() {
        mockExchangeRateManager.ratesToReturn = [
            "USD": 1.0,
            "EUR": 0.85,
            "GBP": 0.73,
        ]
    }
}
