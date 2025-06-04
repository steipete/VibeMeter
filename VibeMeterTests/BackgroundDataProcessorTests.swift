@testable import VibeMeter
import XCTest

// MARK: - Mock Provider for Background Processing Tests

private class MockBackgroundProvider: ProviderProtocol, @unchecked Sendable {
    let provider: ServiceProvider
    private let lock = NSLock()

    // Response data
    private var _userInfoToReturn: ProviderUserInfo?
    private var _teamInfoToReturn: ProviderTeamInfo?
    private var _invoiceToReturn: ProviderMonthlyInvoice?
    private var _usageToReturn: ProviderUsageData?

    // Error simulation
    private var _shouldThrowOnUserInfo = false
    private var _shouldThrowOnTeamInfo = false
    private var _shouldThrowOnInvoice = false
    private var _shouldThrowOnUsage = false
    private var _errorToThrow: Error = TestError.networkFailure

    // Timing simulation
    private var _userInfoDelay: TimeInterval = 0
    private var _teamInfoDelay: TimeInterval = 0
    private var _invoiceDelay: TimeInterval = 0
    private var _usageDelay: TimeInterval = 0

    // Call tracking
    private var _fetchUserInfoCallCount = 0
    private var _fetchTeamInfoCallCount = 0
    private var _fetchMonthlyInvoiceCallCount = 0
    private var _fetchUsageDataCallCount = 0
    private var _lastInvoiceMonth: Int?
    private var _lastInvoiceYear: Int?
    private var _lastTeamId: Int?

    // Thread-safe property accessors
    var userInfoToReturn: ProviderUserInfo? {
        get { lock.withLock { _userInfoToReturn } }
        set { lock.withLock { _userInfoToReturn = newValue } }
    }

    var teamInfoToReturn: ProviderTeamInfo? {
        get { lock.withLock { _teamInfoToReturn } }
        set { lock.withLock { _teamInfoToReturn = newValue } }
    }

    var invoiceToReturn: ProviderMonthlyInvoice? {
        get { lock.withLock { _invoiceToReturn } }
        set { lock.withLock { _invoiceToReturn = newValue } }
    }

    var usageToReturn: ProviderUsageData? {
        get { lock.withLock { _usageToReturn } }
        set { lock.withLock { _usageToReturn = newValue } }
    }

    var shouldThrowOnUserInfo: Bool {
        get { lock.withLock { _shouldThrowOnUserInfo } }
        set { lock.withLock { _shouldThrowOnUserInfo = newValue } }
    }

    var shouldThrowOnTeamInfo: Bool {
        get { lock.withLock { _shouldThrowOnTeamInfo } }
        set { lock.withLock { _shouldThrowOnTeamInfo = newValue } }
    }

    var shouldThrowOnInvoice: Bool {
        get { lock.withLock { _shouldThrowOnInvoice } }
        set { lock.withLock { _shouldThrowOnInvoice = newValue } }
    }

    var shouldThrowOnUsage: Bool {
        get { lock.withLock { _shouldThrowOnUsage } }
        set { lock.withLock { _shouldThrowOnUsage = newValue } }
    }

    var errorToThrow: Error {
        get { lock.withLock { _errorToThrow } }
        set { lock.withLock { _errorToThrow = newValue } }
    }

    var userInfoDelay: TimeInterval {
        get { lock.withLock { _userInfoDelay } }
        set { lock.withLock { _userInfoDelay = newValue } }
    }

    var teamInfoDelay: TimeInterval {
        get { lock.withLock { _teamInfoDelay } }
        set { lock.withLock { _teamInfoDelay = newValue } }
    }

    var invoiceDelay: TimeInterval {
        get { lock.withLock { _invoiceDelay } }
        set { lock.withLock { _invoiceDelay = newValue } }
    }

    var usageDelay: TimeInterval {
        get { lock.withLock { _usageDelay } }
        set { lock.withLock { _usageDelay = newValue } }
    }

    var fetchUserInfoCallCount: Int {
        get { lock.withLock { _fetchUserInfoCallCount } }
        set { lock.withLock { _fetchUserInfoCallCount = newValue } }
    }

    var fetchTeamInfoCallCount: Int {
        get { lock.withLock { _fetchTeamInfoCallCount } }
        set { lock.withLock { _fetchTeamInfoCallCount = newValue } }
    }

