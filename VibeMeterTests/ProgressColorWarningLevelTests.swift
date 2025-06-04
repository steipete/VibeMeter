import SwiftUI
@testable import VibeMeter
import XCTest

final class ProgressColorWarningLevelTests: XCTestCase {
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
                XCTAssertEqual(color, .progressSafe, "Color should be green for progress \(progress)")
                XCTAssertEqual(warningLevel, .normal, "Warning level should be normal for progress \(progress)")
            case 0.5 ..< 0.75:
                XCTAssertEqual(color, .progressCaution, "Color should be yellow for progress \(progress)")
                XCTAssertEqual(warningLevel, .low, "Warning level should be low for progress \(progress)")
            case 0.75 ..< 0.9:
                XCTAssertEqual(color, .progressWarning, "Color should be orange for progress \(progress)")
                XCTAssertEqual(warningLevel, .medium, "Warning level should be medium for progress \(progress)")
            default:
                XCTAssertEqual(color, .progressDanger, "Color should be red for progress \(progress)")
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
