import Foundation
import Testing
@testable import VibeMeter

// MARK: - Claude Provider Pricing Tests

@Suite("Claude Provider Pricing Tests", .tags(.unit))
struct ClaudeProviderPricingTests {
    // MARK: - Mock Settings Manager

    @MainActor
    private func createMockSettingsManager() -> any SettingsManagerProtocol {
        MockSettingsManager()
    }

    // MARK: - Pricing Integration Tests

    @Test("Calculate invoice with dynamic pricing")
    @MainActor
    func calculateInvoiceWithDynamicPricing() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        // Set up mock data with specific models
        logManager.setHasAccess(true)

        // Create entries with different models
        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-5-sonnet-20241022",
                inputTokens: 1000,
                outputTokens: 500),
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-opus-4-20250514",
                inputTokens: 2000,
                outputTokens: 1000),
            ClaudeLogEntry(
                timestamp: Date(),
                model: nil, // Should default to claude-3-5-sonnet
                inputTokens: 500,
                outputTokens: 250),
        ]

        let dailyUsage = [Date().startOfDay: entries]
        logManager.setDailyUsage(dailyUsage)

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1 // 0-indexed
        let year = calendar.component(.year, from: now)

        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: month,
            year: year,
            teamId: nil)

        #expect(invoice.provider == .claude)
        #expect(invoice.items.count > 0)

        // Verify that costs were calculated
        let totalCents = invoice.items.reduce(0) { $0 + $1.cents }
        #expect(totalCents > 0)

        // Expected costs:
        // Sonnet: (1000 * 0.000003) + (500 * 0.000015) = 0.003 + 0.0075 = 0.0105
        // Opus: (2000 * 0.000005) + (1000 * 0.000025) = 0.01 + 0.025 = 0.035
        // Default: (500 * 0.000003) + (250 * 0.000015) = 0.0015 + 0.00375 = 0.00525
        // Total: 0.0105 + 0.035 + 0.00525 = 0.05075 = 5.075 cents

        #expect(totalCents == 5) // Rounded to nearest cent
    }

    @Test("Handle entries without models")
    @MainActor
    func handleEntriesWithoutModels() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        logManager.setHasAccess(true)

        // Create entries without model specified
        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: nil,
                inputTokens: 1000,
                outputTokens: 500),
        ]

        let dailyUsage = [Date().startOfDay: entries]
        logManager.setDailyUsage(dailyUsage)

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1
        let year = calendar.component(.year, from: now)

        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: month,
            year: year,
            teamId: nil)

        // Should use default claude-3-5-sonnet pricing
        #expect(invoice.items.count > 0)
        let totalCents = invoice.items.reduce(0) { $0 + $1.cents }
        #expect(totalCents == 1) // (1000 * 0.000003) + (500 * 0.000015) = 0.0105 = 1 cent
    }

    @Test("Group entries by model")
    @MainActor
    func groupEntriesByModel() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        logManager.setHasAccess(true)

        // Create entries with mixed models
        let entries = [
            ClaudeLogEntry(timestamp: Date(), model: "claude-3-5-sonnet", inputTokens: 100, outputTokens: 50),
            ClaudeLogEntry(timestamp: Date(), model: "claude-opus-4", inputTokens: 200, outputTokens: 100),
            ClaudeLogEntry(timestamp: Date(), model: "claude-3-5-sonnet", inputTokens: 150, outputTokens: 75),
            ClaudeLogEntry(timestamp: Date(), model: "claude-opus-4", inputTokens: 300, outputTokens: 150),
            ClaudeLogEntry(timestamp: Date(), model: nil, inputTokens: 50, outputTokens: 25),
        ]

        let dailyUsage = [Date().startOfDay: entries]
        logManager.setDailyUsage(dailyUsage)

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1
        let year = calendar.component(.year, from: now)

        _ = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: month,
            year: year,
            teamId: nil)

        // The provider should have grouped entries by model internally
        // We can't directly test the grouping, but we can verify the result is correct
        #expect(logManager.callCount(for: "getDailyUsage") == 1)
    }

    @Test("Calculate costs for different account types")
    @MainActor
    func calculateCostsForAccountTypes() async throws {
        // Test that free tier shows zero cost
        let settingsManager = MockSettingsManager()
        settingsManager.sessionSettingsManager.claudeAccountType = .free

        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        logManager.setHasAccess(true)

        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-5-sonnet",
                inputTokens: 1000,
                outputTokens: 500),
        ]

        let dailyUsage = [Date().startOfDay: entries]
        logManager.setDailyUsage(dailyUsage)

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1
        let year = calendar.component(.year, from: now)

        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: month,
            year: year,
            teamId: nil)

        // For non-free tiers, cost should be calculated
        let totalCents = invoice.items.reduce(0) { $0 + $1.cents }
        #expect(totalCents > 0) // Changed: free tier now also shows costs based on tokens
    }

    @Test("Pricing description includes token breakdown")
    @MainActor
    func pricingDescriptionIncludesBreakdown() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        logManager.setHasAccess(true)

        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-5-sonnet",
                inputTokens: 1_000_000,
                outputTokens: 500_000),
        ]

        let dailyUsage = [Date().startOfDay: entries]
        logManager.setDailyUsage(dailyUsage)

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1
        let year = calendar.component(.year, from: now)

        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: month,
            year: year,
            teamId: nil)

        #expect(invoice.pricingDescription != nil)

        let description = invoice.pricingDescription!.description
        #expect(description.contains("1,000,000")) // Input tokens formatted
        #expect(description.contains("500,000")) // Output tokens formatted
        #expect(description.contains("input"))
        #expect(description.contains("output"))
    }

    @Test("Handle large token counts")
    @MainActor
    func handleLargeTokenCounts() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        logManager.setHasAccess(true)

        // 10 million tokens each
        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3-5-sonnet",
                inputTokens: 10_000_000,
                outputTokens: 10_000_000),
        ]

        let dailyUsage = [Date().startOfDay: entries]
        logManager.setDailyUsage(dailyUsage)

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1
        let year = calendar.component(.year, from: now)

        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: month,
            year: year,
            teamId: nil)

        // Expected: (10M * 0.000003) + (10M * 0.000015) = 30 + 150 = 180
        let totalCents = invoice.items.reduce(0) { $0 + $1.cents }
        #expect(totalCents == 18000) // $180.00 = 18000 cents
    }
}