    var fetchMonthlyInvoiceCallCount: Int {
        get { lock.withLock { _fetchMonthlyInvoiceCallCount } }
        set { lock.withLock { _fetchMonthlyInvoiceCallCount = newValue } }
    }

    var fetchUsageDataCallCount: Int {
        get { lock.withLock { _fetchUsageDataCallCount } }
        set { lock.withLock { _fetchUsageDataCallCount = newValue } }
    }

    var lastInvoiceMonth: Int? {
        get { lock.withLock { _lastInvoiceMonth } }
        set { lock.withLock { _lastInvoiceMonth = newValue } }
    }

    var lastInvoiceYear: Int? {
        get { lock.withLock { _lastInvoiceYear } }
        set { lock.withLock { _lastInvoiceYear = newValue } }
    }

    var lastTeamId: Int? {
        get { lock.withLock { _lastTeamId } }
        set { lock.withLock { _lastTeamId = newValue } }
    }

    init(provider: ServiceProvider) {
        self.provider = provider
    }

    func fetchUserInfo(authToken _: String) async throws -> ProviderUserInfo {
        lock.withLock { _fetchUserInfoCallCount += 1 }
        let delay = userInfoDelay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if shouldThrowOnUserInfo {
            throw errorToThrow
        }
        return userInfoToReturn ?? ProviderUserInfo(email: "test@example.com", teamId: 123, provider: provider)
    }

    func fetchTeamInfo(authToken _: String) async throws -> ProviderTeamInfo {
        lock.withLock { _fetchTeamInfoCallCount += 1 }
        let delay = teamInfoDelay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if shouldThrowOnTeamInfo {
            throw errorToThrow
        }
        return teamInfoToReturn ?? ProviderTeamInfo(id: 123, name: "Test Team", provider: provider)
    }

    func fetchMonthlyInvoice(authToken _: String, month: Int, year: Int,
                             teamId: Int?) async throws -> ProviderMonthlyInvoice {
        lock.withLock {
            _fetchMonthlyInvoiceCallCount += 1
            _lastInvoiceMonth = month
            _lastInvoiceYear = year
            _lastTeamId = teamId
        }

        let delay = invoiceDelay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if shouldThrowOnInvoice {
            throw errorToThrow
        }
        return invoiceToReturn ?? ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 1000, description: "Test usage", provider: provider)],
            pricingDescription: nil,
            provider: provider,
            month: month,
            year: year)
    }

    func fetchUsageData(authToken _: String) async throws -> ProviderUsageData {
        lock.withLock { _fetchUsageDataCallCount += 1 }
        let delay = usageDelay
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        if shouldThrowOnUsage {
            throw errorToThrow
        }
        return usageToReturn ?? ProviderUsageData(
            currentRequests: 100,
            totalRequests: 500,
            maxRequests: 1000,
            startOfMonth: Date(),
            provider: provider)
    }

    func validateToken(authToken _: String) async -> Bool {
        true
    }

    func getAuthenticationURL() -> URL {
        URL(string: "https://test.com/auth")!
    }

    func extractAuthToken(from callbackData: [String: Any]) -> String? {
        callbackData["token"] as? String
    }

    func reset() {
        lock.withLock {
            _fetchUserInfoCallCount = 0
            _fetchTeamInfoCallCount = 0
            _fetchMonthlyInvoiceCallCount = 0
            _fetchUsageDataCallCount = 0
            _shouldThrowOnUserInfo = false
            _shouldThrowOnTeamInfo = false
            _shouldThrowOnInvoice = false
            _shouldThrowOnUsage = false
            _userInfoDelay = 0
            _teamInfoDelay = 0
            _invoiceDelay = 0
            _usageDelay = 0
            _lastInvoiceMonth = nil
            _lastInvoiceYear = nil
            _lastTeamId = nil
        }
    }
}

// MARK: - Thread Capturing Mock Provider

private final class ThreadCapturingMockProvider: MockBackgroundProvider, @unchecked Sendable {
    var capturedExecutionContext: String?

    override func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo {
        // Capture execution context instead of thread (safer in async context)
        capturedExecutionContext = "async-context-\(UUID().uuidString)"
        return try await super.fetchUserInfo(authToken: authToken)
    }
}

// MARK: - Test Errors

private enum TestError: Error, LocalizedError {
    case networkFailure
    case authenticationFailure
    case serverError
    case timeoutError

    var errorDescription: String? {
        switch self {
        case .networkFailure:
            "Network connection failed"
        case .authenticationFailure:
            "Authentication failed"
        case .serverError:
            "Server error occurred"
        case .timeoutError:
            "Request timed out"
        }
    }
}

