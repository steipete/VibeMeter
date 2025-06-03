import Foundation
import SwiftUI

/// Represents the different states of the menu bar icon
enum MenuBarState: Equatable {
    /// User is not logged in - grey icon, no gauge
    case notLoggedIn

    /// User is logged in and data is loading - animated gauge
    case loading

    /// User is logged in with spending data - static gauge at value
    case data(value: Double) // 0.0 to 1.0

    /// Returns the gauge value for rendering
    var gaugeValue: Double? {
        switch self {
        case .notLoggedIn:
            nil // No gauge shown
        case .loading:
            nil // Calculated dynamically for animation
        case let .data(value):
            min(max(value, 0.0), 1.0)
        }
    }

    /// Whether this state should show the gauge
    var showsGauge: Bool {
        switch self {
        case .notLoggedIn:
            false
        case .loading, .data:
            true
        }
    }

    /// Whether this state is animated
    var isAnimated: Bool {
        switch self {
        case .loading:
            true
        case .notLoggedIn, .data:
            false
        }
    }
}

/// Manages animated transitions between menu bar states
@MainActor
class MenuBarStateManager: ObservableObject {
    @Published
    private(set) var currentState: MenuBarState = .notLoggedIn
    @Published
    private(set) var animatedGaugeValue: Double = 0.0

    private var animationStartTime: TimeInterval = 0
    private var transitionStartValue: Double = 0
    private var transitionTargetValue: Double = 0
    private var isTransitioning = false

    /// Duration for loading animation cycle (0→1→0)
    private let loadingCycleDuration: TimeInterval = 4.0

    /// Duration for state transitions
    private let transitionDuration: TimeInterval = 0.5

    /// Update the state with optional animation
    func setState(_ newState: MenuBarState) {
        guard newState != currentState else { return }

        // Start transition
        isTransitioning = true
        transitionStartValue = animatedGaugeValue
        animationStartTime = Date().timeIntervalSinceReferenceDate

        // Determine target value for transition
        switch newState {
        case .notLoggedIn:
            transitionTargetValue = 0.0
        case .loading:
            // Continue from current position
            transitionTargetValue = animatedGaugeValue
        case let .data(value):
            transitionTargetValue = value
        }

        currentState = newState
    }

    /// Calculate the current gauge value based on state and time
    func updateAnimation() {
        let currentTime = Date().timeIntervalSinceReferenceDate

        switch currentState {
        case .notLoggedIn:
            animatedGaugeValue = 0.0

        case .loading:
            if isTransitioning {
                // Handle transition into loading state
                let elapsed = currentTime - animationStartTime
                if elapsed >= transitionDuration {
                    isTransitioning = false
                    animationStartTime = currentTime
                } else {
                    let progress = elapsed / transitionDuration
                    animatedGaugeValue = transitionStartValue + (transitionTargetValue - transitionStartValue) *
                        easeInOut(progress)
                    return
                }
            }

            // Loading animation: 0→1→0
            let cycleTime = (currentTime - animationStartTime).truncatingRemainder(dividingBy: loadingCycleDuration)
            let halfCycle = loadingCycleDuration / 2

            if cycleTime < halfCycle {
                // Going up: 0→1
                animatedGaugeValue = cycleTime / halfCycle
            } else {
                // Going down: 1→0
                animatedGaugeValue = 1.0 - ((cycleTime - halfCycle) / halfCycle)
            }

        case let .data(targetValue):
            if isTransitioning {
                let elapsed = currentTime - animationStartTime
                if elapsed >= transitionDuration {
                    isTransitioning = false
                    animatedGaugeValue = targetValue
                } else {
                    let progress = elapsed / transitionDuration
                    animatedGaugeValue = transitionStartValue + (targetValue - transitionStartValue) *
                        easeInOut(progress)
                }
            } else {
                animatedGaugeValue = targetValue
            }
        }
    }

    /// Easing function for smooth transitions
    private func easeInOut(_ t: Double) -> Double {
        t < 0.5
            ? 2 * t * t
            : -1 + (4 - 2 * t) * t
    }
}
