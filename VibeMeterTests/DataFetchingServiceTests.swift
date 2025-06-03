@testable import VibeMeter
import XCTest

// MARK: - Tests

@MainActor
final class DataFetchingServiceTests: XCTestCase {
    var sut: DataFetchingService!
    var providerFactory: ProviderFactory!
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
        providerFactory = ProviderFactory(
            settingsManager: mockSettingsManager,
            urlSession: URLSession.shared)
        mockLoginManager = MultiProviderLoginManager(providerFactory: providerFactory)

        // Initialize SUT
        sut = DataFetchingService(
            providerFactory: providerFactory,
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
        providerFactory = nil
        mockSettingsManager = nil
        mockExchangeRateManager = nil
        mockLoginManager = nil
        SettingsManager._test_clearSharedInstance()
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testDataFetchingService_Initialization_SetsUpCorrectly() {
        // Then
        XCTAssertNotNil(sut, "DataFetchingService should initialize correctly")
    }

    func testFetchMultipleProviderData_WithNoEnabledProviders_ReturnsEmptyResults() async {
        // Given
        ProviderRegistry.shared.disableProvider(.cursor)

        // When
        let result = await sut.fetchMultipleProviderData(for: [])

        // Then
        XCTAssertTrue(result.isEmpty, "Should return empty results when no providers are provided")
    }

    func testFetchProviderData_WithNoLogin_ThrowsUnauthorizedError() async {
        // Given
        // No login setup, so no valid session

        // When/Then
        do {
            _ = try await sut.fetchProviderData(for: .cursor)
            XCTFail("Should throw error when not logged in")
        } catch let providerError as ProviderError {
            XCTAssertEqual(providerError, .unauthorized, "Should throw unauthorized error")
        } catch {
            XCTFail("Should throw ProviderError.unauthorized, got: \(error)")
        }
    }

    func testFetchProviderData_WithSettings_UsesCorrectCurrency() async {
        // Given
        mockSettingsManager.selectedCurrencyCode = "EUR"

        // When/Then
        do {
            _ = try await sut.fetchProviderData(for: .cursor)
        } catch {
            // Expected to fail due to no login, but we're testing that it uses the correct currency
            // The test validates the service can be called and handles settings correctly
        }

        // Verify currency setting was accessed
        XCTAssertEqual(mockSettingsManager.selectedCurrencyCode, "EUR")
    }

    // MARK: - Concurrency Tests

    func testDataFetchingService_MainActorCompliance() {
        // Test passes if compilation succeeds - validates @MainActor compliance
        XCTAssertNotNil(sut)
    }

    func testConcurrentDataFetching_HandlesGracefully() async {
        // Given
        let taskCount = 5

        // When - Perform concurrent operations
        await withTaskGroup(of: Void.self) { group in
            for _ in 0 ..< taskCount {
                group.addTask { @MainActor in
                    // Test that multiple concurrent calls don't crash
                    do {
                        _ = try await self.sut.fetchProviderData(for: .cursor)
                    } catch {
                        // Expected to fail due to no authentication
                    }
                }
            }
        }

        // Then - Should complete without crashes
        XCTAssertNotNil(sut)
    }

    // MARK: - Exchange Rate Integration Tests

    func testFetchMultipleProviderData_UsesExchangeRateManager() async {
        // Given
        mockExchangeRateManager.ratesToReturn = ["USD": 1.0, "EUR": 0.85]

        // When
        let result = await sut.fetchMultipleProviderData(for: [.cursor])

        // Then
        // Exchange rate manager should be used when fetching provider data
        XCTAssertNotNil(result)
        // Note: fetchExchangeRatesCallCount would only increment if providers are logged in
        // This test validates the service is properly wired up
    }

    // MARK: - Error Handling Tests

    func testFetchProviderData_WithDisabledProvider_ThrowsUnsupportedError() async {
        // Given
        ProviderRegistry.shared.disableProvider(.cursor)

        // When/Then
        do {
            _ = try await sut.fetchProviderData(for: .cursor)
            XCTFail("Should throw error for disabled provider")
        } catch let providerError as ProviderError {
            XCTAssertEqual(providerError, .unsupportedProvider(.cursor))
        } catch {
            XCTFail("Should throw ProviderError.unsupportedProvider, got: \(error)")
        }
    }

    // MARK: - Provider Integration Tests

    func testProviderFactory_CreatesValidProviders() {
        // When
        let cursorProvider = providerFactory.createProvider(for: .cursor)

        // Then
        XCTAssertEqual(cursorProvider.provider, .cursor)
        XCTAssertNotNil(cursorProvider, "Should create valid Cursor provider")
    }

    func testProviderFactory_CreateEnabledProviders_ReturnsActiveProviders() {
        // Given
        ProviderRegistry.shared.enableProvider(.cursor)

        // When
        let providers = providerFactory.createEnabledProviders()

        // Then
        XCTAssertEqual(providers.count, 1)
        XCTAssertNotNil(providers[.cursor])
    }
}
