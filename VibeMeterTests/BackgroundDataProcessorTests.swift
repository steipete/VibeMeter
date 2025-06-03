import XCTest
@testable import VibeMeter

// MARK: - Mock Provider for Background Processing Tests

private final class MockBackgroundProvider: ProviderProtocol {
    let provider: ServiceProvider
    
    // Response data
    var userInfoToReturn: ProviderUserInfo?
    var teamInfoToReturn: ProviderTeamInfo?
    var invoiceToReturn: ProviderMonthlyInvoice?
    var usageToReturn: ProviderUsageData?
    
    // Error simulation
    var shouldThrowOnUserInfo = false
    var shouldThrowOnTeamInfo = false
    var shouldThrowOnInvoice = false
    var shouldThrowOnUsage = false
    var errorToThrow: Error = TestError.networkFailure
    
    // Timing simulation
    var userInfoDelay: TimeInterval = 0
    var teamInfoDelay: TimeInterval = 0
    var invoiceDelay: TimeInterval = 0
    var usageDelay: TimeInterval = 0
    
    // Call tracking
    var fetchUserInfoCallCount = 0
    var fetchTeamInfoCallCount = 0
    var fetchMonthlyInvoiceCallCount = 0
    var fetchUsageDataCallCount = 0
    var lastInvoiceMonth: Int?
    var lastInvoiceYear: Int?
    var lastTeamId: Int?
    
    init(provider: ServiceProvider) {
        self.provider = provider
    }
    
    func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo {
        fetchUserInfoCallCount += 1
        if userInfoDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(userInfoDelay * 1_000_000_000))
        }
        if shouldThrowOnUserInfo {
            throw errorToThrow
        }
        return userInfoToReturn ?? ProviderUserInfo(email: "test@example.com", teamId: 123, provider: provider)
    }
    
    func fetchTeamInfo(authToken: String) async throws -> ProviderTeamInfo {
        fetchTeamInfoCallCount += 1
        if teamInfoDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(teamInfoDelay * 1_000_000_000))
        }
        if shouldThrowOnTeamInfo {
            throw errorToThrow
        }
        return teamInfoToReturn ?? ProviderTeamInfo(id: 123, name: "Test Team", provider: provider)
    }
    
    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int, teamId: Int?) async throws -> ProviderMonthlyInvoice {
        fetchMonthlyInvoiceCallCount += 1
        lastInvoiceMonth = month
        lastInvoiceYear = year
        lastTeamId = teamId
        
        if invoiceDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(invoiceDelay * 1_000_000_000))
        }
        if shouldThrowOnInvoice {
            throw errorToThrow
        }
        return invoiceToReturn ?? ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 1000, description: "Test usage", provider: provider)],
            pricingDescription: nil,
            provider: provider,
            month: month,
            year: year
        )
    }
    
    func fetchUsageData(authToken: String) async throws -> ProviderUsageData {
        fetchUsageDataCallCount += 1
        if usageDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(usageDelay * 1_000_000_000))
        }
        if shouldThrowOnUsage {
            throw errorToThrow
        }
        return usageToReturn ?? ProviderUsageData(
            provider: provider,
            currentRequests: 100,
            maxRequests: 1000,
            currentTokens: 50000,
            maxTokens: 1000000
        )
    }
    
    func validateToken(authToken: String) async -> Bool {
        return true
    }
    
    func getAuthenticationURL() -> URL {
        URL(string: "https://test.com/auth")!
    }
    
    func extractAuthToken(from callbackData: [String: Any]) -> String? {
        callbackData["token"] as? String
    }
    
    func reset() {
        fetchUserInfoCallCount = 0
        fetchTeamInfoCallCount = 0
        fetchMonthlyInvoiceCallCount = 0
        fetchUsageDataCallCount = 0
        shouldThrowOnUserInfo = false
        shouldThrowOnTeamInfo = false
        shouldThrowOnInvoice = false
        shouldThrowOnUsage = false
        userInfoDelay = 0
        teamInfoDelay = 0
        invoiceDelay = 0
        usageDelay = 0
        lastInvoiceMonth = nil
        lastInvoiceYear = nil
        lastTeamId = nil
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
            return "Network connection failed"
        case .authenticationFailure:
            return "Authentication failed"
        case .serverError:
            return "Server error occurred"
        case .timeoutError:
            return "Request timed out"
        }
    }
}

// MARK: - Tests

