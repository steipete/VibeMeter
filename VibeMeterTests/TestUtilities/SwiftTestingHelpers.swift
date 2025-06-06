import Foundation
import Testing
@testable import VibeMeter

// MARK: - Common Test Tags

extension Tag {
    // Functional areas
    @Tag static var currency: Self
    @Tag static var conversion: Self
    @Tag static var formatting: Self
    @Tag static var network: Self
    @Tag static var exchangeRates: Self
    @Tag static var async: Self
    @Tag static var integration: Self
    @Tag static var strings: Self
    @Tag static var truncation: Self
    @Tag static var edgeCases: Self
    @Tag static var status: Self
    @Tag static var ui: Self
    @Tag static var provider: Self
    @Tag static var performance: Self
    @Tag static var concurrency: Self
    
    // Test types
    @Tag static var unit: Self
    @Tag static var smoke: Self
    @Tag static var regression: Self
}

// MARK: - Common Test Helpers

struct TestHelpers {
    
    // MARK: - Date Helpers
    
    static func createDate(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components) ?? Date()
    }
    
    static func dateFromISO8601(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }
    
    // MARK: - Currency Helpers
    
    static func createMockExchangeRates() -> [String: Double] {
        [
            "USD": 1.0,
            "EUR": 0.92,
            "GBP": 0.82,
            "JPY": 149.50,
            "CHF": 0.88,
            "CAD": 1.35,
            "AUD": 1.52
        ]
    }
    
    static func createMockProviderSpendingData(
        provider: ServiceProvider = .cursor,
        currentSpendingUSD: Double = 123.45,
        warningLimitUSD: Double = 200.0,
        upperLimitUSD: Double = 500.0
    ) -> ProviderSpendingData {
        ProviderSpendingData(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            warningLimitConverted: warningLimitUSD,
            upperLimitConverted: upperLimitUSD
        )
    }
    
    static func createMockInvoice(
        provider: ServiceProvider = .cursor,
        totalCents: Int = 12345,
        month: Int = 12,
        year: Int = 2023
    ) -> ProviderMonthlyInvoice {
        ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: totalCents, description: "Test item", provider: provider)
            ],
            provider: provider,
            month: month,
            year: year
        )
    }
    
    // MARK: - Network Helpers
    
    static func createMockHTTPResponse(
        statusCode: Int,
        url: String = "https://example.com"
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
    }
    
    static func createMockJSONData<T: Codable>(_ object: T) throws -> Data {
        try JSONEncoder().encode(object)
    }
    
    // MARK: - String Helpers
    
    static func randomString(length: Int) -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).compactMap { _ in characters.randomElement() })
    }
    
    static func createLongString(baseString: String = "Test", repeats: Int = 1000) -> String {
        String(repeating: baseString + " ", count: repeats)
    }
    
    // MARK: - Async Test Helpers
    
    static func withTimeout<T>(
        _ seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async rethrows -> T {
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
    
    struct TimeoutError: Error {}
}

// MARK: - Custom Matchers and Expectations

extension TestHelpers {
    
    /// Verifies that a value is within a tolerance of an expected value
    static func expectApproximatelyEqual(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double = 0.01,
        _ comment: String = ""
    ) {
        let message = comment.isEmpty ? "Values should be approximately equal" : comment
        #expect(abs(actual - expected) < tolerance, "\(message): \(actual) ≈ \(expected)")
    }
    
    /// Verifies that a collection contains all expected elements
    static func expectContainsAll<T: Equatable>(
        _ collection: [T],
        _ expectedElements: [T],
        _ comment: String = ""
    ) {
        for element in expectedElements {
            let message = comment.isEmpty ? "Should contain \(element)" : "\(comment): Should contain \(element)"
            #expect(collection.contains(element), message)
        }
    }
    
    /// Verifies that an async operation completes within a time limit
    static func expectCompletesWithin<T>(
        _ timeLimit: TimeInterval,
        operation: @escaping () async throws -> T,
        _ comment: String = ""
    ) async rethrows -> T {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        
        let message = comment.isEmpty ? 
            "Operation should complete within \(timeLimit) seconds" : 
            "\(comment): Should complete within \(timeLimit) seconds"
        #expect(duration <= timeLimit, "\(message), but took \(duration) seconds")
        
        return result
    }
}

// MARK: - Common Test Data Structures

struct TestData {
    
    // Common currency codes for testing
    static let commonCurrencies = ["USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "SEK", "NOK", "DKK"]
    
    // Common error messages for testing
    static let networkErrorMessages = [
        "Network timeout",
        "Connection failed",
        "Service unavailable",
        "Rate limit exceeded",
        "Authentication failed",
        "Server error"
    ]
    
    // Common test amounts for currency testing
    static let testAmounts: [Double] = [
        0.0, 0.01, 0.99, 1.0, 10.0, 99.99, 100.0, 999.99, 1000.0, 
        9999.99, 10000.0, 99999.99, 100000.0, 1000000.0
    ]
    
    // Common test strings of various lengths
    static let testStrings = [
        "",
        "A",
        "AB",
        "ABC",
        "Short",
        "Medium length string",
        "This is a longer string for testing truncation",
        "This is a very long string that should definitely be truncated by any reasonable truncation algorithm because it exceeds normal display limits"
    ]
}

// MARK: - Performance Testing Helpers

struct PerformanceHelpers {
    
    /// Measures the execution time of a block
    static func measureTime<T>(
        _ operation: () throws -> T
    ) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(startTime)
        return (result, duration)
    }
    
    /// Measures the execution time of an async block
    static func measureTimeAsync<T>(
        _ operation: () async throws -> T
    ) async rethrows -> (result: T, duration: TimeInterval) {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        return (result, duration)
    }
    
    /// Runs a performance test with statistical analysis
    static func performanceTest<T>(
        iterations: Int = 100,
        warmupIterations: Int = 10,
        operation: () throws -> T
    ) rethrows -> PerformanceResult {
        // Warmup
        for _ in 0..<warmupIterations {
            _ = try operation()
        }
        
        // Measure
        var durations: [TimeInterval] = []
        for _ in 0..<iterations {
            let (_, duration) = measureTime(operation)
            durations.append(duration)
        }
        
        return PerformanceResult(durations: durations)
    }
}

struct PerformanceResult {
    let durations: [TimeInterval]
    
    var average: TimeInterval {
        durations.reduce(0, +) / Double(durations.count)
    }
    
    var minimum: TimeInterval {
        durations.min() ?? 0
    }
    
    var maximum: TimeInterval {
        durations.max() ?? 0
    }
    
    var standardDeviation: TimeInterval {
        let avg = average
        let sumOfSquaredDifferences = durations.reduce(0) { sum, duration in
            sum + pow(duration - avg, 2)
        }
        return sqrt(sumOfSquaredDifferences / Double(durations.count))
    }
}