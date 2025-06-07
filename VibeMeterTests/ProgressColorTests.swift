import SwiftUI
import Testing
@testable import VibeMeter

// MARK: - Test Data

private struct ColorTestCase: Sendable, CustomTestStringConvertible {
    let progress: Double
    let expectedColor: Color
    let range: String

    init(_ progress: Double, color: Color, range: String) {
        self.progress = progress
        self.expectedColor = color
        self.range = range
    }

    var testDescription: String {
        "\(range): \(progress) → \(expectedColor)"
    }
}

private struct SpendingScenario: Sendable, CustomTestStringConvertible {
    let progress: Double
    let description: String
    let expectedColor: Color

    var testDescription: String {
        "\(description): \(progress) → \(expectedColor)"
    }
}

private struct WarningLevelTestCase: Sendable, CustomTestStringConvertible {
    let progress: Double
    let expectedLevel: String
    let expectedColor: Color
    let description: String

    var testDescription: String {
        "\(description): \(progress) → \(expectedLevel)/\(expectedColor)"
    }
}

// MARK: - Main Test Suite

@Suite("Progress Color Tests", .tags(.ui, .unit, .fast))
@MainActor
struct ProgressColorTests {
    // MARK: - Basic Color Calculation

    @Suite("Basic Color Calculation")
    struct Basic {
        @Test("Progress color thresholds", arguments: [
            // Below halfway (0-49.9%) = Safe
            ColorTestCase(0.0, color: .progressSafe, range: "zero"),
            ColorTestCase(0.1, color: .progressSafe, range: "below halfway"),
            ColorTestCase(0.25, color: .progressSafe, range: "below halfway"),
            ColorTestCase(0.4, color: .progressSafe, range: "below halfway"),
            ColorTestCase(0.49, color: .progressSafe, range: "below halfway"),
            ColorTestCase(0.499, color: .progressSafe, range: "below halfway"),

            // Halfway to three quarters (50-74.9%) = Caution
            ColorTestCase(0.5, color: .progressCaution, range: "exact halfway"),
            ColorTestCase(0.6, color: .progressCaution, range: "half to three quarters"),
            ColorTestCase(0.65, color: .progressCaution, range: "half to three quarters"),
            ColorTestCase(0.7, color: .progressCaution, range: "half to three quarters"),
            ColorTestCase(0.74, color: .progressCaution, range: "half to three quarters"),
            ColorTestCase(0.749, color: .progressCaution, range: "half to three quarters"),

            // Three quarters to ninety percent (75-89.9%) = Warning
            ColorTestCase(0.75, color: .progressWarning, range: "three quarters"),
            ColorTestCase(0.8, color: .progressWarning, range: "three quarters to ninety"),
            ColorTestCase(0.85, color: .progressWarning, range: "three quarters to ninety"),
            ColorTestCase(0.89, color: .progressWarning, range: "three quarters to ninety"),
            ColorTestCase(0.899, color: .progressWarning, range: "three quarters to ninety"),

            // Ninety percent and above (90%+) = Danger
            ColorTestCase(0.9, color: .progressDanger, range: "ninety percent"),
            ColorTestCase(0.95, color: .progressDanger, range: "above ninety"),
            ColorTestCase(1.0, color: .progressDanger, range: "at limit"),
            ColorTestCase(1.1, color: .progressDanger, range: "over limit"),
            ColorTestCase(1.5, color: .progressDanger, range: "over limit"),
            ColorTestCase(2.0, color: .progressDanger, range: "over limit"),
        ])
        fileprivate func progressColorThresholds(testCase: ColorTestCase) {
            // When
            let color = Color.progressColor(for: testCase.progress)

            // Then
            #expect(color == testCase.expectedColor)
        }

        @Test("Color exact boundary values", arguments: [
            (0.499999, Color.progressSafe),
            (0.5, Color.progressCaution),
            (0.749999, Color.progressCaution),
            (0.75, Color.progressWarning),
            (0.899999, Color.progressWarning),
            (0.9, Color.progressDanger)
        ])
        func colorExactBoundaryValues(progress: Double, expectedColor: Color) {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == expectedColor)
        }

