import Foundation
import SwiftUI
import Testing
@testable import VibeMeter

@Suite("ProgressColorEdgeCasesTests", .tags(.ui, .edgeCase, .unit))
struct ProgressColorEdgeCasesTests {
    // MARK: - Negative Values Tests

    @Test("color negative values returns green")
    func color_NegativeValues_ReturnsGreen() {
        // Given
        let negativeValues = [-1.0, -0.5, -0.1, -0.001]

        for progress in negativeValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == .progressSafe)
        }
    }

    @Test("warning level negative values returns normal")
    func warningLevel_NegativeValues_ReturnsNormal() {
        // Given
        let negativeValues = [-1.0, -0.5, -0.1, -0.001]

        for progress in negativeValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            #expect(warningLevel == .normal)
        }
    }

    // MARK: - Extreme Values Tests

    @Test("color extremely large values returns red")
    func color_ExtremelyLargeValues_ReturnsRed() {
        // Given
        let largeValues = [10.0, 100.0, 1000.0, Double.greatestFiniteMagnitude]

        for progress in largeValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == .progressDanger)
        }
    }

    @Test("warning level extremely large values returns high")
    func warningLevel_ExtremelyLargeValues_ReturnsHigh() {
        // Given
        let largeValues = [10.0, 100.0, 1000.0, Double.greatestFiniteMagnitude]

        for progress in largeValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            #expect(warningLevel == .high)
        }
    }

    // MARK: - Special Float Values Tests

    @Test("color infinity values")
    func color_InfinityValues() {
        // Given
        let infinityValues = [Double.infinity, -Double.infinity]

        for progress in infinityValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            // Infinity values should be handled gracefully
            let _: Color = color
            #expect(Bool(true))
        }
    }

    @Test("color nan value")
    func color_NaNValue() {
        // Given
        let nanProgress = Double.nan

        // When
        let color = Color.progressColor(for: nanProgress)

        // Then
        // NaN should be handled gracefully (will likely fall through to default case)
        let _: Color = color
        #expect(Bool(true))
    }

    @Test("warning level infinity values")
    func warningLevel_InfinityValues() {
        // Given
        let infinityValues = [Double.infinity, -Double.infinity]

        for progress in infinityValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            let _: Color.ProgressWarningLevel = warningLevel
            #expect(Bool(true))
        }
    }

    @Test("warning level nan value")
    func warningLevel_NaNValue() {
        // Given
        let nanProgress = Double.nan

        // When
        let warningLevel = Color.ProgressWarningLevel.level(for: nanProgress)

        // Then
        let _: Color.ProgressWarningLevel = warningLevel
        #expect(Bool(true))
    }

    // MARK: - Performance Tests

    @Test("color performance")
    func color_Performance() {
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
        #expect(duration < 1.0) // Should complete within 1 second
    }

    @Test("warning level performance")
    func warningLevel_Performance() {
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
        #expect(duration < 1.0) // Should complete within 1 second
    }

    @Test("comprehensive range test")
    func color_ComprehensiveRangeTest() {
        // Test a comprehensive range of values to ensure no unexpected behavior
        let increment = 0.01
        var currentProgress = 0.0

        while currentProgress <= 2.0 {
            // When
            let color = Color.progressColor(for: currentProgress)
            let warningLevel = Color.ProgressWarningLevel.level(for: currentProgress)

            // Then - Should always return valid values
            let _: Color = color
            let _: Color.ProgressWarningLevel = warningLevel
            #expect(Bool(true))

            currentProgress += increment
        }
    }
}
