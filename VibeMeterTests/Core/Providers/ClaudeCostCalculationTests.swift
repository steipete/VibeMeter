import XCTest
@testable import VibeMeter

final class ClaudeCostCalculationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var pricingManager: PricingDataManager!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        pricingManager = PricingDataManager.shared
    }
    
    // MARK: - Basic Cost Calculations
    
    func testSmallTokenCostCalculation() async {
        // Test small amounts that previously showed as $0
        let usage = TokenUsage(inputTokens: 146, outputTokens: 120)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-5-sonnet-latest",
            mode: .calculate
        )
        
        // Claude 3.5 Sonnet: $3/1M input, $15/1M output
        // Expected: (146 * 3 / 1_000_000) + (120 * 15 / 1_000_000) = 0.000438 + 0.0018 = 0.002238
        XCTAssertGreaterThan(cost, 0)
        XCTAssertLessThan(cost, 0.01)
        XCTAssertEqual(cost, 0.002238, accuracy: 0.000001)
    }
    
    func testMediumTokenCostCalculation() async {
        // Test medium amounts
        let usage = TokenUsage(inputTokens: 10_000, outputTokens: 5_000)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-5-sonnet-latest",
            mode: .calculate
        )
        
        // Expected: (10_000 * 3 / 1_000_000) + (5_000 * 15 / 1_000_000) = 0.03 + 0.075 = 0.105
        XCTAssertEqual(cost, 0.105, accuracy: 0.001)
    }
    
    func testLargeTokenCostCalculation() async {
        // Test large amounts (full context window)
        let usage = TokenUsage(inputTokens: 200_000, outputTokens: 50_000)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-5-sonnet-latest",
            mode: .calculate
        )
        
        // Expected: (200_000 * 3 / 1_000_000) + (50_000 * 15 / 1_000_000) = 0.6 + 0.75 = 1.35
        XCTAssertEqual(cost, 1.35, accuracy: 0.01)
    }
    
    // MARK: - Different Model Pricing
    
    func testClaudeHaikuPricing() async {
        let usage = TokenUsage(inputTokens: 10_000, outputTokens: 10_000)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-haiku",
            mode: .calculate
        )
        
        // Haiku is cheaper: $0.25/1M input, $1.25/1M output
        // Expected: (10_000 * 0.25 / 1_000_000) + (10_000 * 1.25 / 1_000_000) = 0.015
        XCTAssertLessThan(cost, 0.02)
    }
    
    func testClaudeOpusPricing() async {
        let usage = TokenUsage(inputTokens: 10_000, outputTokens: 10_000)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-opus",
            mode: .calculate
        )
        
        // Opus is more expensive: $15/1M input, $75/1M output
        // Expected: (10_000 * 15 / 1_000_000) + (10_000 * 75 / 1_000_000) = 0.9
        XCTAssertGreaterThan(cost, 0.5)
    }
    
    // MARK: - Cost Formatting
    
    func testMicroTransactionFormatting() {
        let formatter = NumberFormatter.vibeMeterCurrency
        
        // Test very small amounts
        XCTAssertEqual(formatter.string(from: 0.0001), "0.0001")
        XCTAssertEqual(formatter.string(from: 0.0023), "0.0023")
        XCTAssertEqual(formatter.string(from: 0.009), "0.009")
        
        // Test transition to regular formatting
        XCTAssertEqual(formatter.string(from: 0.01), "0.01")
        XCTAssertEqual(formatter.string(from: 0.10), "0.10")
        XCTAssertEqual(formatter.string(from: 1.00), "1")
        XCTAssertEqual(formatter.string(from: 10.50), "10.50")
    }
    
    func testCostFormattingWithCurrency() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        
        // Test micro-transactions
        XCTAssertEqual(formatter.string(from: 0.0001), "$0.0001")
        XCTAssertEqual(formatter.string(from: 0.002238), "$0.0022")
        
        // Test regular amounts
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        XCTAssertEqual(formatter.string(from: 1.0), "$1")
        XCTAssertEqual(formatter.string(from: 25.50), "$25.50")
    }
    
    // MARK: - Edge Cases
    
    func testZeroTokensCost() async {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 0)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-5-sonnet-latest",
            mode: .calculate
        )
        
        XCTAssertEqual(cost, 0.0)
    }
    
    func testInputOnlyCost() async {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 0)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-5-sonnet-latest",
            mode: .calculate
        )
        
        // Expected: 1000 * 3 / 1_000_000 = 0.003
        XCTAssertEqual(cost, 0.003, accuracy: 0.00001)
    }
    
    func testOutputOnlyCost() async {
        let usage = TokenUsage(inputTokens: 0, outputTokens: 1000)
        let cost = await pricingManager.calculateCost(
            tokens: usage,
            model: "claude-3-5-sonnet-latest",
            mode: .calculate
        )
        
        // Expected: 1000 * 15 / 1_000_000 = 0.015
        XCTAssertEqual(cost, 0.015, accuracy: 0.00001)
    }
    
    // MARK: - Model Name Variations
    
    func testModelNameNormalization() async {
        let usage = TokenUsage(inputTokens: 1000, outputTokens: 1000)
        
        // Test various model name formats
        let modelVariations = [
            "claude-3-5-sonnet-20241022",
            "claude-3.5-sonnet",
            "claude-3-5-sonnet-latest",
            "claude-3-5-sonnet"
        ]
        
        for model in modelVariations {
            let cost = await pricingManager.calculateCost(
                tokens: usage,
                model: model,
                mode: .calculate
            )
            
            // All should resolve to same pricing
            XCTAssertGreaterThan(cost, 0, "Model \(model) should have valid pricing")
            XCTAssertEqual(cost, 0.018, accuracy: 0.001, "Model \(model) pricing mismatch")
        }
    }
    
    // MARK: - Monthly Aggregation
    
    func testMonthlyCostAggregation() {
        // Simulate daily costs for a month
        let dailyCosts: [Double] = [
            0.002238, 0.015, 0.105, 0.0, 0.045,
            0.089, 0.234, 0.001, 0.567, 0.890,
            0.123, 0.456, 0.789, 0.012, 0.345,
            0.678, 0.901, 0.234, 0.567, 0.890,
            0.123, 0.456, 0.789, 0.012, 0.345,
            0.678, 0.901, 0.234, 0.567, 0.890
        ]
        
        let totalCost = dailyCosts.reduce(0, +)
        
        // Verify formatting for monthly total
        let formatter = NumberFormatter.vibeMeterCurrency
        let formatted = formatter.string(from: NSNumber(value: totalCost)) ?? ""
        
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(totalCost > 10.0) // Should be a reasonable monthly amount
    }
}