import SwiftUI
import Testing
@testable import VibeMeter

@Suite("ProgressColorBasicTests", .tags(.ui, .unit, .fast))
struct ProgressColorBasicTests {
    // MARK: - Color Threshold Tests
    
    struct ColorTestCase: Sendable {
        let progress: Double
        let expectedColor: Color
        let range: String
        
        init(_ progress: Double, color: Color, range: String) {
            self.progress = progress
            self.expectedColor = color
            self.range = range
        }
    }
    
    static let colorThresholdCases: [ColorTestCase] = [
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
        ColorTestCase(2.0, color: .progressDanger, range: "over limit")
    ]
    
    @Test("Progress color thresholds", arguments: colorThresholdCases)
    func progressColorThresholds(testCase: ColorTestCase) {
        // When
        let color = Color.progressColor(for: testCase.progress)
        
        // Then
        #expect(color == testCase.expectedColor)
    }

    // MARK: - Boundary Value Tests for Colors
    
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

    // MARK: - Real-World Scenario Tests
    
    struct SpendingScenario: Sendable {
        let progress: Double
        let description: String
        let expectedColor: Color
    }
    
    static let spendingScenarios: [SpendingScenario] = [
        SpendingScenario(progress: 0.1, description: "10% of budget", expectedColor: .progressSafe),
        SpendingScenario(progress: 0.3, description: "30% of budget", expectedColor: .progressSafe),
        SpendingScenario(progress: 0.5, description: "50% of budget", expectedColor: .progressCaution),
        SpendingScenario(progress: 0.67, description: "67% of budget", expectedColor: .progressCaution),
        SpendingScenario(progress: 0.8, description: "80% of budget", expectedColor: .progressWarning),
        SpendingScenario(progress: 0.95, description: "95% of budget", expectedColor: .progressDanger),
        SpendingScenario(progress: 1.05, description: "5% over budget", expectedColor: .progressDanger),
        SpendingScenario(progress: 1.2, description: "20% over budget", expectedColor: .progressDanger)
    ]
    
    @Test("Typical spending scenarios", arguments: spendingScenarios)
    func typicalSpendingScenarios(scenario: SpendingScenario) {
        // When
        let color = Color.progressColor(for: scenario.progress)
        
        // Then
        #expect(color == scenario.expectedColor)
    }
}
