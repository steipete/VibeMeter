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
    private let logger = Logger(subsystem: "com.vibemeter", category: "StatusBarObserver")
    
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
        settingsManager: any SettingsManagerProtocol
    ) {
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
            logger.debug("Settings changed, updating status bar")
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
                // Track changes to observable models
                _ = userSession.isLoggedInToAnyProvider
                _ = spendingData.providersWithData.count
                _ = currencyData.selectedCode
                _ = settingsManager.upperLimitUSD
            } onChange: {
                Task { @MainActor in
                    self.logger.debug("Model data changed, updating status bar state")
                    self.onStateUpdateNeeded?()
                }
            }
            
            // Small delay to prevent excessive updates
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
    
    deinit {
        observationTask?.cancel()
        logger.info("StatusBarObserver deallocated")
    }
}