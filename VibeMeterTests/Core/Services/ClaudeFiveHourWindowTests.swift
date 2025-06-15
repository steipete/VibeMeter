import XCTest
@testable import VibeMeter

final class ClaudeFiveHourWindowTests: XCTestCase {
    
    // MARK: - Properties
    
    private var calculator: ClaudeFiveHourWindowCalculator!
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        calculator = ClaudeFiveHourWindowCalculator()
    }
    
    // MARK: - Basic Window Calculations
    
    func testEmptyWindow() {
        let window = calculator.calculateFiveHourWindow(from: [:])
        
        XCTAssertEqual(window.tokensUsed, 0)
        XCTAssertEqual(window.percentageUsed, 0.0)
        XCTAssertEqual(window.used, 0.0)
        XCTAssertEqual(window.total, 100.0)
    }
    
    func testSingleEntryWithinWindow() {
        let now = Date()
        let entry = ClaudeLogEntry(
            timestamp: now.addingTimeInterval(-60), // 1 minute ago
            model: "claude-3-5-sonnet-latest",
            inputTokens: 1000,
            outputTokens: 500,
            projectId: nil,
            id: "test-1"
        )
        
        let dailyUsage = [Calendar.current.startOfDay(for: now): [entry]]
        let window = calculator.calculateFiveHourWindow(from: dailyUsage)
        
        XCTAssertEqual(window.tokensUsed, 1500) // 1000 + 500
        XCTAssertGreaterThan(window.percentageUsed, 0)
        XCTAssertLessThan(window.percentageUsed, 100)
    }
    
    func testMultipleEntriesWithinWindow() {
        let now = Date()
        let entries = [
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-30 * 60), // 30 minutes ago
                model: "claude-3-5-sonnet-latest",
                inputTokens: 10_000,
                outputTokens: 5_000,
                projectId: nil,
                id: "test-1"
            ),
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-60 * 60), // 1 hour ago
                model: "claude-3-5-sonnet-latest",
                inputTokens: 20_000,
                outputTokens: 10_000,
                projectId: nil,
                id: "test-2"
            ),
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-120 * 60), // 2 hours ago
                model: "claude-3-5-sonnet-latest",
                inputTokens: 30_000,
                outputTokens: 15_000,
                projectId: nil,
                id: "test-3"
            )
        ]
        
        let dailyUsage = [Calendar.current.startOfDay(for: now): entries]
        let window = calculator.calculateFiveHourWindow(from: dailyUsage)
        
        // Total: 10k + 5k + 20k + 10k + 30k + 15k = 90k tokens
        XCTAssertEqual(window.tokensUsed, 90_000)
        XCTAssertGreaterThan(window.percentageUsed, 0)
    }
    
    // MARK: - Window Boundary Tests
    
    func testEntriesOutsideWindow() {
        let now = Date()
        let entries = [
            // Within window
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-2 * 60 * 60), // 2 hours ago
                model: "claude-3-5-sonnet-latest",
                inputTokens: 10_000,
                outputTokens: 5_000,
                projectId: nil,
                id: "test-1"
            ),
            // Outside window
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-6 * 60 * 60), // 6 hours ago
                model: "claude-3-5-sonnet-latest",
                inputTokens: 20_000,
                outputTokens: 10_000,
                projectId: nil,
                id: "test-2"
            )
        ]
        
        let dailyUsage = [Calendar.current.startOfDay(for: now): entries]
        let window = calculator.calculateFiveHourWindow(from: dailyUsage)
        
        // Only the first entry (15k tokens) should be counted
        XCTAssertEqual(window.tokensUsed, 15_000)
    }
    
    func testEntriesAtWindowBoundary() {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        
        let entries = [
            // Exactly 5 hours ago (should be excluded)
            ClaudeLogEntry(
                timestamp: fiveHoursAgo,
                model: "claude-3-5-sonnet-latest",
                inputTokens: 1000,
                outputTokens: 1000,
                projectId: nil,
                id: "test-1"
            ),
            // Just inside the window
            ClaudeLogEntry(
                timestamp: fiveHoursAgo.addingTimeInterval(1), // 1 second after boundary
                model: "claude-3-5-sonnet-latest",
                inputTokens: 2000,
                outputTokens: 2000,
                projectId: nil,
                id: "test-2"
            )
        ]
        
        let dailyUsage = [Calendar.current.startOfDay(for: now): entries]
        let window = calculator.calculateFiveHourWindow(from: dailyUsage)
        
        // Only the second entry should be counted
        XCTAssertEqual(window.tokensUsed, 4000)
    }
    
    // MARK: - Cross-Day Boundaries
    
    func testEntriesAcrossDayBoundary() {
        let now = Date()
        let calendar = Calendar.current
        
        // Create entries spanning yesterday and today
        let todayStart = calendar.startOfDay(for: now)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart)!
        
        let yesterdayEntries = [
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-3 * 60 * 60), // 3 hours ago (might be yesterday)
                model: "claude-3-5-sonnet-latest",
                inputTokens: 5000,
                outputTokens: 2500,
                projectId: nil,
                id: "yesterday-1"
            )
        ]
        
        let todayEntries = [
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-1 * 60 * 60), // 1 hour ago (today)
                model: "claude-3-5-sonnet-latest",
                inputTokens: 3000,
                outputTokens: 1500,
                projectId: nil,
                id: "today-1"
            )
        ]
        
        // Check if entries actually span days
        let yesterdayEntry = yesterdayEntries[0]
        if calendar.isDate(yesterdayEntry.timestamp, inSameDayAs: now) {
            // If 3 hours ago is still today, both entries are from today
            let dailyUsage = [todayStart: yesterdayEntries + todayEntries]
            let window = calculator.calculateFiveHourWindow(from: dailyUsage)
            XCTAssertEqual(window.tokensUsed, 12_000) // 7500 + 4500
        } else {
            // Entries span two days
            let dailyUsage = [
                yesterdayStart: yesterdayEntries,
                todayStart: todayEntries
            ]
            let window = calculator.calculateFiveHourWindow(from: dailyUsage)
            XCTAssertEqual(window.tokensUsed, 12_000) // Both should be within 5-hour window
        }
    }
    
    // MARK: - Token Limit Calculations
    
    func testEstimatedTokenLimit() {
        // Test that estimated token limit is calculated based on model
        let now = Date()
        let entries = [
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-60),
                model: "claude-3-5-sonnet-latest",
                inputTokens: 50_000,
                outputTokens: 25_000,
                projectId: nil,
                id: "test-1"
            )
        ]
        
        let dailyUsage = [Calendar.current.startOfDay(for: now): entries]
        let window = calculator.calculateFiveHourWindow(from: dailyUsage)
        
        // For Claude Pro accounts, should estimate a reasonable limit
        XCTAssertGreaterThan(window.estimatedTokenLimit, 0)
        XCTAssertGreaterThan(window.estimatedTokenLimit, window.tokensUsed)
    }
    
    // MARK: - Percentage Calculations
    
    func testPercentageCalculations() {
        let now = Date()
        
        // Test various usage levels
        let testCases: [(tokens: Int, expectedRange: ClosedRange<Double>)] = [
            (10_000, 0...10),      // Low usage
            (100_000, 10...50),    // Medium usage
            (500_000, 50...100),   // High usage
            (1_000_000, 90...100)  // Very high usage
        ]
        
        for testCase in testCases {
            let entry = ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-60),
                model: "claude-3-5-sonnet-latest",
                inputTokens: testCase.tokens / 2,
                outputTokens: testCase.tokens / 2,
                projectId: nil,
                id: "test-\(testCase.tokens)"
            )
            
            let dailyUsage = [Calendar.current.startOfDay(for: now): [entry]]
            let window = calculator.calculateFiveHourWindow(from: dailyUsage)
            
            XCTAssertTrue(
                testCase.expectedRange.contains(window.percentageUsed),
                "Percentage \(window.percentageUsed) not in expected range \(testCase.expectedRange) for \(testCase.tokens) tokens"
            )
        }
    }
    
    // MARK: - Reset Date Calculations
    
    func testResetDateCalculation() {
        let now = Date()
        let window = calculator.calculateFiveHourWindow(from: [:])
        
        // Reset date should be approximately 5 hours from now
        let expectedResetDate = now.addingTimeInterval(5 * 60 * 60)
        let timeDifference = abs(window.resetDate.timeIntervalSince(expectedResetDate))
        
        // Allow for some calculation time difference (within 60 seconds)
        XCTAssertLessThan(timeDifference, 60)
    }
    
    // MARK: - Performance
    
    func testPerformanceWithManyEntries() {
        let now = Date()
        var entries: [ClaudeLogEntry] = []
        
        // Create 1000 entries within the 5-hour window
        for i in 0..<1000 {
            let timestamp = now.addingTimeInterval(Double(-i * 10)) // Every 10 seconds
            let entry = ClaudeLogEntry(
                timestamp: timestamp,
                model: "claude-3-5-sonnet-latest",
                inputTokens: 100,
                outputTokens: 50,
                projectId: nil,
                id: "test-\(i)"
            )
            entries.append(entry)
        }
        
        let dailyUsage = [Calendar.current.startOfDay(for: now): entries]
        
        measure {
            _ = calculator.calculateFiveHourWindow(from: dailyUsage)
        }
    }
}