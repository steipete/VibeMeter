import Foundation
import Testing
@testable import VibeMeter

@Suite("MenuBarStateTests")
@MainActor
struct MenuBarStateTests {
    // MARK: - MenuBarState Tests

    @Test("menu bar state  not logged in  properties")
    func menuBarState_NotLoggedIn_Properties() {
        // Given
        let state = MenuBarState.notLoggedIn

        // Then
        #expect(state.gaugeValue == nil)
        #expect(state.isAnimated == false)
    }

    @Test("menu bar state loading properties")
    func menuBarState_Loading_Properties() {
        // Given
        let state = MenuBarState.loading

        // Then
        #expect(state.gaugeValue == nil)
        #expect(state.isAnimated == true)
    }

    @Test("menu bar state data properties")
    func menuBarState_Data_Properties() {
        // Given
        let testValues = [0.0, 0.5, 1.0, 1.5, -0.5]
        let expectedClamped = [0.0, 0.5, 1.0, 1.0, 0.0]

        for (index, value) in testValues.enumerated() {
            // When
            let state = MenuBarState.data(value: value)

            // Then
            #expect(state.gaugeValue == expectedClamped[index])
            #expect(state.isAnimated == false)
        }
    }

    @Test("menu bar state equality")
    func menuBarState_Equality() {
        // Given
        let state1 = MenuBarState.notLoggedIn
        let state2 = MenuBarState.notLoggedIn
        let state3 = MenuBarState.loading
        let state4 = MenuBarState.data(value: 0.5)
        let state5 = MenuBarState.data(value: 0.5)
        let state6 = MenuBarState.data(value: 0.7)

        // Then
        #expect(state1 == state2)
        #expect(state4 == state5)
    }

    @Test("data state  value clamping")
    func dataState_ValueClamping() {
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
            #expect(state.gaugeValue == expected)
        }
    }
}
