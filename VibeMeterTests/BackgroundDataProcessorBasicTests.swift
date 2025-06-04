@testable import VibeMeter
import XCTest

final class BackgroundDataProcessorBasicTests: XCTestCase {
    var processor: BackgroundDataProcessor!
    var mockProvider: MockBackgroundProvider!
    var mockDate: Date!

    override func setUp() {
        super.setUp()
        processor = BackgroundDataProcessor()
        mockProvider = MockBackgroundProvider()
        mockDate = Date()

        // Set up default mock responses
        mockProvider.userInfoToReturn = ProviderUserInfo(
            email: "test@example.com",
            teamId: 12345,
            provider: .cursor)

        mockProvider.teamInfoToReturn = ProviderTeamInfo(
            id: 12345,
            name: "Test Team",
            provider: .cursor)

        let calendar = Calendar.current
        let currentDate = Date()
        let month = calendar.component(.month, from: currentDate) - 1 // 0-based
        let year = calendar.component(.year, from: currentDate)

        mockProvider.invoiceToReturn = ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 2000, description: "Test Item", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: month,
            year: year)

        mockProvider.usageToReturn = ProviderUsageData(
            currentRequests: 500,
            totalRequests: 1000,
            maxRequests: 10000,
            startOfMonth: mockDate,
            provider: .cursor)
    }

    override func tearDown() {
        processor = nil
        mockProvider = nil
        mockDate = nil
        super.tearDown()
    }

    // MARK: - Basic Functionality Tests

    func testProcessProviderData_Success_ReturnsAllData() async throws {
        // When
        let result = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        XCTAssertEqual(result.userInfo.email, "test@example.com")
        XCTAssertEqual(result.userInfo.teamId, 12345)
        XCTAssertEqual(result.userInfo.provider, .cursor)

        XCTAssertEqual(result.teamInfo.id, 12345)
        XCTAssertEqual(result.teamInfo.name, "Test Team")

        XCTAssertEqual(result.invoice.totalSpendingCents, 2000)
        XCTAssertEqual(result.invoice.provider, .cursor)
        XCTAssertEqual(result.invoice.items.count, 1)
        XCTAssertEqual(result.invoice.items.first?.cents, 2000)
        XCTAssertEqual(result.invoice.items.first?.description, "Test Item")

        XCTAssertEqual(result.usage.currentRequests, 500)
        XCTAssertEqual(result.usage.totalRequests, 1000)
        XCTAssertEqual(result.usage.maxRequests, 10000)

        // Verify all API methods were called
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        XCTAssertEqual(mockProvider.fetchUsageDataCallCount, 1)
    }

    func testProcessProviderData_PassesCorrectMonthAndYear() async throws {
        // When
        _ = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date())
        let currentYear = calendar.component(.year, from: Date())

        XCTAssertEqual(mockProvider.lastInvoiceMonth, currentMonth)
        XCTAssertEqual(mockProvider.lastInvoiceYear, currentYear)
    }

    func testProcessProviderData_PassesTeamIdFromFetchedTeamInfo() async throws {
        // When
        _ = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        XCTAssertEqual(mockProvider.lastTeamId, 12345)
    }

    func testProcessProviderData_ExecutesConcurrently() async throws {
        // Given - Add delays to simulate network latency
        mockProvider.userInfoDelay = 0.1
        mockProvider.teamInfoDelay = 0.1
        mockProvider.invoiceDelay = 0.1
        mockProvider.usageDelay = 0.1

        // When
        let startTime = Date()
        _ = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)
        let elapsed = Date().timeIntervalSince(startTime)

        // Then - Should take ~0.2s (user info + team info sequentially, then invoice + usage concurrently)
        // Not ~0.4s if all were sequential
        XCTAssertLessThan(elapsed, 0.3, "Operations should execute concurrently")
        XCTAssertGreaterThan(elapsed, 0.15, "Operations should have some delay")
    }

    func testProcessProviderData_MultipleConcurrentCalls() async throws {
        // Given
        let processor1 = BackgroundDataProcessor()
        let processor2 = BackgroundDataProcessor()
        let provider1 = MockBackgroundProvider()
        let provider2 = MockBackgroundProvider()

        // Set up both providers with same data
        for provider in [provider1, provider2] {
            provider.userInfoToReturn = mockProvider.userInfoToReturn
            provider.teamInfoToReturn = mockProvider.teamInfoToReturn
            provider.invoiceToReturn = mockProvider.invoiceToReturn
            provider.usageToReturn = mockProvider.usageToReturn
            provider.userInfoDelay = 0.05
        }

        // When - Process both concurrently
        async let result1 = processor1.processProviderData(
            provider: .cursor,
            authToken: "token1",
            providerClient: provider1)
        async let result2 = processor2.processProviderData(
            provider: .cursor,
            authToken: "token2",
            providerClient: provider2)

        let results = try await [result1, result2]

        // Then - Both should succeed independently
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].userInfo.email, "test@example.com")
        XCTAssertEqual(results[1].userInfo.email, "test@example.com")
        XCTAssertEqual(provider1.fetchUserInfoCallCount, 1)
        XCTAssertEqual(provider2.fetchUserInfoCallCount, 1)
    }

    func testBackgroundDataProcessor_IsInitializedCorrectly() {
        // Then
        XCTAssertNotNil(processor)
    }

    func testBackgroundDataProcessor_RunsOffMainThread() async throws {
        // Given
        let threadCapturingProvider = ThreadCapturingProvider()
        threadCapturingProvider.userInfoToReturn = mockProvider.userInfoToReturn
        threadCapturingProvider.teamInfoToReturn = mockProvider.teamInfoToReturn
        threadCapturingProvider.invoiceToReturn = mockProvider.invoiceToReturn
        threadCapturingProvider.usageToReturn = mockProvider.usageToReturn

        // When
        _ = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: threadCapturingProvider)

        // Then
        XCTAssertNotNil(threadCapturingProvider.executionThread)
        XCTAssertFalse(threadCapturingProvider.executionThread!.isMainThread,
                       "Processing should not run on main thread")
    }

    func testProcessProviderData_Performance() async throws {
        // Given
        let iterations = 10

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            _ = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
        }
        let elapsed = Date().timeIntervalSince(startTime)

        // Then
        let averageTime = elapsed / Double(iterations)
        XCTAssertLessThan(averageTime, 0.01, "Processing should be fast without delays")
    }

    func testProcessProviderData_DoesNotRetainProvider() async throws {
        // Given
        weak var weakProvider: MockBackgroundProvider?

        // When
        autoreleasepool {
            let provider = MockBackgroundProvider()
            weakProvider = provider
            provider.userInfoToReturn = mockProvider.userInfoToReturn
            provider.teamInfoToReturn = mockProvider.teamInfoToReturn
            provider.invoiceToReturn = mockProvider.invoiceToReturn
            provider.usageToReturn = mockProvider.usageToReturn

            Task { @Sendable in
                _ = try? await processor.processProviderData(
                    provider: .cursor,
                    authToken: "test-token",
                    providerClient: provider)
            }
        }

        // Then - After a short delay, provider should be deallocated
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        XCTAssertNil(weakProvider, "Provider should not be retained after processing")
    }
}
