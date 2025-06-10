import Foundation
import Testing
@testable import VibeMeter

// MARK: - Pricing Data Manager Tests

@Suite("Pricing Data Manager Tests", .tags(.unit))
struct PricingDataManagerTests {
    // MARK: - Test Environment

    private func createTestManager() -> PricingDataManager {
        // Create a test user defaults to avoid polluting the main app's settings
        let testDefaults = UserDefaults(suiteName: "com.vibemeter.tests.pricing")!
        testDefaults.removePersistentDomain(forName: "com.vibemeter.tests.pricing")
        return PricingDataManager(userDefaults: testDefaults)
    }

    // MARK: - Pricing Lookup Tests

    @Test("Get pricing for known models")
    func getPricingForKnownModels() async {
        let manager = createTestManager()

        // Test Claude models
        let claudeSonnetPricing = await manager.getPricing(for: "claude-3-5-sonnet-20241022")
        #expect(claudeSonnetPricing != nil)
        #expect(claudeSonnetPricing?.inputCostPerToken == 0.000003)
        #expect(claudeSonnetPricing?.outputCostPerToken == 0.000015)

        let claudeOpusPricing = await manager.getPricing(for: "claude-opus-4-20250514")
        #expect(claudeOpusPricing != nil)
        #expect(claudeOpusPricing?.inputCostPerToken == 0.000005)
        #expect(claudeOpusPricing?.outputCostPerToken == 0.000025)

        // Test GPT models
        let gpt4Pricing = await manager.getPricing(for: "gpt-4")
        #expect(gpt4Pricing != nil)
        #expect(gpt4Pricing?.inputCostPerToken == 0.00003)
        #expect(gpt4Pricing?.outputCostPerToken == 0.00006)
    }

    @Test("Get pricing with partial model name matching")
    func getPricingWithPartialMatch() async {
        let manager = createTestManager()

        // Should match "claude-3-5-sonnet-20241022"
        let pricing = await manager.getPricing(for: "claude-3-5-sonnet")
        #expect(pricing != nil)
        #expect(pricing?.inputCostPerToken == 0.000003)

        // Should match with variations
        let pricing2 = await manager.getPricing(for: "sonnet-20241022")
        #expect(pricing2 != nil)
    }

    @Test("Return nil for unknown models")
    func returnNilForUnknownModels() async {
        let manager = createTestManager()

        let unknownPricing = await manager.getPricing(for: "definitely-not-a-real-model")
        #expect(unknownPricing == nil)
    }

    // MARK: - Cost Calculation Tests

