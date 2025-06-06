import Foundation
import Testing
@testable import VibeMeter

@Suite("BackgroundDataProcessor Error Tests")
struct BackgroundDataProcessorErrorTests {
    let processor: BackgroundDataProcessor
    let mockProvider: MockBackgroundProvider
    let mockDate = Date()

    init() {
        processor = BackgroundDataProcessor()
        mockProvider = MockBackgroundProvider()

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

    // MARK: - Error Handling Tests

    @Test("process provider data user info fails throws error")

    func processProviderDataUserInfoFailsThrowsError() async {
        // Given
        mockProvider.shouldThrowOnUserInfo = true
        mockProvider.errorToThrow = TestError.authenticationFailed

        // When/Then
        do {
            _ = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            Issue.record("Should have thrown error")
        } catch {
            #expect((error as? TestError) != nil)
            // Other methods should not be called if user info fails
            #expect(mockProvider.fetchUserInfoCallCount == 1)
            #expect(mockProvider.fetchMonthlyInvoiceCallCount == 0)
        }
    }

    @Test("process provider data team info fails uses fallback team")

    func processProviderDataTeamInfoFailsUsesFallbackTeam() async throws {
        // Given
        mockProvider.shouldThrowOnTeamInfo = true
        mockProvider.errorToThrow = TestError.teamInfoUnavailable

        // When
        let result = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then
        #expect(result.teamInfo.id == 0) // Fallback team name
        #expect(mockProvider.lastTeamId == nil)
        #expect(mockProvider.fetchTeamInfoCallCount == 1)
        #expect(mockProvider.fetchUsageDataCallCount == 1)
    }

    @Test("process provider data invoice fails throws error")

    func processProviderDataInvoiceFailsThrowsError() async {
        // Given
        mockProvider.shouldThrowOnInvoice = true
        mockProvider.errorToThrow = TestError.invoiceUnavailable

        // When/Then
        do {
            _ = try await processor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: mockProvider)
            Issue.record("Should have thrown error")
        } catch {
            #expect((error as? TestError) != nil)
            // User and team info should be fetched before invoice fails
            #expect(mockProvider.fetchUserInfoCallCount == 1)
            #expect(mockProvider.fetchMonthlyInvoiceCallCount == 1)
        }
    }

    @Test("process provider data usage fails uses fallback usage")

    func processProviderDataUsageFailsUsesFallbackUsage() async throws {
        // Given
        mockProvider.shouldThrowOnUsage = true
        mockProvider.errorToThrow = TestError.usageDataUnavailable

        // When
        let result = try await processor.processProviderData(
            provider: .cursor,
            authToken: "test-token",
            providerClient: mockProvider)

        // Then - Should succeed with fallback usage data
        #expect(result.usage.currentRequests == 0)
        #expect(result.usage.maxRequests == nil)

        // All methods should be called
        #expect(mockProvider.fetchUserInfoCallCount == 1)
        #expect(mockProvider.fetchMonthlyInvoiceCallCount == 1)
    }

    @Test("process provider data team and usage fail uses fallbacks")

    func processProviderDataTeamAndUsageFailUsesFallbacks() async throws {
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
        #expect(result.teamInfo.id == 0)
        #expect(result.usage.currentRequests == 0)

        // Invoice should still have real data
        #expect(result.invoice.totalSpendingCents == 2000)
        #expect(mockProvider.fetchTeamInfoCallCount == 1)
        #expect(mockProvider.fetchUsageDataCallCount == 1)
    }

    @Test("process provider data network error propagates error")

    func processProviderDataNetworkErrorPropagatesError() async {
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
            Issue.record("Should have thrown error")
        } catch {
            if case let ProviderError.networkError(message, _) = error {
                #expect(message == "Connection timeout")
            } else {
                Issue.record("Expected networkError, got \(error)")
            }
        }
    }

    @Test("process provider data authentication error propagates error")

    func processProviderDataAuthenticationErrorPropagatesError() async {
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
            Issue.record("Should have thrown error")
        } catch {
            if case let ProviderError.authenticationFailed(reason) = error {
                #expect(reason == "Invalid token")
            } else {
                Issue.record("Expected authenticationFailed, got \(error)")
            }
        }
    }

    @Test("process provider data cancellation during user info throws cancellation error")

    func processProviderDataCancellationDuringUserInfoThrowsCancellationError() async throws {
        // Given
        mockProvider.userInfoDelay = 1.0 // Long delay to allow cancellation

        // When
        let capturedProcessor = processor
        let capturedMockProvider = mockProvider
        let task = Task { @Sendable in
            try await capturedProcessor.processProviderData(
                provider: .cursor,
                authToken: "test-token",
                providerClient: capturedMockProvider)
        }

        // Cancel after a short delay
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        task.cancel()

        // Then
        do {
            _ = try await task.value
            Issue.record("Should have thrown cancellation error")
        } catch {
            #expect(error is CancellationError == true)
            #expect(capturedMockProvider.fetchTeamInfoCallCount == 0)
        }
    }
}