        @Test("Typical spending scenarios", arguments: [
            SpendingScenario(progress: 0.1, description: "10% of budget", expectedColor: .progressSafe),
            SpendingScenario(progress: 0.3, description: "30% of budget", expectedColor: .progressSafe),
            SpendingScenario(progress: 0.5, description: "50% of budget", expectedColor: .progressCaution),
            SpendingScenario(progress: 0.67, description: "67% of budget", expectedColor: .progressCaution),
            SpendingScenario(progress: 0.8, description: "80% of budget", expectedColor: .progressWarning),
            SpendingScenario(progress: 0.95, description: "95% of budget", expectedColor: .progressDanger),
            SpendingScenario(progress: 1.05, description: "5% over budget", expectedColor: .progressDanger),
            SpendingScenario(progress: 1.2, description: "20% over budget", expectedColor: .progressDanger),
        ])
        fileprivate func typicalSpendingScenarios(scenario: SpendingScenario) {
            // When
            let color = Color.progressColor(for: scenario.progress)

            // Then
            #expect(color == scenario.expectedColor)
        }
    }

    // MARK: - Edge Cases

    @Suite("Edge Cases", .tags(.edgeCase))
    struct EdgeCases {
        @Test("Negative progress values return safe color")
        func negativeProgressValues() {
            // Given
            let negativeValues = [-1.0, -0.5, -0.1, -0.001]

            for progress in negativeValues {
                // When
                let color = Color.progressColor(for: progress)

                // Then
                #expect(color == .progressSafe)
            }
        }

        @Test("Very large progress values return danger color")
        func veryLargeProgressValues() {
            // Given
            let largeValues = [5.0, 10.0, 100.0, 1000.0]

            for progress in largeValues {
                // When
                let color = Color.progressColor(for: progress)

                // Then
                #expect(color == .progressDanger)
            }
        }

        @Test("Special float values", arguments: [
            (Double.nan, Color.progressDanger, "NaN returns danger"),
            (Double.infinity, Color.progressDanger, "Infinity returns danger"),
            (-Double.infinity, Color.progressSafe, "Negative infinity returns safe")
        ])
        func specialFloatValues(progress: Double, expectedColor: Color, description _: String) {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == expectedColor)
        }

        @Test("Progress very close to thresholds")
        func progressVeryCloseToThresholds() {
            // Test values that are extremely close to threshold boundaries
            // swiftlint:disable:next large_tuple
            let testCases: [(Double, Color, String)] = [
                (0.5 - Double.ulpOfOne, .progressSafe, "Just below 0.5"),
                (0.5 + Double.ulpOfOne, .progressCaution, "Just above 0.5"),
                (0.75 - Double.ulpOfOne, .progressCaution, "Just below 0.75"),
                (0.75 + Double.ulpOfOne, .progressWarning, "Just above 0.75"),
                (0.9 - Double.ulpOfOne, .progressWarning, "Just below 0.9"),
                (0.9 + Double.ulpOfOne, .progressDanger, "Just above 0.9"),
            ]

            for (progress, expectedColor, _) in testCases {
                // When
                let color = Color.progressColor(for: progress)

                // Then
                #expect(color == expectedColor)
            }
        }
    }

    // MARK: - Warning Levels

    @Suite("Warning Levels", .tags(.notifications))
    struct WarningLevels {
        @Test("Warning level thresholds", arguments: [
            // Safe zone
            WarningLevelTestCase(
                progress: 0.0,
                expectedLevel: "safe",
                expectedColor: .progressSafe,
                description: "Start of budget"),
            WarningLevelTestCase(
                progress: 0.25,
                expectedLevel: "safe",
                expectedColor: .progressSafe,
                description: "Quarter of budget"),
            WarningLevelTestCase(
                progress: 0.49,
                expectedLevel: "safe",
                expectedColor: .progressSafe,
                description: "Just below halfway"),

            // Caution zone
            WarningLevelTestCase(
                progress: 0.5,
                expectedLevel: "caution",
                expectedColor: .progressCaution,
                description: "Halfway point"),
            WarningLevelTestCase(
                progress: 0.6,
                expectedLevel: "caution",
                expectedColor: .progressCaution,
                description: "60% of budget"),
            WarningLevelTestCase(
                progress: 0.74,
                expectedLevel: "caution",
                expectedColor: .progressCaution,
                description: "Just below warning"),

            // Warning zone
            WarningLevelTestCase(
                progress: 0.75,
                expectedLevel: "warning",
                expectedColor: .progressWarning,
                description: "Warning threshold"),
            WarningLevelTestCase(
                progress: 0.8,
                expectedLevel: "warning",
                expectedColor: .progressWarning,
                description: "80% of budget"),
            WarningLevelTestCase(
                progress: 0.89,
                expectedLevel: "warning",
                expectedColor: .progressWarning,
                description: "Just below danger"),

            // Danger zone
            WarningLevelTestCase(
                progress: 0.9,
                expectedLevel: "danger",
                expectedColor: .progressDanger,
                description: "Danger threshold"),
            WarningLevelTestCase(
                progress: 1.0,
                expectedLevel: "danger",
                expectedColor: .progressDanger,
                description: "At limit"),
            WarningLevelTestCase(
                progress: 1.5,
                expectedLevel: "danger",
                expectedColor: .progressDanger,
                description: "Over budget"),
        ])
        fileprivate func warningLevelThresholds(testCase: WarningLevelTestCase) {
            // When
            let color = Color.progressColor(for: testCase.progress)
            let level = warningLevel(for: testCase.progress)

            // Then
            #expect(color == testCase.expectedColor)
            #expect(level == testCase.expectedLevel)
        }

        @Test(
            "Warning levels for monthly spending patterns",
            arguments: Array(stride(from: 0.0, through: 31.0, by: 1.0)))
        func monthlySpendingPattern(dayOfMonth: Double) {
            // Given
            let daysInMonth = 30.0
            let dailyBudgetProgress = dayOfMonth / daysInMonth

            // When
            let color = Color.progressColor(for: dailyBudgetProgress)
            let level = warningLevel(for: dailyBudgetProgress)

            // Then
            if dayOfMonth <= 15 {
                #expect(color == .progressSafe || color == .progressCaution)
                #expect(level == "safe" || level == "caution")
            } else if dayOfMonth <= 22 {
                #expect(color == .progressCaution || color == .progressWarning)
            } else {
                #expect(color == .progressWarning || color == .progressDanger)
            }
        }

        // Helper function for warning levels
        private func warningLevel(for progress: Double) -> String {
            switch progress {
            case ..<0.5: "safe"
            case 0.5 ..< 0.75: "caution"
            case 0.75 ..< 0.9: "warning"
            default: "danger"
            }
        }
    }
}
