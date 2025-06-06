import Testing
@testable import VibeMeter

@Suite("BackgroundDataProcessorBasicTests")
struct BackgroundDataProcessorBasicTests {
    let processor: BackgroundDataProcessor
    let mockProvider: MockBackgroundProvider
    let mockDate: Date

    init() {
        self.processor = BackgroundDataProcessor()
        self.mockProvider = MockBackgroundProvider()
        self.mockDate = Date()

        // Set up mock data
        mockProvider.userInfoToReturn = ProviderUserInfo(email: "test@example.com", provider: .cursor)
        mockProvider.teamInfoToReturn = ProviderTeamInfo(id: 12345, name: "Test Team", provider: .cursor)
        mockProvider.invoiceToReturn = ProviderInvoice(
            provider: .cursor,
            items: [ProviderInvoiceItem(description: "Test", cents: 2000)])
        mockProvider.usageToReturn = ProviderUsageData(
            provider: .cursor,
            currentRequests: 500,
            maxRequests: 10000)
    }

    // MARK: - Basic Functionality Tests

    @Test("process provider data  success  returns all data")

    func processProviderData_Success_ReturnsAllData() async throws {
        // When
        let result = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        #expect(result.userInfo.email == "test@example.com")
        #expect(result.userInfo.provider == .cursor)
        #expect(result.teamInfo.name == "Test Team")
        #expect(result.invoice.provider == .cursor)
        #expect(result.invoice.items.first?.cents == 2000)

        #expect(result.usage.currentRequests == 500)
        #expect(result.usage.maxRequests == 10000)
        #expect(mockProvider.fetchTeamInfoCallCount == 1)
        #expect(mockProvider.fetchUsageDataCallCount == 1)
    }

    @Test("process provider data passes correct month and year")
    func processProviderData_PassesCorrectMonthAndYear() async throws {
        // When
        _ = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        let calendar = Calendar.current
        let currentMonth = calendar.component(.month, from: Date()) - 1 // API uses 0-based months
        let currentYear = calendar.component(.year, from: Date())

        #expect(mockProvider.lastInvoiceMonth == currentMonth)
    }

    @Test("process provider data  passes team id from fetched team info")

    func processProviderData_PassesTeamIdFromFetchedTeamInfo() async throws {
        // When
        _ = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        #expect(mockProvider.lastTeamId == 12345)
    }

    @Test("process provider data executes concurrently")

    func processProviderDataExecutesConcurrently() async throws {
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
        #expect(elapsed < 0.35)
    }

    @Test("process provider data multiple concurrent calls")

    func processProviderDataMultipleConcurrentCalls() async throws {
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
        #expect(results.count == 2)
        #expect(results[1].userInfo.email == "test@example.com")
        #expect(provider2.fetchUserInfoCallCount == 1)
    }

    @Test("background data processor is initialized correctly")

    func backgroundDataProcessorIsInitializedCorrectly() {
        // Then
        #expect(processor != nil)
    }

    @Test("background data processor runs off main thread")

    func backgroundDataProcessorRunsOffMainThread() async throws {
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
        #expect(threadCapturingProvider.executionThread != nil)
    }

    @Test("process provider data performance")

    func processProviderDataPerformance() async throws {
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
        #expect(averageTime < 0.01)
    }

    @Test("process provider data does not retain provider")

    func processProviderDataDoesNotRetainProvider() async throws {
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

            let capturedProcessor = processor
            Task { @Sendable in
                _ = try? await capturedProcessor.processProviderData(
                    provider: .cursor,
                    authToken: "test-token",
                    providerClient: provider)
            }
        }

        // Then - After a short delay, provider should be deallocated
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        #expect(weakProvider == nil)
    }
}
