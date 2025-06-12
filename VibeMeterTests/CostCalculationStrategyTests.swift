import Foundation
import Testing
@testable import VibeMeter

@Suite("Cost Calculation Strategy Tests")
struct CostCalculationStrategyTests {
    @Test("Cost calculation with auto strategy")
    func autoStrategy() {
        // Entry with predefined cost
        let entryWithCost = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-5-sonnet",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: 5.25)

        // Entry without predefined cost
        let entryWithoutCost = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-5-sonnet",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: nil)

        // Auto strategy should use predefined cost when available
        #expect(entryWithCost.calculateCost(strategy: .auto) == 5.25)

        // Auto strategy should calculate when no predefined cost
        let calculatedCost = entryWithoutCost.calculateCost(strategy: .auto)
        #expect(calculatedCost > 0)
        // Expected: (1000 / 1M * $3) + (500 / 1M * $15) = $0.003 + $0.0075 = $0.0105
        #expect(abs(calculatedCost - 0.0105) < 0.0001)
    }

    @Test("Cost calculation with calculate strategy")
    func calculateStrategy() {
        // Entry with predefined cost
        let entry = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-5-sonnet",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: 5.25 // This should be ignored
        )

        // Calculate strategy should always calculate from tokens
        let calculatedCost = entry.calculateCost(strategy: .calculate)
        #expect(calculatedCost != 5.25) // Should not use predefined
        #expect(abs(calculatedCost - 0.0105) < 0.0001) // Should be calculated value
    }

    @Test("Cost calculation with display strategy")
    func displayStrategy() {
        // Entry with predefined cost
        let entryWithCost = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-5-sonnet",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: 5.25)

        // Entry without predefined cost
        let entryWithoutCost = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-5-sonnet",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: nil)

        // Display strategy should only use predefined cost
        #expect(entryWithCost.calculateCost(strategy: .display) == 5.25)
        #expect(entryWithoutCost.calculateCost(strategy: .display) == 0.0) // No cost = 0
    }

    @Test("Cost calculation for different models")
    func differentModelPricing() {
        // Opus model (more expensive)
        let opusEntry = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-opus-4-20250514",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: nil)

        // Haiku model (cheaper)
        let haikuEntry = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-haiku",
            inputTokens: 1000,
            outputTokens: 500,
            costUSD: nil)

        let opusCost = opusEntry.calculateCost(strategy: .calculate)
        let haikuCost = haikuEntry.calculateCost(strategy: .calculate)

        // Opus should be more expensive than Haiku
        #expect(opusCost > haikuCost)

        // Verify specific costs
        // Opus: (1000 / 1M * $15) + (500 / 1M * $75) = $0.015 + $0.0375 = $0.0525
        #expect(opusCost == 0.0525)

        // Haiku: (1000 / 1M * $0.25) + (500 / 1M * $1.25) = $0.00025 + $0.000625 = $0.000875
        #expect(haikuCost == 0.000875)
    }

    @Test("Cost calculation with cache tokens")
    func cacheTokenCosts() {
        let entry = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-5-sonnet",
            inputTokens: 1000,
            outputTokens: 500,
            cacheCreationTokens: 2000,
            cacheReadTokens: 5000,
            costUSD: nil)

        let cost = entry.calculateCost(strategy: .calculate)

        // Should include cache token costs
        // Input: 1000 / 1M * $3 = $0.003
        // Output: 500 / 1M * $15 = $0.0075
        // Cache Write: 2000 / 1M * $3.75 = $0.0075
        // Cache Read: 5000 / 1M * $0.30 = $0.0015
        // Total: $0.003 + $0.0075 + $0.0075 + $0.0015 = $0.0195
        #expect(cost == 0.0195)
    }

    @Test("Daily usage cost aggregation")
    func dailyUsageCostAggregation() {
        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-5-sonnet",
                inputTokens: 1000,
                outputTokens: 500,
                costUSD: 2.0),
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-5-sonnet",
                inputTokens: 2000,
                outputTokens: 1000,
                costUSD: nil // Will be calculated
            ),
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-5-sonnet",
                inputTokens: 500,
                outputTokens: 250,
                costUSD: 1.5),
        ]

        let dailyUsage = ClaudeDailyUsage(date: Date(), entries: entries)

        // Test auto strategy (mix of predefined and calculated)
        let autoCost = dailyUsage.calculateCost(strategy: .auto)
        // First: 2.0 (predefined)
        // Second: (2000/1M * 3) + (1000/1M * 15) = 0.006 + 0.015 = 0.021 (calculated)
        // Third: 1.5 (predefined)
        // Total: 2.0 + 0.021 + 1.5 = 3.521
        #expect(autoCost == 3.521)

        // Test calculate strategy (all calculated)
        let calculateCost = dailyUsage.calculateCost(strategy: .calculate)
        // First: (1000/1M * 3) + (500/1M * 15) = 0.003 + 0.0075 = 0.0105
        // Second: 0.021 (as above)
        // Third: (500/1M * 3) + (250/1M * 15) = 0.0015 + 0.00375 = 0.00525
        // Total: 0.0105 + 0.021 + 0.00525 = 0.03675
        #expect(calculateCost == 0.03675)

        // Test display strategy (only predefined)
        let displayCost = dailyUsage.calculateCost(strategy: .display)
        // First: 2.0, Second: 0.0, Third: 1.5
        // Total: 3.5
        #expect(displayCost == 3.5)
    }
}