final class BackgroundDataProcessorTests: XCTestCase {
    var sut: BackgroundDataProcessor!
    var mockProvider: MockBackgroundProvider!
    
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
            pricingDescription: "Test billing",
            provider: .cursor,
            month: 5,
            year: 2025
        )
        let expectedUsage = ProviderUsageData(
            provider: .cursor,
            currentRequests: 250,
            maxRequests: 5000,
            currentTokens: 75000,
            maxTokens: 2000000
        )
        
        mockProvider.userInfoToReturn = expectedUserInfo
        mockProvider.teamInfoToReturn = expectedTeamInfo
        mockProvider.invoiceToReturn = expectedInvoice
        mockProvider.usageToReturn = expectedUsage
        
        // When
        let result = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider
        )
        
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
            providerClient: mockProvider
        )
        
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
            providerClient: mockProvider
        )
        
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
            providerClient: mockProvider
        )
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Then - Should complete faster than sequential execution
        // Sequential would be 0.4s, concurrent should be ~0.2s (user+team parallel, then invoice+usage parallel)
        XCTAssertLessThan(duration, 0.35, "Concurrent execution should be faster than sequential")
        XCTAssertGreaterThan(duration, 0.15, "Should still take some time for the operations")
    }
    
    func testProcessProviderData_MultipleConcurrentCalls() async throws {
        // Given
        let callCount = 5
        var results: [(userInfo: ProviderUserInfo, teamInfo: ProviderTeamInfo, invoice: ProviderMonthlyInvoice, usage: ProviderUsageData)] = []
        
        // When - Make multiple concurrent calls to the actor
        await withTaskGroup(of: (userInfo: ProviderUserInfo, teamInfo: ProviderTeamInfo, invoice: ProviderMonthlyInvoice, usage: ProviderUsageData)?.self) { group in
            for i in 0..<callCount {
                group.addTask {
                    let provider = MockBackgroundProvider(provider: .cursor)
                    provider.userInfoToReturn = ProviderUserInfo(email: "user\(i)@test.com", teamId: i, provider: .cursor)
                    
                    do {
                        return try await self.sut.processProviderData(
                            provider: .cursor,
                            authToken: "token-\(i)",
                            providerClient: provider
                        )
                    } catch {
                        return nil
                    }
                }
            }
            
            for await result in group {
                if let result = result {
                    results.append(result)
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
                providerClient: mockProvider
            )
            XCTFail("Should have thrown authentication failure")
        } catch let error as TestError {
            XCTAssertEqual(error, .authenticationFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testProcessProviderData_TeamInfoFails_ThrowsError() async {
        // Given
        mockProvider.shouldThrowOnTeamInfo = true
        mockProvider.errorToThrow = TestError.networkFailure
        
        // When/Then
        do {
            _ = try await sut.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider
            )
            XCTFail("Should have thrown network failure")
        } catch let error as TestError {
            XCTAssertEqual(error, .networkFailure)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
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
                providerClient: mockProvider
            )
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
                providerClient: mockProvider
            )
            XCTFail("Should have thrown timeout error")
        } catch let error as TestError {
            XCTAssertEqual(error, .timeoutError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Actor Isolation Tests
    
    func testBackgroundDataProcessor_IsActor() {
        // Then - Verify it's properly defined as an actor
        XCTAssertTrue(type(of: sut) is any Actor.Type)
    }
    
    func testBackgroundDataProcessor_RunsOffMainThread() async throws {
        // Given
        var executionThread: Thread?
        
        let customProvider = MockBackgroundProvider(provider: .cursor)
        customProvider.userInfoToReturn = ProviderUserInfo(email: "thread@test.com", teamId: 999, provider: .cursor)
        
        // Override one method to capture the execution thread
        let originalFetchUser = customProvider.fetchUserInfo
        customProvider.fetchUserInfo = { authToken in
            executionThread = Thread.current
            return try await originalFetchUser(authToken)
        }
        
        // When
        _ = try await sut.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: customProvider
        )
        
        // Then
        XCTAssertNotNil(executionThread)
        XCTAssertFalse(executionThread!.isMainThread, "Should execute off the main thread")
    }
    
    // MARK: - Performance Tests
    
    func testProcessProviderData_Performance() async throws {
        // Given
        let iterations = 10
        var totalDuration: TimeInterval = 0
        
        // When
        for _ in 0..<iterations {
            let startTime = Date()
            _ = try await sut.processProviderData(
                provider: .cursor,
                authToken: "perf-token",
                providerClient: mockProvider
            )
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
                providerClient: tempProvider
            )
            
            // tempProvider goes out of scope here
        }
        
        // Then
        XCTAssertNil(weakProvider, "Provider should not be retained after processing")
    }
}