import Foundation
import Testing
@testable import VibeMeter

// MARK: - Claude 5-Hour Window Tests

@Suite("Claude 5-Hour Window Tests", .tags(.claude))
struct ClaudeFiveHourWindowTests {
    
    // MARK: - Test Helpers
    
    private func createLogEntry(
        hoursAgo: Double,
        inputTokens: Int = 1000,
        outputTokens: Int = 500
    ) -> ClaudeLogEntry {
        ClaudeLogEntry(
            timestamp: Date().addingTimeInterval(-hoursAgo * 3600),
            model: "claude-3.5-sonnet",
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
    }
    
    private func createDailyUsage(entries: [ClaudeLogEntry]) -> [Date: [ClaudeLogEntry]] {
        var usage: [Date: [ClaudeLogEntry]] = [:]
        for entry in entries {
            let day = Calendar.current.startOfDay(for: entry.timestamp)
            usage[day, default: []].append(entry)
        }
        return usage
    }
    
    // MARK: - Window Calculation Tests
    
    @Test("Calculate 5-hour window with recent usage")
    @MainActor
    func calculateFiveHourWindowWithRecentUsage() async {
        let logManager = ClaudeLogManagerMock()
        
        // Create entries: some within 5 hours, some outside
        let entries = [
            createLogEntry(hoursAgo: 1, inputTokens: 1000, outputTokens: 500),   // Recent
            createLogEntry(hoursAgo: 3, inputTokens: 2000, outputTokens: 1000),  // Recent
            createLogEntry(hoursAgo: 4.5, inputTokens: 1500, outputTokens: 750), // Recent
            createLogEntry(hoursAgo: 6, inputTokens: 3000, outputTokens: 1500),  // Old
            createLogEntry(hoursAgo: 24, inputTokens: 5000, outputTokens: 2500), // Old
        ]
        
        let dailyUsage = createDailyUsage(entries: entries)
        
        // Mock Pro account (uses 5-hour window)
        let mockSettings = MockSettingsManager()
        mockSettings.sessionSettingsManager.claudeAccountType = .pro
        _ = ClaudeLogManager(
            fileManager: .default,
            userDefaults: .standard
        )
        
        // Calculate window
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        
        // Pro tier has estimated token limit based on messages
        // Recent entries: 4500 input + 2250 output = 6750 total tokens
        #expect(window.used > 0)
        #expect(window.used <= 100)
        #expect(window.total == 100)
        #expect(window.resetDate > Date())
    }
    
    @Test("Calculate 5-hour window with no recent usage")
    @MainActor
    func calculateFiveHourWindowNoRecentUsage() async {
        let logManager = ClaudeLogManagerMock()
        
        // All entries older than 5 hours
        let entries = [
            createLogEntry(hoursAgo: 6, inputTokens: 3000, outputTokens: 1500),
            createLogEntry(hoursAgo: 12, inputTokens: 2000, outputTokens: 1000),
            createLogEntry(hoursAgo: 24, inputTokens: 5000, outputTokens: 2500),
        ]
        
        let dailyUsage = createDailyUsage(entries: entries)
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        
        #expect(window.used == 0)
        #expect(window.total == 100)
        #expect(window.percentageUsed == 0)
        #expect(!window.isExhausted)
    }
    
    @Test("Calculate 5-hour window at capacity")
    @MainActor
    func calculateFiveHourWindowAtCapacity() async {
        let logManager = ClaudeLogManagerMock()
        
        // Create many recent entries to simulate hitting the limit
        var entries: [ClaudeLogEntry] = []
        for i in 0..<50 {
            entries.append(createLogEntry(
                hoursAgo: Double(i) * 0.1, // Spread over 5 hours
                inputTokens: 5000,
                outputTokens: 2500
            ))
        }
        
        let dailyUsage = createDailyUsage(entries: entries)
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        
        // Should be at or near 100%
        #expect(window.used >= 95)
        #expect(window.used <= 100)
        #expect(window.percentageUsed >= 95)
    }
    
    // MARK: - Account Type Tests
    
    @Test("Calculate window for free tier uses daily limit")
    @MainActor
    func calculateWindowForFreeTier() async {
        let logManager = ClaudeLogManagerMock()
        
        // Create entries throughout the day
        let entries = [
            createLogEntry(hoursAgo: 1),
            createLogEntry(hoursAgo: 6),
            createLogEntry(hoursAgo: 12),
            createLogEntry(hoursAgo: 18),
        ]
        
        let dailyUsage = createDailyUsage(entries: entries)
        
        // Mock free account
        logManager.mockAccountType = .free
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        
        // Free tier uses daily message count
        // 4 messages out of default 50 daily limit = 8%
        #expect(window.used == 8)
        #expect(window.total == 100)
        
        // Reset should be at midnight PT
        let calendar = Calendar.current
        _ = calendar.component(.hour, from: window.resetDate)
        let resetTimeZone = TimeZone(identifier: "America/Los_Angeles")!
        let resetComponents = calendar.dateComponents(in: resetTimeZone, from: window.resetDate)
        #expect(resetComponents.hour == 0)
    }
    
    @Test("Calculate window for different subscription tiers", arguments: [
        ClaudePricingTier.free,
        ClaudePricingTier.pro,
        ClaudePricingTier.max100,
        ClaudePricingTier.max200
    ])
    @MainActor
    func calculateWindowForSubscriptionTier(accountType: ClaudePricingTier) async {
        let logManager = ClaudeLogManagerMock()
        logManager.mockAccountType = accountType
        
        // Create consistent usage
        let entries = (0..<10).map { i in
            createLogEntry(hoursAgo: Double(i) * 0.5, inputTokens: 1000, outputTokens: 500)
        }
        
        let dailyUsage = createDailyUsage(entries: entries)
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        
        #expect(window.total == 100)
        
        if accountType.usesFiveHourWindow {
            // Pro/Max tiers use 5-hour window
            #expect(window.resetDate > Date())
            #expect(window.resetDate <= Date().addingTimeInterval(5 * 3600))
        } else {
            // Free tier uses daily reset
            let calendar = Calendar.current
            let tomorrow = calendar.startOfDay(for: Date()).addingTimeInterval(24 * 3600)
            #expect(window.resetDate >= tomorrow)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Calculate window with empty usage data")
    @MainActor
    func calculateWindowWithEmptyData() async {
        let logManager = ClaudeLogManagerMock()
        let window = logManager.calculateFiveHourWindow(from: [:])
        
        #expect(window.used == 0)
        #expect(window.total == 100)
        #expect(window.remaining == 100)
        #expect(!window.isExhausted)
    }
    
    @Test("Calculate window with entries at exact 5-hour boundary")
    @MainActor
    func calculateWindowAtExactBoundary() async {
        let logManager = ClaudeLogManagerMock()
        
        // Entry at exactly 5 hours ago should be excluded
        let entries = [
            createLogEntry(hoursAgo: 4.99, inputTokens: 1000, outputTokens: 500),  // Included
            createLogEntry(hoursAgo: 5.0, inputTokens: 2000, outputTokens: 1000),   // Excluded
            createLogEntry(hoursAgo: 5.01, inputTokens: 1500, outputTokens: 750),  // Excluded
        ]
        
        let dailyUsage = createDailyUsage(entries: entries)
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        
        // Only the first entry should be counted
        #expect(window.used > 0)
        #expect(window.used < 50) // Should be relatively low usage
    }
    
    @Test("Window reset date calculation")
    @MainActor
    func windowResetDateCalculation() async {
        let logManager = ClaudeLogManagerMock()
        
        // Create entry 3 hours ago
        let entries = [createLogEntry(hoursAgo: 3)]
        let dailyUsage = createDailyUsage(entries: entries)
        
        // Pro account
        logManager.mockAccountType = .pro
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        
        // Reset should be ~2 hours from now (5 - 3)
        let timeUntilReset = window.resetDate.timeIntervalSince(Date())
        #expect(timeUntilReset > 1.5 * 3600)
        #expect(timeUntilReset < 2.5 * 3600)
    }
    
    // MARK: - Performance Tests
    
    @Test("Calculate window with large dataset")
    @MainActor
    func calculateWindowPerformance() async {
        let logManager = ClaudeLogManagerMock()
        
        // Create a large number of entries
        var entries: [ClaudeLogEntry] = []
        for day in 0..<30 {
            for hour in 0..<24 {
                entries.append(createLogEntry(
                    hoursAgo: Double(day * 24 + hour),
                    inputTokens: Int.random(in: 100...5000),
                    outputTokens: Int.random(in: 50...2500)
                ))
            }
        }
        
        let dailyUsage = createDailyUsage(entries: entries)
        
        // Should handle large datasets efficiently
        let startTime = Date()
        let window = logManager.calculateFiveHourWindow(from: dailyUsage)
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        #expect(elapsedTime < 0.1) // Should complete quickly
        #expect(window.used >= 0)
        #expect(window.used <= 100)
    }
}

// MARK: - Window Display Tests

@Suite("Claude Window Display Tests", .tags(.ui))
struct ClaudeWindowDisplayTests {
    
    @Test("Format window percentage for display")
    func formatWindowPercentage() {
        let testCases: [(used: Double, expected: String)] = [
            (0, "0%"),
            (25.5, "26%"),
            (50, "50%"),
            (99.9, "100%"),
            (100, "100%"),
        ]
        
        for (used, expected) in testCases {
            let window = FiveHourWindow(used: used, total: 100, resetDate: Date())
            let formatted = String(format: "%.0f%%", window.percentageUsed)
            #expect(formatted == expected)
        }
    }
    
    @Test("Format time until reset")
    func formatTimeUntilReset() {
        let testCases: [(hours: Double, expectedPattern: String)] = [
            (0.1, "6 minutes"),
            (0.5, "30 minutes"),
            (1, "1 hour"),
            (2.5, "2 hours"),
            (4.75, "4 hours"),
        ]
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        for (hours, expectedPattern) in testCases {
            let resetDate = Date().addingTimeInterval(hours * 3600)
            let window = FiveHourWindow(used: 50, total: 100, resetDate: resetDate)
            
            let formatted = formatter.localizedString(for: window.resetDate, relativeTo: Date())
            #expect(formatted.contains(expectedPattern))
        }
    }
    
    @Test("Window state descriptions")
    func windowStateDescriptions() {
        // Available
        let available = FiveHourWindow(used: 25, total: 100, resetDate: Date().addingTimeInterval(3600))
        #expect(!available.isExhausted)
        #expect(available.remaining == 75)
        
        // Warning threshold (>80%)
        let warning = FiveHourWindow(used: 85, total: 100, resetDate: Date().addingTimeInterval(3600))
        #expect(!warning.isExhausted)
        #expect(warning.percentageUsed > 80)
        
        // Exhausted
        let exhausted = FiveHourWindow(used: 100, total: 100, resetDate: Date().addingTimeInterval(3600))
        #expect(exhausted.isExhausted)
        #expect(exhausted.remaining == 0)
    }
}