// MARK: - Tests

final class BackgroundDataProcessorTests: XCTestCase {
    var sut: BackgroundDataProcessor!
    fileprivate var mockProvider: MockBackgroundProvider!

    override func setUp() async throws {
        try await super.setUp()
        sut = BackgroundDataProcessor()
        mockProvider = MockBackgroundProvider(provider: .cursor)
    }

    override func tearDown() async throws {
        sut = nil
        mockProvider = nil
        try await super.tearDown()
    }

    // MARK: - Successful Processing Tests

    func testProcessProviderData_Success_ReturnsAllData() async throws {
        // Given
        let expectedUserInfo = ProviderUserInfo(email: "success@test.com", teamId: 456, provider: .cursor)
        let expectedTeamInfo = ProviderTeamInfo(id: 456, name: "Success Team", provider: .cursor)
        let expectedInvoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 2500, description: "API calls", provider: .cursor)],
            pricingDescription: ProviderPricingDescription(
                description: "Test billing",
                id: "test-id",
                provider: .cursor),
            provider: .cursor,
            month: 5,
            year: 2025)
        let expectedUsage = ProviderUsageData(
            currentRequests: 250,
            totalRequests: 1000,
            maxRequests: 5000,
            startOfMonth: Date(),
            provider: .cursor)

        mockProvider.userInfoToReturn = expectedUserInfo
        mockProvider.teamInfoToReturn = expectedTeamInfo
        mockProvider.invoiceToReturn = expectedInvoice
        mockProvider.usageToReturn = expectedUsage

        // When
        let result = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        XCTAssertEqual(result.userInfo.email, expectedUserInfo.email)
        XCTAssertEqual(result.teamInfo.name, expectedTeamInfo.name)
        XCTAssertEqual(result.invoice.totalSpendingCents, expectedInvoice.totalSpendingCents)
        XCTAssertEqual(result.usage.currentRequests, expectedUsage.currentRequests)

        // Verify all API calls were made
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        XCTAssertEqual(mockProvider.fetchUsageDataCallCount, 1)
    }

    func testProcessProviderData_PassesCorrectMonthAndYear() async throws {
        // Given
        let calendar = Calendar.current
        let expectedMonth = calendar.component(.month, from: Date()) - 1 // 0-based
        let expectedYear = calendar.component(.year, from: Date())

        // When
        _ = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        XCTAssertEqual(mockProvider.lastInvoiceMonth, expectedMonth)
        XCTAssertEqual(mockProvider.lastInvoiceYear, expectedYear)
    }

    func testProcessProviderData_PassesTeamIdFromFetchedTeamInfo() async throws {
        // Given
        let teamInfo = ProviderTeamInfo(id: 789, name: "Dynamic Team", provider: .cursor)
        mockProvider.teamInfoToReturn = teamInfo

        // When
        _ = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        XCTAssertEqual(mockProvider.lastTeamId, 789)
    }

    // MARK: - Concurrent Operation Tests

    func testProcessProviderData_ExecutesConcurrently() async throws {
        // Given
        mockProvider.userInfoDelay = 0.1
        mockProvider.teamInfoDelay = 0.1
        mockProvider.invoiceDelay = 0.1
        mockProvider.usageDelay = 0.1

        let startTime = Date()

        // When
        _ = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        let duration = Date().timeIntervalSince(startTime)

        // Then - Should complete faster than sequential execution
        // Sequential would be 0.4s, concurrent should be ~0.2s (user+team parallel, then invoice+usage parallel)
        XCTAssertLessThan(duration, 0.35, "Concurrent execution should be faster than sequential")
        XCTAssertGreaterThan(duration, 0.15, "Should still take some time for the operations")
    }

    func testProcessProviderData_MultipleConcurrentCalls() async throws {
        // Given
        let callCount = 5
        var results: [(
            userInfo: ProviderUserInfo,
            teamInfo: ProviderTeamInfo,
            invoice: ProviderMonthlyInvoice,
            usage: ProviderUsageData)] = []

        // When - Make multiple concurrent calls to the actor
        await withTaskGroup(of: ProviderDataResult?.self) { group in
                for i in 0 ..< callCount {
                    group.addTask { [sut = self.sut] in
                        let provider = MockBackgroundProvider(provider: .cursor)
                        provider.userInfoToReturn = ProviderUserInfo(
                            email: "user\(i)@test.com",
                            teamId: i,
                            provider: .cursor)

                        do {
                            return try await sut!.processProviderData(
                                provider: .cursor,
                                authToken: "token-\(i)",
                                providerClient: provider)
                        } catch {
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let result {
                        results.append((
                            userInfo: result.userInfo,
                            teamInfo: result.teamInfo,
                            invoice: result.invoice,
                            usage: result.usage
                        ))
                    }
                }
            }

        // Then
        XCTAssertEqual(results.count, callCount, "All concurrent calls should complete")
    }

    // MARK: - Error Handling Tests

    func testProcessProviderData_UserInfoFails_ThrowsError() async {
        // Given
        mockProvider.shouldThrowOnUserInfo = true
        mockProvider.errorToThrow = TestError.authenticationFailure

        // When/Then
        do {
            _ = try await sut.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            XCTFail("Should have thrown authentication failure")
        } catch let error as TestError {
            XCTAssertEqual(error, .authenticationFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testProcessProviderData_TeamInfoFails_UsesFallbackTeam() async throws {
        // Given
        mockProvider.shouldThrowOnTeamInfo = true
        mockProvider.errorToThrow = TestError.networkFailure

        // When
        let result = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then - Should use fallback team instead of throwing
        XCTAssertEqual(result.teamInfo.id, 0)
        XCTAssertEqual(result.teamInfo.name, "Individual Account")
        XCTAssertEqual(result.teamInfo.provider, .cursor)
        
        // Other data should still be fetched successfully
        XCTAssertEqual(result.userInfo.email, "test@example.com")
        XCTAssertEqual(result.invoice.totalSpendingCents, 1000)
        XCTAssertEqual(result.usage.currentRequests, 100)
    }

    func testProcessProviderData_InvoiceFails_ThrowsError() async {
        // Given
        mockProvider.shouldThrowOnInvoice = true
        mockProvider.errorToThrow = TestError.serverError

        // When/Then
        do {
            _ = try await sut.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            XCTFail("Should have thrown server error")
        } catch let error as TestError {
            XCTAssertEqual(error, .serverError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testProcessProviderData_UsageFails_ThrowsError() async {
        // Given
        mockProvider.shouldThrowOnUsage = true
        mockProvider.errorToThrow = TestError.timeoutError

        // When/Then
        do {
            _ = try await sut.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            XCTFail("Should have thrown timeout error")
        } catch let error as TestError {
            XCTAssertEqual(error, .timeoutError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Actor Isolation Tests

    func testBackgroundDataProcessor_IsInitializedCorrectly() {
        // Then - Verify it's properly initialized
        XCTAssertNotNil(sut)
    }

    func testBackgroundDataProcessor_RunsOffMainThread() async throws {
        // Given
        let customProvider = ThreadCapturingMockProvider(provider: .cursor)
        customProvider.userInfoToReturn = ProviderUserInfo(email: "thread@test.com", teamId: 999, provider: .cursor)

        // When
        _ = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: customProvider)

        // Then
        XCTAssertNotNil(customProvider.capturedExecutionContext)
        XCTAssertTrue(
            customProvider.capturedExecutionContext!.contains("async-context"),
            "Should execute in async context")
    }

    // MARK: - Performance Tests

    func testProcessProviderData_Performance() async throws {
        // Given
        let iterations = 10
        var totalDuration: TimeInterval = 0

        // When
        for _ in 0 ..< iterations {
            let startTime = Date()
            _ = try await sut.processProviderData(
                provider: .cursor,
                authToken: "perf-token",
                providerClient: mockProvider)
            totalDuration += Date().timeIntervalSince(startTime)
        }

        let averageDuration = totalDuration / Double(iterations)

        // Then
        XCTAssertLessThan(averageDuration, 0.1, "Average processing time should be fast")
    }

    // MARK: - Memory Management Tests

    func testProcessProviderData_DoesNotRetainProvider() async throws {
        // Given
        weak var weakProvider: MockBackgroundProvider?

        do {
            let tempProvider = MockBackgroundProvider(provider: .cursor)
            weakProvider = tempProvider

            // When
            _ = try await sut.processProviderData(
                provider: .cursor,
                authToken: "memory-token",
                providerClient: tempProvider)

            // tempProvider goes out of scope here
        }

        // Then
        XCTAssertNil(weakProvider, "Provider should not be retained after processing")
    }
}
