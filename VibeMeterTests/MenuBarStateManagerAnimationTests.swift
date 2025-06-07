import Foundation
import Testing
@testable import VibeMeter

@Suite("Menu Bar State Manager - Animation Tests", .tags(.ui, .unit, .performance))
@MainActor
struct MenuBarStateManagerAnimationTests {
    let sut: MenuBarStateManager

    init() {
        sut = MenuBarStateManager()
    }

    // MARK: - Animation Update Tests

    @Test("update animation  not logged in state  sets zero value")
    func updateAnimation_NotLoggedInState_SetsZeroValue() {
        // Given
        sut.setState(.notLoggedIn)
        sut.animatedGaugeValue = 0.5 // Set non-zero value

        // When
        sut.updateAnimation()

        // Then
        #expect(sut.animatedGaugeValue == 0.0)
    }

    @Test("update animation  loading state  generates animated values")
    func updateAnimation_LoadingState_GeneratesAnimatedValues() {
        // Given
        sut.setState(.loading)
        sut.isTransitioning = false // Skip transition for pure loading animation

        // When - Update multiple times to see animation
        for _ in 0 ..< 10 {
            sut.updateAnimation()
            let value = sut.animatedGaugeValue
            // Then
            // Values should be between 0 and 1
            #expect(value >= 0.0)
        }
    }

    @Test("update animation  data state  without transition  sets static value")
    func updateAnimation_DataState_WithoutTransition_SetsStaticValue() {
        // Given
        let targetValue = 0.6
        sut.setState(.data(value: targetValue))
        sut.isTransitioning = false // Skip transition

        // When
        sut.updateAnimation()

        // Then
        #expect(sut.animatedGaugeValue == targetValue)
    }

    @Test("loading animation cycle behavior")
    func loadingAnimation_CycleBehavior() {
        // Given
        sut.setState(.loading)
        sut.isTransitioning = false // Skip transition for pure loading test

        // Store initial animation state
        sut.updateAnimation()

        // When - Simulate time passing
        // (Note: This test is limited since we can't easily mock time)
        for _ in 0 ..< 100 {
            sut.updateAnimation()
        }

        // Then - Values should remain within bounds
        #expect(sut.animatedGaugeValue >= 0.0)
    }

    // MARK: - Easing Function Tests

    @Test("Easing function boundary values", arguments: [
        (0.0, 0.0),
        (0.5, 0.5),
        (1.0, 1.0)
    ])
    func easingFunctionBoundaryValues(input: Double, expected: Double) {
        // When
        let result = sut.easeInOut(input)
        
        // Then
        #expect(result == expected)
    }

    @Test("Easing function smooth curve", arguments: stride(from: 0.0, through: 1.0, by: 0.1))
    func easingFunctionSmoothCurve(input: Double) {
        // When
        let result = sut.easeInOut(input)
        
        // Then
        #expect(result >= 0.0)
        #expect(result <= 1.0)
    }

    @Test("ease in out  midpoint is half")
    func easeInOut_MidpointIsHalf() {
        // When
        let result = sut.easeInOut(0.5)

        // Then
        #expect(result == 0.5)
    }

    struct EasingTestCase: Sendable {
        let input: Double
        let expected: Double
        let description: String
        let tolerance: Double = 0.0001
    }
    
    static let easingEdgeCases: [EasingTestCase] = [
        EasingTestCase(input: -0.1, expected: 0.02, description: "Below 0: 2 * (-0.1) * (-0.1) = 0.02"),
        EasingTestCase(input: 1.1, expected: 0.98, description: "Above 1: -1 + (4 - 2*1.1) * 1.1 = 0.98"),
        EasingTestCase(input: 0.25, expected: 0.125, description: "First quarter: 2 * 0.25 * 0.25 = 0.125"),
        EasingTestCase(input: 0.75, expected: 0.875, description: "Third quarter: -1 + (4 - 2*0.75) * 0.75 = 0.875")
    ]
    
    @Test("Easing function edge cases", arguments: easingEdgeCases)
    func easingFunctionEdgeCases(testCase: EasingTestCase) {
        // When
        let result = sut.easeInOut(testCase.input)
        
        // Then
        #expect(abs(result - testCase.expected) < testCase.tolerance)
    }

    // MARK: - Performance Tests

    @Test("Update animation performance", .timeLimit(.seconds(1)))
    func updateAnimationPerformance() {
        // Given
        sut.setState(.loading)
        let iterations = 10000
        
        // When/Then - Should complete within time limit
        for _ in 0 ..< iterations {
            sut.updateAnimation()
        }
    }
}
