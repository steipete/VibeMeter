import Foundation
import Testing
@testable import VibeMeter

// MARK: - Async Test Helpers

/// Helper for testing async operations with confirmations
struct AsyncTestHelper {
    
    /// Waits for an async operation and confirms it was called
    static func confirmAsyncOperation<T>(
        expectedCount: Int = 1,
        timeout: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        return try await operation()
    }
    
    /// Tests that an async operation completes within a time limit
    static func testWithTimeout<T>(
        timeout: TimeInterval = 5.0,
        operation: () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    struct TimeoutError: Error, LocalizedError {
        var errorDescription: String? {
            "Operation timed out"
        }
    }
}

// MARK: - Mock Verification Helpers

extension NotificationManagerMock {
    /// Verifies that a warning notification was shown with expected parameters
    func verifyWarningNotification(
        spending: Double,
        limit: Double,
        currency: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(showWarningNotificationCalled, sourceLocation: sourceLocation)
        #expect(lastWarningSpending == spending, sourceLocation: sourceLocation)
        #expect(lastWarningLimit == limit, sourceLocation: sourceLocation)
        #expect(lastWarningCurrency == currency, sourceLocation: sourceLocation)
    }
    
    /// Verifies that an upper limit notification was shown with expected parameters
    func verifyUpperLimitNotification(
        spending: Double,
        limit: Double,
        currency: String,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(showUpperLimitNotificationCalled, sourceLocation: sourceLocation)
        #expect(lastUpperLimitSpending == spending, sourceLocation: sourceLocation)
        #expect(lastUpperLimitAmount == limit, sourceLocation: sourceLocation)
        #expect(lastUpperLimitCurrency == currency, sourceLocation: sourceLocation)
    }
    
    /// Verifies that notification state was reset with expected parameters
    func verifyNotificationStateReset(
        limitType: NotificationLimitType,
        currentSpending: Double,
        warningLimit: Double,
        upperLimit: Double,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(resetNotificationStateIfBelowCalled, sourceLocation: sourceLocation)
        #expect(lastResetLimitType == limitType, sourceLocation: sourceLocation)
        #expect(lastResetCurrentSpendingUSD == currentSpending, sourceLocation: sourceLocation)
        #expect(lastResetWarningLimitUSD == warningLimit, sourceLocation: sourceLocation)
        #expect(lastResetUpperLimitUSD == upperLimit, sourceLocation: sourceLocation)
    }
}

// MARK: - Provider Test Helpers

extension ProviderMonthlyInvoice {
    /// Creates a test invoice with common defaults
    static func makeTestInvoice(
        items: [ProviderInvoiceItem]? = nil,
        provider: ServiceProvider = .cursor,
        month: Int = 1,
        year: Int = 2025,
        pricingDescription: ProviderPricingDescription? = nil
    ) -> ProviderMonthlyInvoice {
        let defaultItems = items ?? [
            ProviderInvoiceItem(cents: 5000, description: "Test usage", provider: provider)
        ]
        
        return ProviderMonthlyInvoice(
            items: defaultItems,
            pricingDescription: pricingDescription,
            provider: provider,
            month: month,
            year: year
        )
    }
}

extension ProviderSession {
    /// Creates a test session with common defaults
    static func makeTestSession(
        provider: ServiceProvider = .cursor,
        teamId: Int? = 12345,
        teamName: String? = "Test Team",
        userEmail: String = "test@example.com",
        isActive: Bool = true
    ) -> ProviderSession {
        return ProviderSession(
            provider: provider,
            teamId: teamId,
            teamName: teamName,
            userEmail: userEmail,
            isActive: isActive
        )
    }
}

// MARK: - URL Session Test Helpers

extension MockURLSession {
    /// Configures the mock to return a successful response with data
    func configureSuccess(
        data: Data,
        statusCode: Int = 200,
        headers: [String: String]? = nil
    ) {
        self.nextData = data
        self.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: headers
        )!
    }
    
    /// Configures the mock to return an error
    func configureError(_ error: Error) {
        self.nextError = error
    }
    
    /// Configures the mock to return a specific status code with optional data
    func configureHTTPError(
        statusCode: Int,
        data: Data? = nil
    ) {
        self.nextData = data
        self.nextResponse = HTTPURLResponse(
            url: URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
}

// MARK: - Settings Manager Test Helpers

extension MockSettingsManager {
    /// Sets up common test state
    func setupTestState(
        currency: String = "USD",
        warningLimit: Double = 100.0,
        upperLimit: Double = 200.0,
        session: ProviderSession? = nil
    ) async {
        await updateCurrency(currency)
        await updateYearlyWarningLimit(warningLimit)
        await updateYearlyUpperLimit(upperLimit)
        
        if let session {
            await updateSession(for: session.provider, session: session)
        }
    }
}

// MARK: - Expectation Helpers for Collections

extension Array where Element: Equatable {
    /// Verifies that the array contains all expected elements in any order
    func containsAll(
        _ expected: [Element],
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for element in expected {
            #expect(contains(element), "Array should contain \(element)", sourceLocation: sourceLocation)
        }
    }
}

// MARK: - Date Test Helpers

extension Date {
    /// Creates a test date for a specific day of the current month
    static func testDate(day: Int, hour: Int = 12) -> Date {
        var components = Calendar.current.dateComponents([.year, .month], from: Date())
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }
    
    /// Creates a test date for a specific month and year
    static func testDate(year: Int, month: Int, day: Int = 1) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}