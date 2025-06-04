@testable import VibeMeter
import XCTest

@MainActor
final class MenuBarStateTests: XCTestCase {
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

    func testDataState_ValueClamping() {
        // Test that data state properly clamps values
        let testCases = [
            (-0.5, 0.0),
            (0.0, 0.0),
            (0.5, 0.5),
            (1.0, 1.0),
            (1.5, 1.0),
            (100.0, 1.0),
        ]

        for (input, expected) in testCases {
            // When
            let state = MenuBarState.data(value: input)

            // Then
            XCTAssertEqual(state.gaugeValue, expected, "Should clamp value \(input) to \(expected)")
        }
    }
}
