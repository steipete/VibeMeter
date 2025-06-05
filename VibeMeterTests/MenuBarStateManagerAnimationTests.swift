@testable import VibeMeter
import Testing

@Suite("MenuBarStateManagerAnimationTests")
@MainActor
struct MenuBarStateManagerAnimationTests {
    let sut: MenuBarStateManager

    init() async throws {
        await MainActor.run {  }
        sut = MenuBarStateManager()
    }

     async throws {
        sut = nil
        await MainActor.run {  }
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

    func updateAnimation_LoadingState_GeneratesAnimatedValues() {
        // Given
        sut.setState(.loading)
        sut.isTransitioning = false // Skip transition for pure loading animation

        // When - Update multiple times to see animation
        let values = (0 ..< 10).map { _ in
            sut.updateAnimation()
            return sut.animatedGaugeValue
        }

        // Then
        // Values should be between 0 and 1
        for value in values {
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

    func loadingAnimation_CycleBehavior() {
        // Given
        sut.setState(.loading)
        sut.isTransitioning = false // Skip transition for pure loading test

        // Store initial animation state
        sut.updateAnimation()
        _ = sut.animatedGaugeValue

        // When - Simulate time passing
        // (Note: This test is limited since we can't easily mock time)
        for _ in 0 ..< 100 {
            sut.updateAnimation()
        }

        // Then - Values should remain within bounds
        #expect(sut.animatedGaugeValue >= 0.0)
    }

    // MARK: - Easing Function Tests

    @Test("ease in out  boundary values")

    func easeInOut_BoundaryValues() {
        // Given
        let testValues = [0.0, 0.5, 1.0]
        let expectedResults = [0.0, 0.5, 1.0]

        for (index, input) in testValues.enumerated() {
            // When
            let result = sut.easeInOut(input)

            // Then
            #expect(
                result == expectedResults[index])

    func easeInOut_SmoothCurve() {
        // Given
        let inputs = stride(from: 0.0, through: 1.0, by: 0.1)

        for input in inputs {
            // When
            let result = sut.easeInOut(input)

            // Then
            #expect(result >= 0.0)
        }
    }

    @Test("ease in out  midpoint is half")

    func easeInOut_MidpointIsHalf() {
        // When
        let result = sut.easeInOut(0.5)

        // Then
        #expect(result == 0.5)
    }

    @Test("ease in out  edge cases")

    func easeInOut_EdgeCases() {
        // Test easing function with edge cases
        let testCases = [
            (-0.1, 0.02), // Below 0: 2 * (-0.1) * (-0.1) = 0.02
            (1.1, 0.98), // Above 1: -1 + (4 - 2*1.1) * 1.1 = -1 + 1.8 * 1.1 = 0.98
            (0.25, 0.125), // First quarter: 2 * 0.25 * 0.25 = 0.125
            (0.75, 0.875), // Third quarter: -1 + (4 - 2*0.75) * 0.75 = -1 + 2.5 * 0.75 = 0.875
        ]

        for (input, approximateExpected) in testCases {
            // When
            let result = sut.easeInOut(input)

            // Then
            #expect(
                result == approximateExpected)
        }
    }

    // MARK: - Performance Tests

    @Test("update animation  performance")

    func updateAnimation_Performance() {
        // Given
        sut.setState(.loading)
        let iterations = 10000

        // When
        let startTime = Date()
        for _ in 0 ..< iterations {
            sut.updateAnimation()
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        #expect(duration < 1.0)
    }
}
