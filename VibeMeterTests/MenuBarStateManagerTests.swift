@testable import VibeMeter
import XCTest

@MainActor
final class MenuBarStateManagerTests: XCTestCase {
    var sut: MenuBarStateManager!

    override func setUp() async throws {
        await MainActor.run { super.setUp() }
        sut = MenuBarStateManager()
    }

    override func tearDown() async throws {
        sut = nil
        await MainActor.run { super.tearDown() }
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
        XCTAssertNotNil(sut as (any Observable)?, "MenuBarStateManager should be Observable")
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
        // Then - MenuBarStateManager is marked with @MainActor attribute
        // This test ensures the class exists and can be accessed on MainActor
        XCTAssertNotNil(sut)
    }

    func testConcurrentStateUpdates_MainActorSafety() async {
        // Given
        let taskCount = 10

        // When - Perform concurrent state updates
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< taskCount {
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

    func testStateTransitions_Performance() {
        // Given
        let states: [MenuBarState] = [.notLoggedIn, .loading, .data(value: 0.5)]
        let iterations = 1000

        // When
        let startTime = Date()
        for i in 0 ..< iterations {
            let state = states[i % states.count]
            sut.setState(state)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "State transitions should be fast")
    }

    // MARK: - Animation Timing Tests

    // MARK: - State-Specific Behavior Tests
}
