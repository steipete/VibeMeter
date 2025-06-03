import XCTest
@testable import VibeMeter

@MainActor
final class MenuBarStateManagerTests: XCTestCase {
    var sut: MenuBarStateManager!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = MenuBarStateManager()
    }
    
    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - MenuBarState Tests
    
    func testMenuBarState_NotLoggedIn_Properties() {
        // Given
        let state = MenuBarState.notLoggedIn
        
        // Then
        XCTAssertNil(state.gaugeValue, "Not logged in state should have no gauge value")
        XCTAssertFalse(state.showsGauge, "Not logged in state should not show gauge")
        XCTAssertFalse(state.isAnimated, "Not logged in state should not be animated")
    }
    
    func testMenuBarState_Loading_Properties() {
        // Given
        let state = MenuBarState.loading
        
        // Then
        XCTAssertNil(state.gaugeValue, "Loading state should have no static gauge value")
        XCTAssertTrue(state.showsGauge, "Loading state should show gauge")
        XCTAssertTrue(state.isAnimated, "Loading state should be animated")
    }
    
    func testMenuBarState_Data_Properties() {
        // Given
        let testValues = [0.0, 0.5, 1.0, 1.5, -0.5]
        let expectedClamped = [0.0, 0.5, 1.0, 1.0, 0.0]
        
        for (index, value) in testValues.enumerated() {
            // When
            let state = MenuBarState.data(value: value)
            
            // Then
            XCTAssertEqual(state.gaugeValue, expectedClamped[index], "Data state should clamp value between 0-1")
            XCTAssertTrue(state.showsGauge, "Data state should show gauge")
            XCTAssertFalse(state.isAnimated, "Data state should not be animated")
        }
    }
    
    func testMenuBarState_Equality() {
        // Given
        let state1 = MenuBarState.notLoggedIn
        let state2 = MenuBarState.notLoggedIn
        let state3 = MenuBarState.loading
        let state4 = MenuBarState.data(value: 0.5)
        let state5 = MenuBarState.data(value: 0.5)
        let state6 = MenuBarState.data(value: 0.7)
        
        // Then
        XCTAssertEqual(state1, state2, "Same states should be equal")
        XCTAssertNotEqual(state1, state3, "Different states should not be equal")
        XCTAssertEqual(state4, state5, "Data states with same value should be equal")
        XCTAssertNotEqual(state4, state6, "Data states with different values should not be equal")
    }
    
    // MARK: - StateManager Initialization Tests
    
    func testStateManager_InitialState() {
        // Then
        XCTAssertEqual(sut.currentState, .notLoggedIn, "Should start in not logged in state")
        XCTAssertEqual(sut.animatedGaugeValue, 0.0, "Should start with zero gauge value")
        XCTAssertFalse(sut.isTransitioning, "Should not be transitioning initially")
        XCTAssertEqual(sut.animatedCostValue, 0.0, "Should start with zero cost value")
        XCTAssertFalse(sut.isCostTransitioning, "Should not be cost transitioning initially")
    }
    
    // MARK: - State Transition Tests
    
    func testSetState_SameState_DoesNotTransition() {
        // Given
        sut.setState(.notLoggedIn) // Set to current state
        
        // Then
        XCTAssertFalse(sut.isTransitioning, "Should not transition when setting same state")
    }
    
    func testSetState_DifferentState_StartsTransition() {
        // When
        sut.setState(.loading)
        
        // Then
        XCTAssertEqual(sut.currentState, .loading, "Should update current state")
        XCTAssertTrue(sut.isTransitioning, "Should start transitioning")
    }
    
    func testSetState_NotLoggedInToLoading_SetsCorrectTarget() {
        // Given
        sut.animatedGaugeValue = 0.5 // Set some current value
        
        // When
        sut.setState(.loading)
        
        // Then
        XCTAssertEqual(sut.currentState, .loading, "Should transition to loading state")
        XCTAssertTrue(sut.isTransitioning, "Should be transitioning")
    }
    
    func testSetState_ToDataState_SetsCorrectTarget() {
        // Given
        let targetValue = 0.75
        
        // When
        sut.setState(.data(value: targetValue))
        
        // Then
        XCTAssertEqual(sut.currentState, .data(value: targetValue), "Should transition to data state")
        XCTAssertTrue(sut.isTransitioning, "Should be transitioning")
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
        let values = (0..<10).map { _ in
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
    
    // MARK: - Cost Animation Tests
    
    func testSetCostValue_FirstTime_SetsImmediately() {
        // Given
        let newValue = 100.0
        XCTAssertEqual(sut.animatedCostValue, 0.0) // Precondition
        
        // When
        sut.setCostValue(newValue)
        
        // Then
        XCTAssertEqual(sut.animatedCostValue, newValue, "First cost value should be set immediately")
        XCTAssertFalse(sut.isCostTransitioning, "Should not animate first cost value")
    }
    
    func testSetCostValue_SignificantChange_StartsTransition() {
        // Given
        sut.setCostValue(100.0) // Set initial value
        let newValue = 150.0
        
        // When
        sut.setCostValue(newValue)
        
        // Then
        XCTAssertTrue(sut.isCostTransitioning, "Should start transitioning for significant change")
    }
    
    func testSetCostValue_SmallChange_DoesNotTransition() {
        // Given
        sut.setCostValue(100.0) // Set initial value
        let smallChange = 100.005 // Less than 0.01 threshold
        
        // When
        sut.setCostValue(smallChange)
        
        // Then
        XCTAssertFalse(sut.isCostTransitioning, "Should not transition for small changes")
    }
    
    func testUpdateAnimation_CostTransition_AnimatesValue() {
        // Given
        sut.setCostValue(100.0) // Set initial
        sut.setCostValue(200.0) // Trigger transition
        XCTAssertTrue(sut.isCostTransitioning) // Precondition
        
        // When
        sut.updateAnimation()
        
        // Then
        // Value should be between start and target during transition
        XCTAssertGreaterThanOrEqual(sut.animatedCostValue, 100.0, "Cost should be >= start value")
        XCTAssertLessThanOrEqual(sut.animatedCostValue, 200.0, "Cost should be <= target value")
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
            XCTAssertEqual(result, expectedResults[index], accuracy: 0.001, "Easing function should handle boundary values correctly")
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
    
    // MARK: - Integration Tests
    
    func testCompleteStateTransitionCycle() {
        // Start: not logged in → loading → data
        
        // Phase 1: Not logged in to loading
        sut.setState(.loading)
        XCTAssertEqual(sut.currentState, .loading)
        XCTAssertTrue(sut.isTransitioning)
        
        // Phase 2: Loading to data
        sut.setState(.data(value: 0.7))
        XCTAssertEqual(sut.currentState, .data(value: 0.7))
        XCTAssertTrue(sut.isTransitioning)
        
        // Phase 3: Back to not logged in
        sut.setState(.notLoggedIn)
        XCTAssertEqual(sut.currentState, .notLoggedIn)
        XCTAssertTrue(sut.isTransitioning)
    }
    
    func testCostValueUpdatesIndependently() {
        // Given
        sut.setState(.data(value: 0.5))
        
        // When
        sut.setCostValue(50.0)
        sut.setCostValue(75.0) // Should trigger transition
        
        // Then
        XCTAssertTrue(sut.isCostTransitioning, "Cost should transition independently")
        XCTAssertTrue(sut.isTransitioning, "State should still be transitioning")
    }
    
    // MARK: - Observable Pattern Tests
    
    func testMenuBarStateManager_IsObservable() {
        // Then
        XCTAssertTrue(type(of: sut) is any Observable.Type, "MenuBarStateManager should be Observable")
    }
    
    func testStateProperties_ArePublic() {
        // Then
        _ = sut.currentState
        _ = sut.animatedGaugeValue
        _ = sut.isTransitioning
        _ = sut.animatedCostValue
        _ = sut.isCostTransitioning
        
        // Should compile without errors
    }
    
    // MARK: - MainActor Tests
    
    func testMenuBarStateManager_IsMainActor() {
        // Then
        XCTAssertTrue(type(of: sut) is any MainActor.Type, "MenuBarStateManager should be MainActor")
    }
    
    func testConcurrentStateUpdates_MainActorSafety() async {
        // Given
        let taskCount = 10
        
        // When - Perform concurrent state updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<taskCount {
                group.addTask { @MainActor in
                    let value = Double(i) / Double(taskCount)
                    self.sut.setState(.data(value: value))
                    self.sut.setCostValue(Double(i * 10))
                    self.sut.updateAnimation()
                }
            }
        }
        
        // Then - Should complete without crashes
        XCTAssertNotNil(sut.currentState)
    }
    
    // MARK: - Edge Cases Tests
    
    func testSetState_ExtremeDataValues_ClampsCorrectly() {
        // Given
        let extremeValues = [-1.0, 2.0, 100.0, -100.0]
        
        for value in extremeValues {
            // When
            sut.setState(.data(value: value))
            sut.isTransitioning = false
            sut.updateAnimation()
            
            // Then
            let clampedValue = min(max(value, 0.0), 1.0)
            XCTAssertEqual(sut.animatedGaugeValue, clampedValue, "Should clamp extreme values")
        }
    }
    
    func testSetCostValue_NegativeValues_HandlesGracefully() {
        // Given
        sut.setCostValue(100.0) // Set initial positive value
        
        // When
        sut.setCostValue(-50.0)
        
        // Then
        XCTAssertTrue(sut.isCostTransitioning, "Should handle negative cost values")
    }
    
    func testSetCostValue_VeryLargeValues_HandlesGracefully() {
        // Given
        sut.setCostValue(100.0) // Set initial value
        let largeValue = 1_000_000.0
        
        // When
        sut.setCostValue(largeValue)
        
        // Then
        XCTAssertTrue(sut.isCostTransitioning, "Should handle very large cost values")
    }
    
    // MARK: - Performance Tests
    
    func testUpdateAnimation_Performance() {
        // Given
        sut.setState(.loading)
        let iterations = 10000
        
        // When
        let startTime = Date()
        for _ in 0..<iterations {
            sut.updateAnimation()
        }
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 1.0, "Animation updates should be fast")
    }
    
    func testStateTransitions_Performance() {
        // Given
        let states: [MenuBarState] = [.notLoggedIn, .loading, .data(value: 0.5)]
        let iterations = 1000
        
        // When
        let startTime = Date()
        for i in 0..<iterations {
            let state = states[i % states.count]
            sut.setState(state)
        }
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertLessThan(duration, 1.0, "State transitions should be fast")
    }
    
    // MARK: - Animation Timing Tests
    
    func testLoadingAnimation_CycleBehavior() {
        // Given
        sut.setState(.loading)
        sut.isTransitioning = false // Skip transition for pure loading test
        
        // Store initial animation state
        sut.updateAnimation()
        let initialValue = sut.animatedGaugeValue
        
        // When - Simulate time passing
        // (Note: This test is limited since we can't easily mock time)
        for _ in 0..<100 {
            sut.updateAnimation()
        }
        
        // Then - Values should remain within bounds
        XCTAssertGreaterThanOrEqual(sut.animatedGaugeValue, 0.0, "Loading animation should stay >= 0")
        XCTAssertLessThanOrEqual(sut.animatedGaugeValue, 1.0, "Loading animation should stay <= 1")
    }
    
    // MARK: - State-Specific Behavior Tests
    
    func testDataState_ValueClamping() {
        // Test that data state properly clamps values
        let testCases = [
            (-0.5, 0.0),
            (0.0, 0.0),
            (0.5, 0.5),
            (1.0, 1.0),
            (1.5, 1.0),
            (100.0, 1.0)
        ]
        
        for (input, expected) in testCases {
            // When
            let state = MenuBarState.data(value: input)
            
            // Then
            XCTAssertEqual(state.gaugeValue, expected, "Should clamp value \(input) to \(expected)")
        }
    }
    
    func testEaseInOut_EdgeCases() {
        // Test easing function with edge cases
        let testCases = [
            (-0.1, 0.02), // Below 0
            (1.1, 1.42),  // Above 1
            (0.25, 0.125), // First quarter
            (0.75, 0.875)  // Third quarter
        ]
        
        for (input, approximateExpected) in testCases {
            // When
            let result = sut.easeInOut(input)
            
            // Then
            XCTAssertEqual(result, approximateExpected, accuracy: 0.01, "Easing function should handle edge case \(input)")
        }
    }
}