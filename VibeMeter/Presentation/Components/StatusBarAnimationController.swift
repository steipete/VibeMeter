import Foundation
import os.log

/// Manages animation timing and state for the status bar.
///
/// This controller handles the adaptive animation timing system that optimizes
/// CPU usage by adjusting timer frequency based on animation needs while
/// maintaining smooth visual transitions.
@MainActor
final class StatusBarAnimationController {
    
    // MARK: - Private Properties
    
    private var animationTimer: Timer?
    private var periodicTimer: Timer?
    private let stateManager: MenuBarStateManager
    private var lastRenderedValue: Double = 0
    private let logger = Logger(subsystem: "com.vibemeter", category: "StatusBarAnimationController")
    
    // MARK: - Callbacks
    
    /// Called when display should be updated due to animation or state changes
    var onDisplayUpdateNeeded: (() -> Void)?
    
    // MARK: - Initialization
    
    init(stateManager: MenuBarStateManager) {
        self.stateManager = stateManager
        logger.info("StatusBarAnimationController initialized")
    }
    
    // MARK: - Public Methods
    
    /// Starts the animation and periodic update timers
    func startTimers() {
        logger.info("Starting animation timers")
        setupAnimationTimer()
        setupPeriodicTimer()
    }
    
    /// Stops all timers
    func stopTimers() {
        logger.info("Stopping animation timers")
        animationTimer?.invalidate()
        periodicTimer?.invalidate()
        animationTimer = nil
        periodicTimer = nil
    }
    
    /// Updates animation state and triggers display updates when needed
    func updateAnimationState() {
        stateManager.updateAnimation()
    }
    
    // MARK: - Private Methods
    
    private func setupAnimationTimer() {
        // Start with a slower interval and adapt based on animation needs
        startAdaptiveAnimationTimer()
    }
    
    private func startAdaptiveAnimationTimer(interval: TimeInterval = 0.1) {
        animationTimer?.invalidate()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }

                // Update animation state first
                self.stateManager.updateAnimation()

                let isActivelyAnimating = self.stateManager.currentState.isAnimated ||
                    self.stateManager.isTransitioning ||
                    self.stateManager.isCostTransitioning
                
                let valueChanged = abs(self.stateManager.animatedGaugeValue - self.lastRenderedValue) > 0.001

                // Always update animation state, but only update display if needed
                if isActivelyAnimating || valueChanged {
                    self.onDisplayUpdateNeeded?()
                    self.lastRenderedValue = self.stateManager.animatedGaugeValue
                } else {
                    // Still call display update but change detection will prevent unnecessary work
                    self.onDisplayUpdateNeeded?()
                }
                
                // Adapt timer frequency based on animation state
                let currentInterval = interval
                let targetInterval: TimeInterval
                
                if isActivelyAnimating {
                    // High frequency for smooth animations (30fps)
                    targetInterval = 0.033
                } else if valueChanged {
                    // Medium frequency for value changes (15fps)
                    targetInterval = 0.067
                } else {
                    // Low frequency when idle (5fps)
                    targetInterval = 0.2
                }
                
                // Only restart timer if frequency needs to change significantly
                if abs(currentInterval - targetInterval) > 0.01 {
                    self.startAdaptiveAnimationTimer(interval: targetInterval)
                }
            }
        }
    }
    
    private func setupPeriodicTimer() {
        // Periodic timer for tooltip updates and other non-critical updates
        // Run every 30 seconds to reduce CPU usage while keeping tooltips reasonably fresh
        periodicTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Only update if not actively animating to avoid conflicts
                guard let self,
                      !self.stateManager.currentState.isAnimated,
                      !self.stateManager.isTransitioning,
                      !self.stateManager.isCostTransitioning else { return }
                
                self.onDisplayUpdateNeeded?()
            }
        }
    }
    
    deinit {
        // Note: Timer invalidation cannot be safely done from deinit in Swift 6 strict concurrency
        // Timers will be cleaned up when the class is deallocated
        logger.info("StatusBarAnimationController deallocated")
    }
}