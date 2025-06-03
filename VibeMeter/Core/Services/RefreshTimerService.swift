import Foundation
import os.log

/// Service responsible for managing automatic refresh timers for providers.
@MainActor
final class RefreshTimerService {
    // MARK: - Types
    
    typealias RefreshCallback = (ServiceProvider) async -> Void
    
    // MARK: - Private Properties
    
    private var refreshTimers: [ServiceProvider: Timer] = [:]
    private let logger = Logger(subsystem: "com.vibemeter", category: "RefreshTimer")
    private let settingsManager: any SettingsManagerProtocol
    private let refreshCallback: RefreshCallback
    
    // MARK: - Initialization
    
    init(settingsManager: any SettingsManagerProtocol, refreshCallback: @escaping RefreshCallback) {
        self.settingsManager = settingsManager
        self.refreshCallback = refreshCallback
        setupRefreshTimers()
        observeSettingsChanges()
    }
    
    deinit {
        // Timers will be cleaned up automatically when deallocated
    }
    
    // MARK: - Public Methods
    
    /// Starts refresh timer for a specific provider.
    func startTimer(for provider: ServiceProvider) {
        stopTimer(for: provider)
        
        let intervalMinutes = settingsManager.refreshIntervalMinutes
        let intervalSeconds = TimeInterval(intervalMinutes * 60)
        
        logger.info("Starting refresh timer for \(provider.displayName) with interval \(intervalMinutes) minutes")
        
        let timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshCallback(provider)
            }
        }
        
        refreshTimers[provider] = timer
    }
    
    /// Stops refresh timer for a specific provider.
    func stopTimer(for provider: ServiceProvider) {
        if let timer = refreshTimers[provider] {
            timer.invalidate()
            refreshTimers.removeValue(forKey: provider)
            logger.info("Stopped refresh timer for \(provider.displayName)")
        }
    }
    
    /// Restarts timer for a specific provider with current settings.
    func restartTimer(for provider: ServiceProvider) {
        stopTimer(for: provider)
        startTimer(for: provider)
    }
    
    /// Stops all refresh timers.
    func stopAllTimers() {
        for provider in refreshTimers.keys {
            stopTimer(for: provider)
        }
        logger.info("Stopped all refresh timers")
    }
    
    /// Restarts all timers with current settings.
    func restartAllTimers() {
        let providers = Array(refreshTimers.keys)
        stopAllTimers()
        
        for provider in providers {
            startTimer(for: provider)
        }
        
        logger.info("Restarted all refresh timers")
    }
    
    // MARK: - Private Methods
    
    private func setupRefreshTimers() {
        logger.info("Setting up refresh timers for all providers")
        
        for provider in ServiceProvider.allCases {
            if ProviderRegistry.shared.isEnabled(provider) {
                startTimer(for: provider)
            }
        }
    }
    
    private func observeSettingsChanges() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.handleSettingsChange()
            }
        }
    }
    
    @MainActor
    private func handleSettingsChange() async {
        logger.info("Settings changed, updating refresh timers")
        restartAllTimers()
    }
}