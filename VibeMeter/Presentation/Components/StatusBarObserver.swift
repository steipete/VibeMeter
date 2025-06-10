import AppKit
import Foundation
import os.log

/// Manages observation of data changes and system events that affect the status bar.
///
/// This observer handles monitoring of settings changes, appearance changes,
/// and data model changes to trigger appropriate status bar updates.
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

    // MARK: - Callbacks

    /// Called when data changes require a status bar update
    var onDataChanged: (() -> Void)?

    /// Called when state manager needs to be updated due to data changes
    var onStateUpdateNeeded: (() -> Void)?

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
            onDataChanged?()
        }
    }

    private func observeModelChanges() async {
        // Use withObservationTracking to observe @Observable models
        while !Task.isCancelled {
            withObservationTracking {
                // Capture current state snapshot
                let currentState = ObservedState(
                    isLoggedIn: userSession.isLoggedInToAnyProvider,
                    providersCount: spendingData.providersWithData.count,
                    selectedCurrency: currencyData.selectedCode,
                    upperLimit: settingsManager.upperLimitUSD,
                    totalSpending: calculateTotalSpending())

                // Check if state actually changed and enough time has passed
                if hasStateChanged(currentState), shouldUpdateNow() {
                    lastObservedState = currentState
                    lastUpdateTime = Date()

                    logger.debug("Significant model data change detected, updating status bar")
                    onStateUpdateNeeded?()
                }
            } onChange: {
                // This closure will be called when any of the observed properties change
                // We'll handle the actual update logic in the main tracking block
            }

            // Keep responsive 50ms delay - throttling handles update frequency
            try? await Task.sleep(for: .milliseconds(50))
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
