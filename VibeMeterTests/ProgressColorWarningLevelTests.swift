import SwiftUI
import Testing
@testable import VibeMeter

@Suite("ProgressColorWarningLevelTests")
struct ProgressColorWarningLevelTests {
    // MARK: - Warning Level Tests

    @Test("warning level below halfway returns normal")
    func warningLevel_BelowHalfway_ReturnsNormal() {
        // Given
        let testValues = [0.0, 0.1, 0.25, 0.4, 0.49, 0.499]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            #expect(warningLevel == .normal)
        }
    }

    @Test("warning level at exact halfway returns low")
    func warningLevel_AtExactHalfway_ReturnsLow() {
        // Given
        let progress = 0.5

        // When
        let warningLevel = Color.ProgressWarningLevel.level(for: progress)

        // Then
        #expect(warningLevel == .low)
    }

    @Test("warning level between half and three quarters returns low")
    func warningLevel_BetweenHalfAndThreeQuarters_ReturnsLow() {
        // Given
        let testValues = [0.5, 0.6, 0.65, 0.7, 0.74, 0.749]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            #expect(warningLevel == .low)
        }
    }

    @Test("warning level at three quarters returns medium")
    func warningLevel_AtThreeQuarters_ReturnsMedium() {
        // Given
        let progress = 0.75

        // When
        let warningLevel = Color.ProgressWarningLevel.level(for: progress)

        // Then
        #expect(warningLevel == .medium)
    }

    @Test("warning level between three quarters and ninety percent returns medium")
    func warningLevel_BetweenThreeQuartersAndNinetyPercent_ReturnsMedium() {
        // Given
        let testValues = [0.75, 0.8, 0.85, 0.89, 0.899]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            #expect(warningLevel == .medium)
        }
    }

    @Test("warning level at ninety percent returns high")
    func warningLevel_AtNinetyPercent_ReturnsHigh() {
        // Given
        let progress = 0.9

        // When
        let warningLevel = Color.ProgressWarningLevel.level(for: progress)

        // Then
        #expect(warningLevel == .high)
    }

    @Test("warning level above ninety percent returns high")
    func warningLevel_AboveNinetyPercent_ReturnsHigh() {
        // Given
        let testValues = [0.9, 0.95, 1.0, 1.1, 1.5, 2.0]

        for progress in testValues {
            // When
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then
            #expect(warningLevel == .high)
        }
    }

    // MARK: - Boundary Value Tests for Warning Levels

    @Test("warning level exact boundary values")
    func warningLevel_ExactBoundaryValues() {
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
            #expect(warningLevel == expectedLevel)
        }
    }

    // MARK: - Consistency Tests

    @Test("color and warning level consistency")
    func colorAndWarningLevel_Consistency() {
        // Test that color and warning level thresholds are consistent
        let testValues = [0.0, 0.25, 0.5, 0.6, 0.75, 0.8, 0.9, 1.0]

        for progress in testValues {
            // When
            let color = Color.progressColor(for: progress)
            let warningLevel = Color.ProgressWarningLevel.level(for: progress)

            // Then - Verify color and warning level are consistent
            switch progress {
            case ..<0.5:
                #expect(color == .progressSafe)
                #expect(warningLevel == .normal)
            case 0.5 ..< 0.75:
                #expect(color == .progressCaution)
                #expect(warningLevel == .low)
            case 0.75 ..< 0.9:
                #expect(color == .progressWarning)
                #expect(warningLevel == .medium)
            default:
                #expect(color == .progressDanger)
                #expect(warningLevel == .high)
            }
        }
    }

    // MARK: - WarningLevel Enum Tests

    @Test("warning level all cases can be created")
    func warningLevel_AllCasesCanBeCreated() {
        // Given/When/Then
        let normal = Color.ProgressWarningLevel.normal
        let low = Color.ProgressWarningLevel.low
        let medium = Color.ProgressWarningLevel.medium
        let high = Color.ProgressWarningLevel.high

        #expect(normal != low)
        #expect(low != medium)
        #expect(medium != high)
    }

    @Test("warning level equatable")
    func warningLevel_Equatable() {
        // Given
        let normal1 = Color.ProgressWarningLevel.normal
        let normal2 = Color.ProgressWarningLevel.normal
        let low = Color.ProgressWarningLevel.low

        // Then
        #expect(normal1 == normal2)
        #expect(normal1 != low)
    }

    @Test("warning level typical spending scenarios")
    func warningLevel_TypicalSpendingScenarios() {
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
            #expect(warningLevel == expectedLevel)
        }
    }
}