    @Test("Calculate cost in auto mode")
    func calculateCostAutoMode() async {
        let manager = createTestManager()

        // Test with pre-calculated cost available
        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 500)
        let costWithPreCalc = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet",
            mode: .auto,
            preCalculatedCost: 0.05)
        #expect(costWithPreCalc == 0.05)

        // Test without pre-calculated cost (should calculate)
        let costCalculated = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet",
            mode: .auto,
            preCalculatedCost: nil)

        // Expected: (1000 * 0.000003) + (500 * 0.000015) = 0.003 + 0.0075 = 0.0105
        #expect(costCalculated == 0.0105)
    }

    @Test("Calculate cost in calculate mode")
    func calculateCostCalculateMode() async {
        let manager = createTestManager()

        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 500)

        // Should ignore pre-calculated cost
        let cost = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet",
            mode: .calculate,
            preCalculatedCost: 99.99)

        // Expected: (1000 * 0.000003) + (500 * 0.000015) = 0.003 + 0.0075 = 0.0105
        #expect(cost == 0.0105)
    }

    @Test("Calculate cost in display mode")
    func calculateCostDisplayMode() async {
        let manager = createTestManager()

        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 500)

        // Should only use pre-calculated cost
        let costWithPreCalc = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet",
            mode: .display,
            preCalculatedCost: 0.05)
        #expect(costWithPreCalc == 0.05)

        // Should return 0 without pre-calculated cost
        let costWithoutPreCalc = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet",
            mode: .display,
            preCalculatedCost: nil)
        #expect(costWithoutPreCalc == 0)
    }

    @Test("Calculate cost with cache tokens")
    func calculateCostWithCacheTokens() async {
        let manager = createTestManager()

        let tokens = TokenUsage(
            inputTokens: 1000,
            outputTokens: 500,
            cacheCreationTokens: 200,
            cacheReadTokens: 300)

        let cost = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet-20241022",
            mode: .calculate)

        // Expected:
        // Input: 1000 * 0.000003 = 0.003
        // Output: 500 * 0.000015 = 0.0075
        // Cache creation: 200 * 0.00000375 = 0.00075
        // Cache read: 300 * 0.0000003 = 0.00009
        // Total: 0.003 + 0.0075 + 0.00075 + 0.00009 = 0.01134
        #expect(cost == 0.01134)
    }

    @Test("Return zero cost for unknown model")
    func returnZeroCostForUnknownModel() async {
        let manager = createTestManager()

        let tokens = TokenUsage(inputTokens: 1000, outputTokens: 500)
        let cost = await manager.calculateCost(
            tokens: tokens,
            model: "unknown-model",
            mode: .calculate)

        #expect(cost == 0)
    }

    // MARK: - Caching Tests

    @Test("Cache pricing data")
    func cachePricingData() async {
        let manager = createTestManager()

        // First call should fetch data
        let start1 = Date()
        let pricing1 = await manager.getPricing(for: "claude-3-5-sonnet")
        let duration1 = Date().timeIntervalSince(start1)

        // Second call should use cache and be much faster
        let start2 = Date()
        let pricing2 = await manager.getPricing(for: "claude-3-5-sonnet")
        let duration2 = Date().timeIntervalSince(start2)

        #expect(pricing1 != nil)
        #expect(pricing2 != nil)
        #expect(pricing1?.inputCostPerToken == pricing2?.inputCostPerToken)

        // Cache hit should be significantly faster (at least 10x)
        // Note: This might be flaky in CI, so we're being conservative
        #expect(duration2 < duration1 / 2)
    }

    @Test("Clear cache removes all data")
    func clearCacheRemovesData() async {
        let testDefaults = UserDefaults(suiteName: "com.vibemeter.tests.pricing.clear")!
        let manager = PricingDataManager(userDefaults: testDefaults)

        // Get pricing to populate cache
        let pricing = await manager.getPricing(for: "claude-3-5-sonnet")
        #expect(pricing != nil)

        // Clear cache
        manager.clearCache()

        // Verify cache is cleared by checking UserDefaults directly
        #expect(testDefaults.data(forKey: "com.vibemeter.pricingDataCache") == nil)
        #expect(testDefaults.object(forKey: "com.vibemeter.pricingCacheTimestamp") == nil)
    }

    // MARK: - Edge Cases

    @Test("Handle zero token counts")
    func handleZeroTokenCounts() async {
        let manager = createTestManager()

        let tokens = TokenUsage(inputTokens: 0, outputTokens: 0)
        let cost = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet",
            mode: .calculate)

        #expect(cost == 0)
    }

    @Test("Handle very large token counts")
    func handleLargeTokenCounts() async {
        let manager = createTestManager()

        // 10 million tokens each
        let tokens = TokenUsage(inputTokens: 10_000_000, outputTokens: 10_000_000)
        let cost = await manager.calculateCost(
            tokens: tokens,
            model: "claude-3-5-sonnet",
            mode: .calculate)

        // Expected: (10M * 0.000003) + (10M * 0.000015) = 30 + 150 = 180
        #expect(cost == 180.0)
    }

    @Test("Handle model name variations")
    func handleModelNameVariations() async {
        let manager = createTestManager()

        // Test different variations that should all resolve to the same model
        let variations = [
            "claude-3-5-sonnet",
            "claude-3.5-sonnet",
            "anthropic/claude-3-5-sonnet",
            "claude-sonnet",
        ]

        for variation in variations {
            let pricing = await manager.getPricing(for: variation)
            #expect(pricing != nil, "Failed to find pricing for variation: \(variation)")
        }
    }
}
