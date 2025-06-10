import Foundation
import Testing
@testable import VibeMeter

// MARK: - Common Test Helpers

public enum TestHelpers {
    // MARK: - Date Helpers

    public static func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }

    public static func dateFromISO8601(_ string: String) -> Date? {
        ISO8601DateFormatter.vibeMeterDefault.date(from: string)
    }

    // MARK: - Currency Helpers

    public static func createMockExchangeRates() -> [String: Double] {
        [
            "USD": 1.0,
            "EUR": 0.92,
            "GBP": 0.82,
            "JPY": 149.50,
            "CHF": 0.88,
            "CAD": 1.35,
            "AUD": 1.52,
        ]
    }

    public static func createMockProviderSpendingData(
        provider: ServiceProvider = .cursor,
        currentSpendingUSD: Double = 123.45,
        warningLimitUSD: Double = 200.0,
        upperLimitUSD: Double = 500.0) -> ProviderSpendingData {
        ProviderSpendingData(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            warningLimitConverted: warningLimitUSD,
            upperLimitConverted: upperLimitUSD)
    }

    public static func createMockInvoice(
        provider: ServiceProvider = .cursor,
        totalCents: Int = 12345,
        month: Int = 12,
        year: Int = 2023) -> ProviderMonthlyInvoice {
        ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: totalCents, description: "Test item", provider: provider),
            ],
            provider: provider,
            month: month,
            year: year)
    }

    // MARK: - Network Helpers

    public static func createMockHTTPResponse(
        statusCode: Int,
        url: String = "https://example.com") -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil)!
    }

    public static func createMockJSONData(_ object: some Codable) throws -> Data {
        try JSONEncoder().encode(object)
    }

    // MARK: - String Helpers

    public static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0 ..< length).compactMap { _ in characters.randomElement() })
    }

    public static func createLongString(baseString: String = "Test", repeats: Int = 1000) -> String {
        String(repeating: baseString + " ", count: repeats)
    }

    // MARK: - Async Test Helpers

    public static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T) async rethrows -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }

            defer { group.cancelAll() }
            return try await group.next()!
        }
    }

    public struct TimeoutError: Error {}

    // MARK: - Performance Testing Helpers

    public static func measureTime<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(startTime)
        return (result, duration)
    }

    public static func measureTimeAsync<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T) async rethrows -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        return (result, duration)
    }
}

// MARK: - Custom Expectations

public extension TestHelpers {
    /// Verifies that a value is within a tolerance of an expected value
    static func expectApproximatelyEqual(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double = 0.01) {
        #expect(abs(actual - expected) < tolerance)
    }

    /// Verifies that a collection contains all expected elements
    static func expectContainsAll<T: Equatable & Sendable>(
        _ collection: [T],
        _ expectedElements: [T]) {
        for element in expectedElements {
            #expect(collection.contains(element))
        }
    }
}

// MARK: - Common Test Data

public enum TestData {
    // Common currency codes for testing
    public static let commonCurrencies = ["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "SEK", "NOK", "DKK"]

    // Common error messages for testing
    public static let networkErrorMessages = [
        "Network timeout",
        "Connection failed",
        "Service unavailable",
        "Rate limit exceeded",
        "Authentication failed",
        "Server error",
    ]

    // Common test amounts for currency testing
    public static let testAmounts: [Double] = [
        0.0, 0.01, 0.99, 1.0, 10.0, 99.99, 100.0, 999.99, 1000.0,
        9999.99, 10000.0, 99999.99, 100_000.0, 1_000_000.0,
    ]

    // Common test strings of various lengths
    public static let testStrings = [
        "",
        "A",
        "AB",
        "ABC",
        "Short",
        "Medium length string",
        "This is a longer string for testing truncation",
        "This is a very long string that should definitely be truncated by any reasonable truncation algorithm " +
            "because it exceeds normal display limits",
    ]
}
