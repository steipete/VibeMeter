import SwiftUI
@testable import VibeMeter
import XCTest

final class ProgressColorEdgeCasesTests: XCTestCase {
    // MARK: - Negative Values Tests

    func testColor_NegativeValues_ReturnsGreen() {
        // Given
        let negativeValues = [-1.0, -0.5, -0.1, -0.001]

        for progress in negativeValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            XCTAssertEqual(color, .progressSafe, "Negative progress \(progress) should return green color")
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
            XCTAssertEqual(color, .progressDanger, "Large progress \(progress) should return red color")
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
        let color = Color.progressColor(for: nanProgress)

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
        let warningLevel = Color.ProgressWarningLevel.level(for: nanProgress)

        // Then
        XCTAssertNotNil(warningLevel, "Should handle NaN value")
    }

    // MARK: - Performance Tests

    func testColor_Performance() {
        // Given
        let iterations = 100_000
        let testProgress = 0.6

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            _ = Color.progressColor(for: testProgress)
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
            _ = Color.ProgressWarningLevel.level(for: testProgress)
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
            let color = Color.progressColor(for: currentProgress)
            let warningLevel = Color.ProgressWarningLevel.level(for: currentProgress)

            // Then - Should always return valid values
            XCTAssertNotNil(color, "Should return valid color for progress \(currentProgress)")
            XCTAssertNotNil(warningLevel, "Should return valid warning level for progress \(currentProgress)")

            currentProgress += increment
        }
    }
}
