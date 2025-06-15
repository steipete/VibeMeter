import XCTest
@testable import VibeMeter

final class TokenFormatterTests: XCTestCase {
    
    // MARK: - Basic Number Formatting
    
    func testFormatSmallNumbers() {
        // Numbers under 1,000 should be displayed as-is
        XCTAssertEqual(TokenFormatter.format(0), "0")
        XCTAssertEqual(TokenFormatter.format(1), "1")
        XCTAssertEqual(TokenFormatter.format(99), "99")
        XCTAssertEqual(TokenFormatter.format(500), "500")
        XCTAssertEqual(TokenFormatter.format(999), "999")
    }
    
    func testFormatThousandsWithDecimal() {
        // Numbers 1,000-9,999 should show one decimal place
        XCTAssertEqual(TokenFormatter.format(1_000), "1.0k")
        XCTAssertEqual(TokenFormatter.format(1_234), "1.2k")
        XCTAssertEqual(TokenFormatter.format(1_567), "1.6k") // Tests rounding
        XCTAssertEqual(TokenFormatter.format(5_432), "5.4k")
        XCTAssertEqual(TokenFormatter.format(9_999), "10.0k") // Edge case - rounds up
    }
    
    func testFormatThousandsWithoutDecimal() {
        // Numbers 10,000-999,999 should show no decimal places
        XCTAssertEqual(TokenFormatter.format(10_000), "10k")
        XCTAssertEqual(TokenFormatter.format(15_678), "15k")
        XCTAssertEqual(TokenFormatter.format(50_000), "50k")
        XCTAssertEqual(TokenFormatter.format(123_456), "123k")
        XCTAssertEqual(TokenFormatter.format(999_999), "999k")
    }
    
    func testFormatMillions() {
        // Numbers 1,000,000+ should show millions with one decimal
        XCTAssertEqual(TokenFormatter.format(1_000_000), "1.0M")
        XCTAssertEqual(TokenFormatter.format(1_234_567), "1.2M")
        XCTAssertEqual(TokenFormatter.format(5_678_901), "5.7M") // Tests rounding
        XCTAssertEqual(TokenFormatter.format(10_000_000), "10.0M")
        XCTAssertEqual(TokenFormatter.format(123_456_789), "123.5M")
    }
    
    // MARK: - Edge Cases
    
    func testBoundaryValues() {
        // Test exact boundary transitions
        XCTAssertEqual(TokenFormatter.format(999), "999")
        XCTAssertEqual(TokenFormatter.format(1_000), "1.0k")
        
        XCTAssertEqual(TokenFormatter.format(9_999), "10.0k")
        XCTAssertEqual(TokenFormatter.format(10_000), "10k")
        
        XCTAssertEqual(TokenFormatter.format(999_999), "999k")
        XCTAssertEqual(TokenFormatter.format(1_000_000), "1.0M")
    }
    
    func testRoundingBehavior() {
        // Test rounding for thousands with decimal
        XCTAssertEqual(TokenFormatter.format(1_449), "1.4k") // Rounds down
        XCTAssertEqual(TokenFormatter.format(1_450), "1.5k") // Rounds up
        XCTAssertEqual(TokenFormatter.format(1_950), "2.0k") // Rounds up
        
        // Test rounding for thousands without decimal
        XCTAssertEqual(TokenFormatter.format(15_499), "15k") // Rounds down
        XCTAssertEqual(TokenFormatter.format(15_500), "16k") // Rounds up
        
        // Test rounding for millions
        XCTAssertEqual(TokenFormatter.format(1_449_999), "1.4M") // Rounds down
        XCTAssertEqual(TokenFormatter.format(1_450_000), "1.5M") // Rounds up
    }
    
    // MARK: - Range Formatting
    
    func testFormatRange() {
        // Test range formatting
        XCTAssertEqual(TokenFormatter.formatRange(from: 0, to: 100), "0-100")
        XCTAssertEqual(TokenFormatter.formatRange(from: 1_000, to: 5_000), "1.0k-5.0k")
        XCTAssertEqual(TokenFormatter.formatRange(from: 10_000, to: 50_000), "10k-50k")
        XCTAssertEqual(TokenFormatter.formatRange(from: 100_000, to: 1_000_000), "100k-1.0M")
        XCTAssertEqual(TokenFormatter.formatRange(from: 1_000_000, to: 5_000_000), "1.0M-5.0M")
    }
    
    func testFormatRangeConsistency() {
        // Ensure range uses same formatting as individual values
        let testCases: [(from: Int, to: Int)] = [
            (150, 900),
            (1_200, 8_500),
            (15_000, 95_000),
            (150_000, 850_000),
            (1_500_000, 9_500_000)
        ]
        
        for testCase in testCases {
            let expected = "\(TokenFormatter.format(testCase.from))-\(TokenFormatter.format(testCase.to))"
            let actual = TokenFormatter.formatRange(from: testCase.from, to: testCase.to)
            XCTAssertEqual(actual, expected)
        }
    }
    
    // MARK: - Real-World Scenarios
    
    func testCommonClaudeTokenCounts() {
        // Test common token counts for Claude interactions
        XCTAssertEqual(TokenFormatter.format(146), "146") // Small conversation
        XCTAssertEqual(TokenFormatter.format(2_048), "2.0k") // Moderate conversation
        XCTAssertEqual(TokenFormatter.format(8_192), "8.2k") // Long conversation
        XCTAssertEqual(TokenFormatter.format(32_768), "32k") // Very long conversation
        XCTAssertEqual(TokenFormatter.format(200_000), "200k") // Claude Pro limit
    }
    
    func testMenuBarDisplay() {
        // Test format for menu bar display scenarios
        let usedTokens = 45_678
        let limitTokens = 200_000
        let formatted = "\(TokenFormatter.format(usedTokens))/\(TokenFormatter.format(limitTokens))"
        XCTAssertEqual(formatted, "45k/200k")
    }
    
    // MARK: - Performance
    
    func testPerformance() {
        // Ensure formatting is fast enough for UI updates
        measure {
            for i in 0...1_000_000 where i % 1000 == 0 {
                _ = TokenFormatter.format(i)
            }
        }
    }
}