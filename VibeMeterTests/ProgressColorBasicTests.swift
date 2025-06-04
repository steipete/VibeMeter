import SwiftUI
@testable import VibeMeter
import XCTest

final class ProgressColorBasicTests: XCTestCase {
    // MARK: - Color Threshold Tests

    func testColor_BelowHalfway_ReturnsHealthy() {
        // Given
        let testValues = [0.0, 0.1, 0.25, 0.4, 0.49, 0.499]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .progressSafe, "Progress \(progress) should return healthy gauge color")
        }
    }

    func testColor_AtExactHalfway_ReturnsModerate() {
        // Given
        let progress = 0.5

        // When
        let color = Color.progressColor(for: progress)

        // Then
        XCTAssertEqual(color, .progressCaution, "Progress 0.5 should return moderate gauge color")
    }

    func testColor_BetweenHalfAndThreeQuarters_ReturnsModerate() {
        // Given
        let testValues = [0.5, 0.6, 0.65, 0.7, 0.74, 0.749]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .progressCaution, "Progress \(progress) should return moderate gauge color")
        }
    }

    func testColor_AtThreeQuarters_ReturnsWarning() {
        // Given
        let progress = 0.75

        // When
        let color = Color.progressColor(for: progress)

        // Then
        XCTAssertEqual(color, .progressWarning, "Progress 0.75 should return warning gauge color")
    }

    func testColor_BetweenThreeQuartersAndNinetyPercent_ReturnsWarning() {
        // Given
        let testValues = [0.75, 0.8, 0.85, 0.89, 0.899]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .progressWarning, "Progress \(progress) should return warning gauge color")
        }
    }

    func testColor_AtNinetyPercent_ReturnsDanger() {
        // Given
        let progress = 0.9

        // When
        let color = Color.progressColor(for: progress)

        // Then
        XCTAssertEqual(color, .progressDanger, "Progress 0.9 should return danger gauge color")
    }

    func testColor_AboveNinetyPercent_ReturnsDanger() {
        // Given
        let testValues = [0.9, 0.95, 1.0, 1.1, 1.5, 2.0]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .progressDanger, "Progress \(progress) should return danger gauge color")
        }
    }

    // MARK: - Boundary Value Tests for Colors

    func testColor_ExactBoundaryValues() {
        // Test exact boundary values to ensure correct thresholds
        let testCases = [
            (0.499999, Color.progressSafe),
            (0.5, Color.progressCaution),
            (0.749999, Color.progressCaution),
            (0.75, Color.progressWarning),
            (0.899999, Color.progressWarning),
            (0.9, Color.progressDanger),
        ]

        for (progress, expectedColor) in testCases {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, expectedColor, "Progress \(progress) should return \(expectedColor)")
        }
    }

    // MARK: - Real-World Scenario Tests

    func testColor_TypicalSpendingScenarios() {
        // Test realistic spending progress scenarios
        let scenarios = [
            (0.1, "10% of budget", Color.progressSafe),
            (0.3, "30% of budget", Color.progressSafe),
            (0.5, "50% of budget", Color.progressCaution),
            (0.67, "67% of budget", Color.progressCaution),
            (0.8, "80% of budget", Color.progressWarning),
            (0.95, "95% of budget", Color.progressDanger),
            (1.05, "5% over budget", Color.progressDanger),
            (1.2, "20% over budget", Color.progressDanger),
        ]

        for (progress, scenario, expectedColor) in scenarios {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, expectedColor, "Scenario '\(scenario)' should have correct color")
        }
    }
}
