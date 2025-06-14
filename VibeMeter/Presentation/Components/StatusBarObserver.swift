import AppKit
import Foundation
import os.log

/// Manages observation of data changes and system events that affect the status bar.
///
/// This observer handles monitoring of settings changes, appearance changes,
/// and data model changes to trigger appropriate status bar updates.
///
/// With NSObservationTrackingEnabled, this class now leverages automatic
/// observation tracking instead of manual polling.
@MainActor
final class StatusBarObserver {
    // MARK: - Private Properties

    private var observationTask: Task<Void, Never>?
    private let userSession: MultiProviderUserSessionData
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private let settingsManager: any SettingsManagerProtocol
    private let logger = Logger.vibeMeter(category: "StatusBarObserver")

    // State tracking for change detection
    private var lastObservedState: ObservedState?
    private var lastUpdateTime: Date = .distantPast
    private let updateThrottleInterval: TimeInterval = 0.5 // 500ms minimum between updates
    
    // Debounced state for spending data updates
    private let debouncedStateGroup = DebouncedGroup<ObservedState?>(
        initialModel: nil,
        duration: .milliseconds(300)
    )

    // MARK: - Callbacks

    /// Called when data changes require a status bar update
    var onDataChanged: (() -> Void)?

    /// Called when state manager needs to be updated due to data changes
    var onStateUpdateNeeded: (() -> Void)?
    
    /// Called when appearance changes (dark/light mode)
    var onAppearanceChanged: (() -> Void)?

    // MARK: - Automatic Observation

    /// Checks the current state and triggers updates if needed.
    /// With NSObservationTrackingEnabled, this method will automatically
    /// re-run when any Observable properties it accesses change.
    func checkForStateChanges() {
        // Capture current state snapshot
        let currentState = ObservedState(
            isLoggedIn: userSession.isLoggedInToAnyProvider,
            providersCount: spendingData.providersWithData.count,
            selectedCurrency: currencyData.selectedCode,
            upperLimit: settingsManager.upperLimitUSD,
            totalSpending: calculateTotalSpending())

        // Update the debounced state - this will automatically delay updates
        debouncedStateGroup.update(currentState)
    }

    // MARK: - Initialization

    init(
        userSession: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        currencyData: CurrencyData,
        settingsManager: any SettingsManagerProtocol) {
        self.userSession = userSession
        self.spendingData = spendingData
        self.currencyData = currencyData
        self.settingsManager = settingsManager

        logger.info("StatusBarObserver initialized")
        
        // Set up observation of debounced state changes
        setupDebouncedStateObservation()
    }

    // MARK: - Public Methods

    /// Starts observing data changes and system events
    func startObserving() {
        logger.info("Starting data observation")

        // Start modern observation using structured concurrency
        observationTask = Task { @MainActor [weak self] in
            guard let self else { return }

            // Set up notification observers and model observation using structured concurrency
            await withTaskGroup(of: Void.self) { group in
                // Observe settings changes
                group.addTask {
                    await self.observeSettingsChanges()
                }

                // Observe appearance changes
                group.addTask {
                    await self.observeAppearanceChanges()
                }

                // Observe @Observable model changes
                group.addTask {
                    await self.observeModelChanges()
                }
            }
        }
    }

    /// Stops observing data changes
    func stopObserving() {
        logger.info("Stopping data observation")
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - Private Methods
    
    private func setupDebouncedStateObservation() {
        // Use Combine to observe debounced state changes
        Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Monitor the debounced state group for changes
            for await _ in debouncedStateGroup.$model.values {
                guard let newState = debouncedStateGroup.model else { continue }
                
                // Check if state actually changed
                if hasStateChanged(newState), shouldUpdateNow() {
                    lastObservedState = newState
                    lastUpdateTime = Date()
                    
                    logger.debug("Debounced state change detected, updating status bar")
                    onStateUpdateNeeded?()
                }
            }
        }
    }

    private func observeSettingsChanges() async {
        let notificationSequence = NotificationCenter.default.notifications(
            named: UserDefaults.didChangeNotification)

        for await _ in notificationSequence {
            onDataChanged?()
        }
    }

    private func observeAppearanceChanges() async {
        let notificationSequence = DistributedNotificationCenter.default.notifications(
            named: Notification.Name("AppleInterfaceThemeChangedNotification"))

        for await _ in notificationSequence {
            logger.debug("Appearance changed, updating status bar")
            // Delay slightly to ensure the appearance change has propagated
            try? await Task.sleep(for: .milliseconds(100))
            onAppearanceChanged?()
            onDataChanged?()
        }
    }

    private func observeModelChanges() async {
        // With NSObservationTrackingEnabled, we no longer need manual polling.
        // The system will automatically track Observable property access and
        // trigger updates when those properties change.
        logger.info("Model observation started with automatic tracking")

        // Keep the task alive to maintain the observation context
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3600)) // Sleep for an hour
        }
    }

    // MARK: - Helper Methods

    private func hasStateChanged(_ newState: ObservedState) -> Bool {
        guard let lastState = lastObservedState else {
            return true // First observation, consider it a change
        }

        return lastState != newState
    }

    private func shouldUpdateNow() -> Bool {
        Date().timeIntervalSince(lastUpdateTime) >= updateThrottleInterval
    }

    private func calculateTotalSpending() -> Double {
        spendingData.totalSpendingConverted(to: "USD", rates: currencyData.effectiveRates)
    }

    deinit {
        observationTask?.cancel()
        logger.info("StatusBarObserver deallocated")
    }
}

// MARK: - ObservedState

/// Captures a snapshot of observable state for change detection
private struct ObservedState: Equatable {
    let isLoggedIn: Bool
    let providersCount: Int
    let selectedCurrency: String
    let upperLimit: Double
    let totalSpending: Double

    static func == (lhs: ObservedState, rhs: ObservedState) -> Bool {
        lhs.isLoggedIn == rhs.isLoggedIn &&
            lhs.providersCount == rhs.providersCount &&
            lhs.selectedCurrency == rhs.selectedCurrency &&
            abs(lhs.upperLimit - rhs.upperLimit) < 0.01 &&
            abs(lhs.totalSpending - rhs.totalSpending) < 0.01
    }
}
