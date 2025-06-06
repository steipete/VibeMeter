import AppKit
import Foundation
import Network
import os.log

/// Manages network connectivity monitoring and app state transitions.
///
/// This manager handles network restoration/loss, app foreground/background transitions,
/// and stale data detection based on network state. It coordinates with the main
/// orchestrator to refresh data when appropriate.
@Observable
@MainActor
public final class NetworkStateManager {
    // MARK: - Dependencies

    private let networkMonitor = NetworkConnectivityMonitor()
    private let logger = Logger(subsystem: "com.vibemeter", category: "NetworkStateManager")

    // MARK: - Callbacks

    public var onNetworkRestored: (() async -> Void)?
    public var onNetworkLost: (() async -> Void)?
    public var onAppBecameActive: (() async -> Void)?

    // MARK: - Public Properties

    /// Current network connectivity status for display in UI
    public var networkStatus: String {
        networkMonitor.connectivityStatus
    }

    /// Whether the device is currently connected to the internet
    public var isNetworkConnected: Bool {
        networkMonitor.isConnected
    }

    // MARK: - Initialization

    public init() {
        setupNetworkMonitoring()
        setupAppStateMonitoring()
        logger.info("NetworkStateManager initialized")
    }

    // MARK: - Public Methods

    /// Starts stale data monitoring with the specified threshold
    public func startStaleDataMonitoring(
        spendingData: MultiProviderSpendingData,
        checkInterval: TimeInterval = 300,
        staleThreshold: TimeInterval = 3600) {
        logger.info("Starting stale data monitoring (interval: \(checkInterval)s, threshold: \(staleThreshold)s)")

        Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForStaleData(spendingData: spendingData, staleThreshold: staleThreshold)
            }
        }
    }

    /// Handles network restoration for providers with connection-related errors
    public func handleNetworkRestored(spendingData: MultiProviderSpendingData) async {
        logger.info("Handling network restoration")

        // Get providers that had connection-related errors
        let providersToRefresh = spendingData.providersWithData.filter { provider in
            guard let data = spendingData.getSpendingData(for: provider) else { return false }

            switch data.connectionStatus {
            case let .error(message):
                // Only refresh if the error was network-related
                let networkRelatedTerms = ["network", "connection", "timeout", "internet", "offline", "unreachable"]
                return networkRelatedTerms.contains { message.lowercased().contains($0) }
            case .stale:
                return true
            default:
                return false
            }
        }

        if !providersToRefresh.isEmpty {
            let refreshMessage = "Found \(providersToRefresh.count) providers needing refresh after network restore: " +
                "\(providersToRefresh.map(\.displayName).joined(separator: ", "))"
            logger.info("\(refreshMessage)")
            await onNetworkRestored?()
        } else {
            logger.info("No providers need refreshing after network restore")
        }
    }

    /// Handles network loss by marking connected providers as offline
    public func handleNetworkLost(spendingData: MultiProviderSpendingData) async {
        logger.info("Handling network loss")

        // Mark all currently connected/syncing providers as having connection errors
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider) {
                switch data.connectionStatus {
                case .connected, .syncing, .connecting:
                    logger.info("Marking \(provider.displayName) as offline due to network loss")
                    spendingData.updateConnectionStatus(
                        for: provider,
                        status: .error(message: "No internet connection"))
                default:
                    break // Keep existing error states
                }
            }
        }

        await onNetworkLost?()
    }

    /// Handles app becoming active by checking for stale data
    public func handleAppBecameActive(
        spendingData: MultiProviderSpendingData,
        staleThreshold: TimeInterval = 600) async {
        logger.info("App became active, checking for stale data")

        var shouldRefreshAny = false

        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider),
               data.isStale(olderThan: staleThreshold) {
                shouldRefreshAny = true
                break
            }
        }

        if shouldRefreshAny {
            logger.info("Found stale data after app activation, refreshing")
            // Force check connectivity first
            await networkMonitor.checkConnectivity()

            // Only refresh if we have connectivity
            if networkMonitor.isConnected {
                await onAppBecameActive?()
            } else {
                logger.warning("No network connectivity, skipping refresh after app activation")
            }
        }
    }

    // MARK: - Private Methods

    private func setupNetworkMonitoring() {
        logger.info("Setting up network connectivity monitoring")

        // Handle network restoration
        networkMonitor.onNetworkRestored = { [weak self] in
            guard let self else { return }
            self.logger.info("Network connectivity restored")
            // The actual handling will be done by the orchestrator through the callback
        }

        // Handle network loss
        networkMonitor.onNetworkLost = { [weak self] in
            guard let self else { return }
            self.logger.warning("Network connectivity lost")
            // The actual handling will be done by the orchestrator through the callback
        }

        // Handle connection type changes
        networkMonitor.onConnectionTypeChanged = { [weak self] newType in
            guard let self else { return }
            self.logger.info("Connection type changed to: \(newType?.displayName ?? "unknown")")
            await self.handleConnectionTypeChanged(to: newType)
        }
    }

    private func setupAppStateMonitoring() {
        logger.info("Setting up app state monitoring")

        // Monitor app becoming active (foreground)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main) { [weak self] _ in
            self?.logger.info("App became active")
            // The actual handling will be done by the orchestrator through the callback
        }

        // Monitor app becoming inactive (background)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main) { [weak self] _ in
            self?.logger.info("App became inactive")
        }
    }

    private func checkForStaleData(
        spendingData: MultiProviderSpendingData,
        staleThreshold: TimeInterval) async {
        for provider in spendingData.providersWithData {
            if let data = spendingData.getSpendingData(for: provider),
               data.connectionStatus == .connected,
               data.isStale(olderThan: staleThreshold) {
                let staleMessage = "Marking \(provider.displayName) as stale " +
                    "(last refresh: \(data.lastSuccessfulRefresh?.description ?? "never"))"
                logger.info("\(staleMessage)")
                spendingData.updateConnectionStatus(for: provider, status: .stale)
            }
        }
    }

    private func handleConnectionTypeChanged(to newType: NWInterface.InterfaceType?) async {
        logger.info("Connection type changed to: \(newType?.displayName ?? "unknown")")

        // If switching to an expensive connection, we might want to be more conservative
        if newType?.isTypicallyExpensive == true || networkMonitor.isExpensive {
            logger.info("Now on expensive connection, considering refresh strategy")
            // Could implement logic to reduce refresh frequency on expensive connections
        }

        // For now, just log the change. Future enhancement could adjust behavior based on connection type
    }
}
