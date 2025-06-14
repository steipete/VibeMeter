import Foundation
import SwiftUI

/// Represents the different states of the menu bar icon.
///
/// This enum defines the three possible states for the menu bar gauge icon:
/// not logged in (grey), loading (animated), or displaying data (static value).
/// Each state determines how the gauge icon should be rendered.
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

/// Manages animated transitions between menu bar states.
///
/// This class handles smooth animations for gauge value changes and loading states,
/// including the pulsing animation during data loading and smooth transitions when
/// spending values change. It also manages cost value animations for the menu bar text.
@Observable
@MainActor
class MenuBarStateManager {
    var currentState: MenuBarState = .notLoggedIn
    var animatedGaugeValue: Double = 0.0
    var isTransitioning = false
    var animatedCostValue: Double = 0.0
    var isCostTransitioning = false

    private var animationStartTime: TimeInterval = 0
    private var transitionStartValue: Double = 0
    private var transitionTargetValue: Double = 0

    // Cost animation properties
    private var costAnimationStartTime: TimeInterval = 0
    private var costTransitionStartValue: Double = 0
    private var costTransitionTargetValue: Double = 0
    
    // Debounced cost value to reduce rapid updates
    private let debouncedCost = DebouncedGroup<Double>(
        initialModel: 0.0,
        duration: .milliseconds(300)
    )

    /// Duration for loading animation cycle (0→1→0)
    private let loadingCycleDuration: TimeInterval = 4.0

    /// Duration for state transitions
    private let transitionDuration: TimeInterval = 0.5

    /// Duration for cost transitions (shorter for snappier feel)
    private let costTransitionDuration: TimeInterval = 0.3
    
    init() {
        // Set up observation of debounced cost changes
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Monitor debounced cost changes
            for await _ in debouncedCost.$model.values {
                let newValue = debouncedCost.model
                
                // Only animate if the value has changed significantly (more than $0.01)
                guard abs(newValue - self.costTransitionTargetValue) > 0.01 else { continue }
                
                // Start cost transition
                self.isCostTransitioning = true
                self.costTransitionStartValue = self.animatedCostValue
                self.costTransitionTargetValue = newValue
                self.costAnimationStartTime = Date().timeIntervalSinceReferenceDate
            }
        }
    }

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
            transitionTargetValue = min(max(value, 0.0), 1.0)
        }

        currentState = newState
    }

    /// Update the cost value with optional animation
    func setCostValue(_ newValue: Double) {
        // If this is the first time setting cost (both current and target are 0), set immediately without animation
        if animatedCostValue == 0.0, costTransitionTargetValue == 0.0 {
            animatedCostValue = newValue
            costTransitionTargetValue = newValue
            debouncedCost.update(newValue)
            return
        }

        // Update the debounced cost value - animation will be triggered by the observer
        debouncedCost.update(newValue)
    }

    /// Immediately set the cost value without animation (for currency changes)
    func setCostValueImmediately(_ newValue: Double) {
        animatedCostValue = newValue
        costTransitionTargetValue = newValue
        isCostTransitioning = false
    }

    /// Calculate the current gauge value based on state and time
    func updateAnimation() {
        let currentTime = Date().timeIntervalSinceReferenceDate
        updateGaugeAnimation(currentTime: currentTime)
        updateCostAnimation(currentTime: currentTime)
    }

    private func updateGaugeAnimation(currentTime: TimeInterval) {
        switch currentState {
        case .notLoggedIn:
            animatedGaugeValue = 0.0
        case .loading:
            updateLoadingAnimation(currentTime: currentTime)
        case let .data(targetValue):
            updateDataAnimation(currentTime: currentTime, targetValue: targetValue)
        }
    }

    private func updateLoadingAnimation(currentTime: TimeInterval) {
        if isTransitioning {
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
            animatedGaugeValue = cycleTime / halfCycle
        } else {
            animatedGaugeValue = 1.0 - ((cycleTime - halfCycle) / halfCycle)
        }
    }

    private func updateDataAnimation(currentTime: TimeInterval, targetValue: Double) {
        let clampedTargetValue = min(max(targetValue, 0.0), 1.0)
        if isTransitioning {
            let elapsed = currentTime - animationStartTime
            if elapsed >= transitionDuration {
                isTransitioning = false
                animatedGaugeValue = clampedTargetValue
            } else {
                let progress = elapsed / transitionDuration
                animatedGaugeValue = transitionStartValue + (clampedTargetValue - transitionStartValue) *
                    easeInOut(progress)
            }
        } else {
            animatedGaugeValue = clampedTargetValue
        }
    }

    private func updateCostAnimation(currentTime: TimeInterval) {
        if isCostTransitioning {
            let elapsed = currentTime - costAnimationStartTime
            if elapsed >= costTransitionDuration {
                isCostTransitioning = false
                animatedCostValue = costTransitionTargetValue
            } else {
                let progress = elapsed / costTransitionDuration
                animatedCostValue = costTransitionStartValue + (costTransitionTargetValue - costTransitionStartValue) *
                    easeInOut(progress)
            }
        }
    }

    /// Easing function for smooth transitions
    func easeInOut(_ t: Double) -> Double {
        t < 0.5
            ? 2 * t * t
            : -1 + (4 - 2 * t) * t
    }
}
