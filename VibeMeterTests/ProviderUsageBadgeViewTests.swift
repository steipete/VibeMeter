import XCTest
@testable import VibeMeter

final class ProviderUsageBadgeViewTests: XCTestCase {
    @MainActor
    func testClaudeTokenFormatting() async throws {
        // Test that Claude tokens are formatted with k/M suffixes
        let spendingData = MultiProviderSpendingData()
        
        // Add Claude usage data with 200k token limit
        spendingData.updateUsage(
            for: .claude,
            from: ProviderUsageData(
                currentRequests: 0,
                totalRequests: 0,
                maxRequests: 200_000,
                startOfMonth: Date(),
                provider: .claude))
        
        // The view should format this as "0/200k" not "0/200000"
        let providerData = spendingData.getSpendingData(for: .claude)
        XCTAssertNotNil(providerData?.usageData)
        XCTAssertEqual(providerData?.usageData?.maxRequests, 200_000)
        
        // Test various token counts
        XCTAssertEqual(TokenFormatter.format(0), "0")
        XCTAssertEqual(TokenFormatter.format(200_000), "200k")
        XCTAssertEqual(TokenFormatter.format(1_500), "1.5k")
        XCTAssertEqual(TokenFormatter.format(1_500_000), "1.5M")
    }
    
    @MainActor
    func testNonClaudeProviderFormatting() async throws {
        // Test that non-Claude providers show raw numbers
        let spendingData = MultiProviderSpendingData()
        
        // Add Cursor usage data
        spendingData.updateUsage(
            for: .cursor,
            from: ProviderUsageData(
                currentRequests: 350,
                totalRequests: 4387,
                maxRequests: 500,
                startOfMonth: Date(),
                provider: .cursor))
        
        // The view should show raw numbers for Cursor
        let providerData = spendingData.getSpendingData(for: .cursor)
        XCTAssertNotNil(providerData?.usageData)
        XCTAssertEqual(providerData?.usageData?.currentRequests, 350)
        XCTAssertEqual(providerData?.usageData?.maxRequests, 500)
    }
}