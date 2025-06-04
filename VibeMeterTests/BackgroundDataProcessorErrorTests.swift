@testable import VibeMeter
import XCTest

final class BackgroundDataProcessorErrorTests: XCTestCase {
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

    // MARK: - Error Handling Tests

    func testProcessProviderData_UserInfoFails_ThrowsError() async {
        // Given
        mockProvider.shouldThrowOnUserInfo = true
        mockProvider.errorToThrow = TestError.authenticationFailed

        // When/Then
        do {
            _ = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual((error as? TestError), TestError.authenticationFailed)
            // Other methods should not be called if user info fails
            XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
            XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 0)
            XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 0)
            XCTAssertEqual(mockProvider.fetchUsageDataCallCount, 0)
        }
    }

    func testProcessProviderData_TeamInfoFails_UsesFallbackTeam() async throws {
        // Given
        mockProvider.shouldThrowOnTeamInfo = true
        mockProvider.errorToThrow = TestError.teamInfoUnavailable

        // When
        let result = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        XCTAssertEqual(result.teamInfo.id, 0) // Fallback team ID
        XCTAssertEqual(result.teamInfo.name, "Individual Account") // Fallback team name
        XCTAssertNil(mockProvider.lastTeamId) // Should pass nil for fallback team

        // All methods should be called
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        XCTAssertEqual(mockProvider.fetchUsageDataCallCount, 1)
    }

    func testProcessProviderData_InvoiceFails_ThrowsError() async {
        // Given
        mockProvider.shouldThrowOnInvoice = true
        mockProvider.errorToThrow = TestError.invoiceUnavailable

        // When/Then
        do {
            _ = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual((error as? TestError), TestError.invoiceUnavailable)
            // User and team info should be fetched before invoice fails
            XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
            XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
            XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        }
    }

    func testProcessProviderData_UsageFails_UsesFallbackUsage() async throws {
        // Given
        mockProvider.shouldThrowOnUsage = true
        mockProvider.errorToThrow = TestError.usageDataUnavailable

        // When
        let result = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then - Should succeed with fallback usage data
        XCTAssertEqual(result.usage.currentRequests, 0)
        XCTAssertEqual(result.usage.totalRequests, 0)
        XCTAssertNil(result.usage.maxRequests)
        XCTAssertEqual(result.usage.provider, .cursor)

        // All methods should be called
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        XCTAssertEqual(mockProvider.fetchUsageDataCallCount, 1)
    }

    func testProcessProviderData_TeamAndUsageFail_UsesFallbacks() async throws {
        // Given
        mockProvider.shouldThrowOnTeamInfo = true
        mockProvider.shouldThrowOnUsage = true
        mockProvider.errorToThrow = TestError.networkFailure

        // When
        let result = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then - Should succeed with both fallbacks
        XCTAssertEqual(result.teamInfo.id, 0) // Fallback team
        XCTAssertEqual(result.teamInfo.name, "Individual Account")
        XCTAssertEqual(result.usage.currentRequests, 0) // Fallback usage
        XCTAssertEqual(result.usage.totalRequests, 0)

        // Invoice should still have real data
        XCTAssertEqual(result.invoice.totalSpendingCents, 2000)

        // All methods should be called
        XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 1)
        XCTAssertEqual(mockProvider.fetchMonthlyInvoiceCallCount, 1)
        XCTAssertEqual(mockProvider.fetchUsageDataCallCount, 1)
    }

    func testProcessProviderData_NetworkError_PropagatesError() async {
        // Given
        mockProvider.shouldThrowOnUserInfo = true
        mockProvider.errorToThrow = ProviderError.networkError(
            message: "Connection timeout",
            statusCode: 408)

        // When/Then
        do {
            _ = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            XCTFail("Should have thrown error")
        } catch {
            if case let ProviderError.networkError(message, _) = error {
                XCTAssertEqual(message, "Connection timeout")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testProcessProviderData_AuthenticationError_PropagatesError() async {
        // Given
        mockProvider.shouldThrowOnUserInfo = true
        mockProvider.errorToThrow = ProviderError.authenticationFailed(
            reason: "Invalid token")

        // When/Then
        do {
            _ = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            XCTFail("Should have thrown error")
        } catch {
            if case let ProviderError.authenticationFailed(reason) = error {
                XCTAssertEqual(reason, "Invalid token")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testProcessProviderData_CancellationDuringUserInfo_ThrowsCancellationError() async throws {
        // Given
        mockProvider.userInfoDelay = 1.0 // Long delay to allow cancellation

        // When
        let task = Task {
            try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
        }

        // Cancel after a short delay
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        task.cancel()

        // Then
        do {
            _ = try await task.value
            XCTFail("Should have thrown cancellation error")
        } catch {
            XCTAssertTrue(error is CancellationError)
            // Only user info should have been attempted
            XCTAssertEqual(mockProvider.fetchUserInfoCallCount, 1)
            XCTAssertEqual(mockProvider.fetchTeamInfoCallCount, 0)
        }
    }
}
