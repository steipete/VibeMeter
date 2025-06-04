@testable import VibeMeter
import XCTest

@MainActor
final class MenuBarStateManagerAnimationTests: XCTestCase {
    var sut: MenuBarStateManager!
    
    override func setUp() async throws {
        await MainActor.run { super.setUp() }
        sut = MenuBarStateManager()
    }
    
    override func tearDown() async throws {
        sut = nil
        await MainActor.run { super.tearDown() }
    }
    
    // MARK: - Animation Update Tests
    
    func testUpdateAnimation_NotLoggedInState_SetsZeroValue() {
        // Given
        sut.setState(.notLoggedIn)
        sut.animatedGaugeValue = 0.5 // Set non-zero value
        
        // When
        sut.updateAnimation()
        
        // Then
        XCTAssertEqual(sut.animatedGaugeValue, 0.0, "Not logged in state should set gauge to zero")
    }
    
    func testUpdateAnimation_LoadingState_GeneratesAnimatedValues() {
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
            XCTAssertGreaterThanOrEqual(value, 0.0, "Loading animation should stay >= 0")
            XCTAssertLessThanOrEqual(value, 1.0, "Loading animation should stay <= 1")
        }
    }
    
    func testUpdateAnimation_DataState_WithoutTransition_SetsStaticValue() {
        // Given
        let targetValue = 0.6
        sut.setState(.data(value: targetValue))
        sut.isTransitioning = false // Skip transition
        
        // When
        sut.updateAnimation()
        
        // Then
        XCTAssertEqual(sut.animatedGaugeValue, targetValue, "Data state should set static gauge value")
    }
    
    func testLoadingAnimation_CycleBehavior() {
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
        XCTAssertGreaterThanOrEqual(sut.animatedGaugeValue, 0.0, "Loading animation should stay >= 0")
        XCTAssertLessThanOrEqual(sut.animatedGaugeValue, 1.0, "Loading animation should stay <= 1")
    }
    
    // MARK: - Easing Function Tests
    
    func testEaseInOut_BoundaryValues() {
        // Given
        let testValues = [0.0, 0.5, 1.0]
        let expectedResults = [0.0, 0.5, 1.0]
        
        for (index, input) in testValues.enumerated() {
            // When
            let result = sut.easeInOut(input)
            
            // Then
            XCTAssertEqual(
                result,
                expectedResults[index],
                accuracy: 0.001,
                "Easing function should handle boundary values correctly")
        }
    }
    
    func testEaseInOut_SmoothCurve() {
        // Given
        let inputs = stride(from: 0.0, through: 1.0, by: 0.1)
        
        for input in inputs {
            // When
            let result = sut.easeInOut(input)
            
            // Then
            XCTAssertGreaterThanOrEqual(result, 0.0, "Easing should stay >= 0")
            XCTAssertLessThanOrEqual(result, 1.0, "Easing should stay <= 1")
        }
    }
    
    func testEaseInOut_MidpointIsHalf() {
        // When
        let result = sut.easeInOut(0.5)
        
        // Then
        XCTAssertEqual(result, 0.5, accuracy: 0.001, "Easing function should pass through (0.5, 0.5)")
    }
    
    func testEaseInOut_EdgeCases() {
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
            XCTAssertEqual(
                result,
                approximateExpected,
                accuracy: 0.01,
                "Easing function should handle edge case \(input)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testUpdateAnimation_Performance() {
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
        XCTAssertLessThan(duration, 1.0, "Animation updates should be fast")
    }
}