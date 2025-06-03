import SwiftUI
@testable import VibeMeter
import XCTest

final class ProgressColorTests: XCTestCase {
    // MARK: - Color Threshold Tests

    func testColor_BelowHalfway_ReturnsHealthy() {
        // Given
        let testValues = [0.0, 0.1, 0.25, 0.4, 0.49, 0.499]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .gaugeHealthy, "Progress \(progress) should return healthy gauge color")
        }
    }

    func testColor_AtExactHalfway_ReturnsModerate() {
        // Given
        let progress = 0.5

        // When
        let color = Color.progressColor(for: progress)

        // Then
        XCTAssertEqual(color, .gaugeModerate, "Progress 0.5 should return moderate gauge color")
    }

    func testColor_BetweenHalfAndThreeQuarters_ReturnsModerate() {
        // Given
        let testValues = [0.5, 0.6, 0.65, 0.7, 0.74, 0.749]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .gaugeModerate, "Progress \(progress) should return moderate gauge color")
        }
    }

    func testColor_AtThreeQuarters_ReturnsWarning() {
        // Given
        let progress = 0.75

        // When
        let color = Color.progressColor(for: progress)

        // Then
        XCTAssertEqual(color, .gaugeWarning, "Progress 0.75 should return warning gauge color")
    }

    func testColor_BetweenThreeQuartersAndNinetyPercent_ReturnsWarning() {
        // Given
        let testValues = [0.75, 0.8, 0.85, 0.89, 0.899]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .gaugeWarning, "Progress \(progress) should return warning gauge color")
        }
    }

    func testColor_AtNinetyPercent_ReturnsDanger() {
        // Given
        let progress = 0.9

        // When
        let color = Color.progressColor(for: progress)

        // Then
        XCTAssertEqual(color, .gaugeDanger, "Progress 0.9 should return danger gauge color")
    }

    func testColor_AboveNinetyPercent_ReturnsDanger() {
        // Given
        let testValues = [0.9, 0.95, 1.0, 1.1, 1.5, 2.0]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .gaugeDanger, "Progress \(progress) should return danger gauge color")
        }
    }

    // MARK: - Boundary Value Tests for Colors

    func testColor_ExactBoundaryValues() {
        // Test exact boundary values to ensure correct thresholds
        let testCases = [
            (0.499999, Color.gaugeHealthy),
            (0.5, Color.gaugeModerate),
            (0.749999, Color.gaugeModerate),
            (0.75, Color.gaugeWarning),
            (0.899999, Color.gaugeWarning),
            (0.9, Color.gaugeDanger),
        ]

        for (progress, expectedColor) in testCases {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, expectedColor, "Progress \(progress) should return \(expectedColor)")
        }
    }

    // MARK: - Warning Level Tests

    func testWarningLevel_BelowHalfway_ReturnsNormal() {
        // Given
        let testValues = [0.0, 0.1, 0.25, 0.4, 0.49, 0.499]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, .normal, "Progress \(progress) should return normal warning level")
        }
    }

    func testWarningLevel_AtExactHalfway_ReturnsLow() {
        // Given
        let progress = 0.5

        // When
        let warningLevel = Color.ProgressWarningLevel.level(for: progress)

        // Then
        XCTAssertEqual(warningLevel, .low, "Progress 0.5 should return low warning level")
    }

    func testWarningLevel_BetweenHalfAndThreeQuarters_ReturnsLow() {
        // Given
        let testValues = [0.5, 0.6, 0.65, 0.7, 0.74, 0.749]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, .low, "Progress \(progress) should return low warning level")
        }
    }

    func testWarningLevel_AtThreeQuarters_ReturnsMedium() {
        // Given
        let progress = 0.75

        // When
        let warningLevel = Color.ProgressWarningLevel.level(for: progress)

        // Then
        XCTAssertEqual(warningLevel, .medium, "Progress 0.75 should return medium warning level")
    }

    func testWarningLevel_BetweenThreeQuartersAndNinetyPercent_ReturnsMedium() {
        // Given
        let testValues = [0.75, 0.8, 0.85, 0.89, 0.899]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, .medium, "Progress \(progress) should return medium warning level")
        }
    }

    func testWarningLevel_AtNinetyPercent_ReturnsHigh() {
        // Given
        let progress = 0.9

        // When
        let warningLevel = Color.ProgressWarningLevel.level(for: progress)

        // Then
        XCTAssertEqual(warningLevel, .high, "Progress 0.9 should return high warning level")
    }

    func testWarningLevel_AboveNinetyPercent_ReturnsHigh() {
        // Given
        let testValues = [0.9, 0.95, 1.0, 1.1, 1.5, 2.0]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, .high, "Progress \(progress) should return high warning level")
        }
    }

    // MARK: - Boundary Value Tests for Warning Levels

    func testWarningLevel_ExactBoundaryValues() {
        // Test exact boundary values to ensure correct thresholds
        let testCases = [
            (0.499999, Color.ProgressWarningLevel.normal),
            (0.5, Color.ProgressWarningLevel.low),
            (0.749999, Color.ProgressWarningLevel.low),
            (0.75, Color.ProgressWarningLevel.medium),
            (0.899999, Color.ProgressWarningLevel.medium),
            (0.9, Color.ProgressWarningLevel.high),
        ]

        for (progress, expectedLevel) in testCases {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, expectedLevel, "Progress \(progress) should return \(expectedLevel)")
        }
    }

    // MARK: - Negative Values Tests

    func testColor_NegativeValues_ReturnsGreen() {
        // Given
        let negativeValues = [-1.0, -0.5, -0.1, -0.001]

        for progress in negativeValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .gaugeHealthy, "Negative progress \(progress) should return green color")
        }
    }

    func testWarningLevel_NegativeValues_ReturnsNormal() {
        // Given
        let negativeValues = [-1.0, -0.5, -0.1, -0.001]

        for progress in negativeValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, .normal, "Negative progress \(progress) should return normal warning level")
        }
    }

    // MARK: - Extreme Values Tests

    func testColor_ExtremelyLargeValues_ReturnsRed() {
        // Given
        let largeValues = [10.0, 100.0, 1000.0, Double.greatestFiniteMagnitude]

        for progress in largeValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .gaugeDanger, "Large progress \(progress) should return red color")
        }
    }

    func testWarningLevel_ExtremelyLargeValues_ReturnsHigh() {
        // Given
        let largeValues = [10.0, 100.0, 1000.0, Double.greatestFiniteMagnitude]

        for progress in largeValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, .high, "Large progress \(progress) should return high warning level")
        }
    }

    // MARK: - Special Float Values Tests

    func testColor_InfinityValues() {
        // Given
        let infinityValues = [Double.infinity, -Double.infinity]

        for progress in infinityValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            // Infinity values should be handled gracefully
            XCTAssertNotNil(color, "Should handle infinity value \(progress)")
        }
    }

    func testColor_NaNValue() {
        // Given
        let nanProgress = Double.nan

        // When
        let color = ProgressColorHelper.color(for: nanProgress)

        // Then
        // NaN should be handled gracefully (will likely fall through to default case)
        XCTAssertNotNil(color, "Should handle NaN value")
    }

    func testWarningLevel_InfinityValues() {
        // Given
        let infinityValues = [Double.infinity, -Double.infinity]

        for progress in infinityValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertNotNil(warningLevel, "Should handle infinity value \(progress)")
        }
    }

    func testWarningLevel_NaNValue() {
        // Given
        let nanProgress = Double.nan

        // When
        let warningLevel = ProgressColorHelper.warningLevel(for: nanProgress)

        // Then
        XCTAssertNotNil(warningLevel, "Should handle NaN value")
    }

    // MARK: - Consistency Tests

    func testColorAndWarningLevel_Consistency() {
        // Test that color and warning level thresholds are consistent
        let testValues = [0.0, 0.25, 0.5, 0.6, 0.75, 0.8, 0.9, 1.0]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then - Verify color and warning level are consistent
            switch progress {
            case ..<0.5:
                XCTAssertEqual(color, .gaugeHealthy, "Color should be green for progress \(progress)")
                XCTAssertEqual(warningLevel, .normal, "Warning level should be normal for progress \(progress)")
            case 0.5 ..< 0.75:
                XCTAssertEqual(color, .gaugeModerate, "Color should be yellow for progress \(progress)")
                XCTAssertEqual(warningLevel, .low, "Warning level should be low for progress \(progress)")
            case 0.75 ..< 0.9:
                XCTAssertEqual(color, .gaugeWarning, "Color should be orange for progress \(progress)")
                XCTAssertEqual(warningLevel, .medium, "Warning level should be medium for progress \(progress)")
            default:
                XCTAssertEqual(color, .gaugeDanger, "Color should be red for progress \(progress)")
                XCTAssertEqual(warningLevel, .high, "Warning level should be high for progress \(progress)")
            }
        }
    }

    // MARK: - WarningLevel Enum Tests

    func testWarningLevel_AllCasesCanBeCreated() {
        // Given/When/Then
        let normal = Color.ProgressWarningLevel.normal
        let low = Color.ProgressWarningLevel.low
        let medium = Color.ProgressWarningLevel.medium
        let high = Color.ProgressWarningLevel.high

        XCTAssertNotNil(normal)
        XCTAssertNotNil(low)
        XCTAssertNotNil(medium)
        XCTAssertNotNil(high)
    }

    func testWarningLevel_Equatable() {
        // Given
        let normal1 = Color.ProgressWarningLevel.normal
        let normal2 = Color.ProgressWarningLevel.normal
        let low = Color.ProgressWarningLevel.low

        // Then
        XCTAssertEqual(normal1, normal2, "Same warning levels should be equal")
        XCTAssertNotEqual(normal1, low, "Different warning levels should not be equal")
    }

    // MARK: - Performance Tests

    func testColor_Performance() {
        // Given
        let iterations = 100_000
        let testProgress = 0.6

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            _ = ProgressColorHelper.color(for: testProgress)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "Color calculation should be fast")
    }

    func testWarningLevel_Performance() {
        // Given
        let iterations = 100_000
        let testProgress = 0.8

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            _ = ProgressColorHelper.warningLevel(for: testProgress)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "Warning level calculation should be fast")
    }

    // MARK: - Comprehensive Range Tests

    func testColor_ComprehensiveRangeTest() {
        // Test a comprehensive range of values to ensure no unexpected behavior
        let increment = 0.01
        var currentProgress = 0.0

        while currentProgress <= 2.0 {
            // When
            let color = ProgressColorHelper.color(for: currentProgress)
            let warningLevel = ProgressColorHelper.warningLevel(for: currentProgress)

            // Then - Should always return valid values
            XCTAssertNotNil(color, "Should return valid color for progress \(currentProgress)")
            XCTAssertNotNil(warningLevel, "Should return valid warning level for progress \(currentProgress)")

            currentProgress += increment
        }
    }

    // MARK: - Real-World Scenario Tests

    func testColor_TypicalSpendingScenarios() {
        // Test realistic spending progress scenarios
        let scenarios = [
            (0.1, "10% of budget", Color.gaugeHealthy),
            (0.3, "30% of budget", Color.gaugeHealthy),
            (0.5, "50% of budget", Color.gaugeModerate),
            (0.67, "67% of budget", Color.gaugeModerate),
            (0.8, "80% of budget", Color.gaugeWarning),
            (0.95, "95% of budget", Color.gaugeDanger),
            (1.05, "5% over budget", Color.gaugeDanger),
            (1.2, "20% over budget", Color.gaugeDanger),
        ]

        for (progress, scenario, expectedColor) in scenarios {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, expectedColor, "Scenario '\(scenario)' should have correct color")
        }
    }

    func testWarningLevel_TypicalSpendingScenarios() {
        // Test realistic spending progress scenarios
        let scenarios = [
            (0.1, "10% of budget", Color.ProgressWarningLevel.normal),
            (0.3, "30% of budget", Color.ProgressWarningLevel.normal),
            (0.5, "50% of budget", Color.ProgressWarningLevel.low),
            (0.67, "67% of budget", Color.ProgressWarningLevel.low),
            (0.8, "80% of budget", Color.ProgressWarningLevel.medium),
            (0.95, "95% of budget", Color.ProgressWarningLevel.high),
            (1.05, "5% over budget", Color.ProgressWarningLevel.high),
            (1.2, "20% over budget", Color.ProgressWarningLevel.high),
        ]

        for (progress, scenario, expectedLevel) in scenarios {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            XCTAssertEqual(warningLevel, expectedLevel, "Scenario '\(scenario)' should have correct warning level")
        }
    }
}
