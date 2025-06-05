import SwiftUI
@testable import VibeMeter
import Testing

@Suite("ProgressColorBasicTests")
struct ProgressColorBasicTests {
    // MARK: - Color Threshold Tests

    @Test("color  below halfway  returns healthy")

    func color_BelowHalfway_ReturnsHealthy() {
        // Given
        let testValues = [0.0, 0.1, 0.25, 0.4, 0.49, 0.499]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == .progressSafe)
        }
    }

    @Test("color  at exact halfway  returns moderate")

    func color_AtExactHalfway_ReturnsModerate() {
        // Given
        let progress = 0.5

        // When
        let color = Color.progressColor(for: progress)

        // Then
        #expect(color == .progressCaution)

    func color_BetweenHalfAndThreeQuarters_ReturnsModerate() {
        // Given
        let testValues = [0.5, 0.6, 0.65, 0.7, 0.74, 0.749]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == .progressCaution)
        }
    }

    @Test("color  at three quarters  returns warning")

    func color_AtThreeQuarters_ReturnsWarning() {
        // Given
        let progress = 0.75

        // When
        let color = Color.progressColor(for: progress)

        // Then
        #expect(color == .progressWarning)

    func color_BetweenThreeQuartersAndNinetyPercent_ReturnsWarning() {
        // Given
        let testValues = [0.75, 0.8, 0.85, 0.89, 0.899]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == .progressWarning)
        }
    }

    @Test("color  at ninety percent  returns danger")

    func color_AtNinetyPercent_ReturnsDanger() {
        // Given
        let progress = 0.9

        // When
        let color = Color.progressColor(for: progress)

        // Then
        #expect(color == .progressDanger)

    func color_AboveNinetyPercent_ReturnsDanger() {
        // Given
        let testValues = [0.9, 0.95, 1.0, 1.1, 1.5, 2.0]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)

            // Then
            #expect(color == .progressDanger)
        }
    }

    // MARK: - Boundary Value Tests for Colors

    @Test("color  exact boundary values")

    func color_ExactBoundaryValues() {
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
            #expect(color == expectedColor)")
        }
    }

    // MARK: - Real-World Scenario Tests

    @Test("color  typical spending scenarios")

    func color_TypicalSpendingScenarios() {
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
            #expect(color == expectedColor)
        }
    }
}
