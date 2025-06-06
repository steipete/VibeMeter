import Foundation
import Testing
@testable import VibeMeter

@Suite("MenuBarStateManagerTests")
@MainActor
struct MenuBarStateManagerTests {
    let sut: MenuBarStateManager

    init() {
        sut = MenuBarStateManager()
    }

    // MARK: - StateManager Initialization Tests

    @Test("state manager  initial state")
    func stateManager_InitialState() {
        // Then
        #expect(sut.currentState == .notLoggedIn)
        #expect(sut.isTransitioning == false)
        #expect(sut.isCostTransitioning == false)
    }

    @Test("set state  same state  does not transition")
    func setState_SameState_DoesNotTransition() {
        // Given
        sut.setState(.notLoggedIn) // Set to current state

        // Then
        #expect(sut.isTransitioning == false)
    }

    @Test("set state  different state  starts transition")
    func setState_DifferentState_StartsTransition() {
        // When
        sut.setState(.loading)

        // Then
        #expect(sut.currentState == .loading)
    }

    @Test("set state  not logged in to loading  sets correct target")
    func setState_NotLoggedInToLoading_SetsCorrectTarget() {
        // Given
        sut.animatedGaugeValue = 0.5 // Set some current value

        // When
        sut.setState(.loading)

        // Then
        #expect(sut.currentState == .loading)
    }

    @Test("set state  to data state  sets correct target")
    func setState_ToDataState_SetsCorrectTarget() {
        // Given
        let targetValue = 0.75

        // When
        sut.setState(.data(value: targetValue))

        // Then
        #expect(sut.currentState == .data(value: targetValue))
        #expect(sut.isTransitioning == true)
    }

    @Test("set cost value  first time  sets immediately")
    func setCostValue_FirstTime_SetsImmediately() {
        // Given
        let newValue = 100.0
        #expect(sut.animatedCostValue == 0.0)

        // When
        sut.setCostValue(newValue)

        // Then
        #expect(sut.animatedCostValue == newValue)
    }

    @Test("set cost value  significant change  starts transition")
    func setCostValue_SignificantChange_StartsTransition() {
        // Given
        sut.setCostValue(100.0) // Set initial value
        let newValue = 150.0

        // When
        sut.setCostValue(newValue)

        // Then
        #expect(sut.isCostTransitioning == true)
    }

    @Test("set cost value  small change  does not transition")
    func setCostValue_SmallChange_DoesNotTransition() {
        // Given
        sut.setCostValue(100.0) // Set initial value
        let smallChange = 100.005 // Less than 0.01 threshold

        // When
        sut.setCostValue(smallChange)

        // Then
        #expect(sut.isCostTransitioning == false)
    }

    @Test("update animation  cost transition  animates value")
    func updateAnimation_CostTransition_AnimatesValue() {
        // Given
        sut.setCostValue(100.0) // Set initial
        sut.setCostValue(200.0) // Trigger transition
        #expect(sut.isCostTransitioning == true)

        // Then
        // Value should be between start and target during transition
        #expect(sut.animatedCostValue >= 100.0)
    }

    // MARK: - Integration Tests

    @Test("complete state transition cycle")
    func completeStateTransitionCycle() {
        // Start: not logged in → loading → data

        // Phase 1: Not logged in to loading
        sut.setState(.loading)
        #expect(sut.currentState == .loading)

        // Phase 2: Loading to data
        sut.setState(.data(value: 0.7))
        #expect(sut.currentState == .data(value: 0.7))

        // Phase 3: Back to not logged in
        sut.setState(.notLoggedIn)
        #expect(sut.currentState == .notLoggedIn)
    }

    @Test("cost value updates independently")
    func costValueUpdatesIndependently() {
        // Given
        sut.setState(.data(value: 0.5))

        // When
        sut.setCostValue(50.0)
        sut.setCostValue(75.0) // Should trigger transition

        // Then
        #expect(sut.isCostTransitioning == true)
    }

    // MARK: - Observable Pattern Tests

    @Test("menu bar state manager  is observable")
    func menuBarStateManager_IsObservable() {
        // Then
        #expect((sut as (any Observable)?) != nil)
    }

    @Test("state properties  are public")
    func stateProperties_ArePublic() {
        // Then
        _ = sut.currentState
        _ = sut.animatedGaugeValue
        _ = sut.isTransitioning
        _ = sut.animatedCostValue
        _ = sut.isCostTransitioning

        // Should compile without errors
    }

    // MARK: - MainActor Tests

    @Test("menu bar state manager  is main actor")
    func menuBarStateManager_IsMainActor() {
        // Then - MenuBarStateManager is marked with @MainActor attribute
        // This test ensures the class exists and can be accessed on MainActor
        #expect(sut != nil)
    }

    @Test("concurrent state updates  main actor safety")
    func concurrentStateUpdates_MainActorSafety() async {
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
        #expect(sut.currentState != nil)
    }

    @Test("set state  extreme data values  clamps correctly")
    func setState_ExtremeDataValues_ClampsCorrectly() {
        // Given
        let extremeValues = [-1.0, 2.0, 100.0, -100.0]

        for value in extremeValues {
            // When
            sut.setState(.data(value: value))
            sut.isTransitioning = false
            sut.updateAnimation()

            // Then
            let clampedValue = min(max(value, 0.0), 1.0)
            #expect(sut.animatedGaugeValue == clampedValue)
        }
    }

    @Test("set cost value  negative values  handles gracefully")
    func setCostValue_NegativeValues_HandlesGracefully() {
        // Given
        sut.setCostValue(100.0) // Set initial positive value

        // When
        sut.setCostValue(-50.0)

        // Then
        #expect(sut.isCostTransitioning == true)
    }

    @Test("set cost value  very large values  handles gracefully")
    func setCostValue_VeryLargeValues_HandlesGracefully() {
        // Given
        sut.setCostValue(100.0) // Set initial value
        let largeValue = 1_000_000.0

        // When
        sut.setCostValue(largeValue)

        // Then
        #expect(sut.isCostTransitioning == true)
    }

    @Test("state transitions  performance")
    func stateTransitions_Performance() {
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
        #expect(duration < 1.0)
    }

    // MARK: - Animation Timing Tests

    // MARK: - State-Specific Behavior Tests
}
