import AppKit
import Foundation
import Network
import os.log

// MARK: - Multi-Provider Data Orchestrator

/// Orchestrates data operations across multiple service providers.
///
/// This orchestrator manages data fetching, authentication, and synchronization
/// for all enabled providers simultaneously, allowing users to track costs
/// across multiple services in a unified interface.
///
/// Implements Swift 6 strict concurrency with proper isolation for data operations.
@Observable
@MainActor
public final class MultiProviderDataOrchestrator {
    // MARK: - Dependencies

    private let providerFactory: ProviderFactory
    private let settingsManager: any SettingsManagerProtocol
    private let exchangeRateManager: ExchangeRateManagerProtocol
    private let notificationManager: NotificationManagerProtocol
    private let loginManager: MultiProviderLoginManager

    // MARK: - Specialized Managers

    private let networkStateManager: NetworkStateManager
    private let sessionStateManager: SessionStateManager
    private let currencyOrchestrator: CurrencyOrchestrator
    private let errorHandler: MultiProviderErrorHandler
    private let dataProcessor: MultiProviderDataProcessor

    // MARK: - Data Models

    public private(set) var spendingData: MultiProviderSpendingData
    public private(set) var userSessionData: MultiProviderUserSessionData
    public private(set) var gravatarService: GravatarService

    // MARK: - Currency Data (delegated)

    public var currencyData: CurrencyData {
        currencyOrchestrator.currencyData
    }

    // MARK: - State

    public private(set) var isRefreshing: [ServiceProvider: Bool] = [:]
    public private(set) var lastRefreshDates: [ServiceProvider: Date] = [:]
    public private(set) var refreshErrors: [ServiceProvider: String] = [:]

    // MARK: - Private Properties

    private let logger = Logger.vibeMeter(category: "MultiProviderOrchestrator")
    private var refreshTasks: [ServiceProvider: Task<Void, Never>] = [:]
    private let backgroundProcessor = BackgroundDataProcessor()

    // MARK: - Initialization

    public init(
        providerFactory: ProviderFactory,
        settingsManager: any SettingsManagerProtocol,
        exchangeRateManager: ExchangeRateManagerProtocol,
        notificationManager: NotificationManagerProtocol,
        loginManager: MultiProviderLoginManager,
        spendingData: MultiProviderSpendingData = MultiProviderSpendingData(),
        userSessionData: MultiProviderUserSessionData = MultiProviderUserSessionData(),
        currencyData: CurrencyData = CurrencyData(),
        gravatarService: GravatarService = GravatarService.shared) {
        self.providerFactory = providerFactory
        self.settingsManager = settingsManager
        self.exchangeRateManager = exchangeRateManager
        self.notificationManager = notificationManager
        self.loginManager = loginManager
        self.spendingData = spendingData
        self.userSessionData = userSessionData
        self.gravatarService = gravatarService

        // Initialize specialized managers
        self.networkStateManager = NetworkStateManager()
        self.sessionStateManager = SessionStateManager(
            loginManager: loginManager,
            settingsManager: settingsManager)
        self.currencyOrchestrator = CurrencyOrchestrator(
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            settingsManager: settingsManager,
            currencyData: currencyData)
        self.errorHandler = MultiProviderErrorHandler(
            sessionStateManager: sessionStateManager,
            loginManager: loginManager)
        self.dataProcessor = MultiProviderDataProcessor(
            sessionStateManager: sessionStateManager,
            currencyOrchestrator: currencyOrchestrator,
            gravatarService: gravatarService)

        // Initialize refresh states
        for provider in ServiceProvider.allCases {
            isRefreshing[provider] = false
            logger.info("Set isRefreshing=false for \(provider.displayName)")
        }

        // Set orchestrator reference in login manager
        loginManager.orchestrator = self

        setupManagerCallbacks()
        setupRefreshTimers()

        // Initialize user session state for providers with existing tokens
        // Also check for inconsistent states (stored session data but no token)
        sessionStateManager.validateSessionConsistency(
            userSessionData: userSessionData,
            spendingData: spendingData)

        sessionStateManager.initializeExistingProviderSessions(
            userSessionData: userSessionData)

        let providerCount = loginManager.loggedInProviders.count
        logger.info("MultiProviderDataOrchestrator initialized with \(providerCount) logged-in providers")

        // Trigger initial data refresh for providers with existing tokens
        Task {
            let loggedInProviders = loginManager.loggedInProviders
            logger.info("Starting initial data refresh for \(loggedInProviders.count) logged-in providers")

            for provider in loggedInProviders {
                logger.info("Triggering initial refresh for \(provider.displayName)")
                if provider == .claude {
                    let hasToken = loginManager.getAuthToken(for: provider) != nil
                    logger.info("Claude: Initial check - hasToken: \(hasToken)")
                }
                await refreshData(for: provider, showSyncedMessage: false)
            }

            // Start monitoring systems
            networkStateManager.startStaleDataMonitoring(spendingData: spendingData)
        }
    }

    // MARK: - Public Properties

    /// Current network connectivity status for display in UI
    public var networkStatus: String {
        networkStateManager.networkStatus
    }

    /// Whether the device is currently connected to the internet
    public var isNetworkConnected: Bool {
        networkStateManager.isNetworkConnected
    }

    // MARK: - Public Methods

    /// Refreshes data for all enabled providers.
    @MainActor
    public func refreshAllProviders(showSyncedMessage: Bool = false) async {
        let enabledProviders = ProviderRegistry.shared.activeProviders

        let providerNames = enabledProviders.map(\.displayName).joined(separator: ", ")
        logger.info("refreshAllProviders called for \(enabledProviders.count) providers: \(providerNames)")

        await withTaskGroup(of: Void.self) { group in
            for provider in enabledProviders {
                group.addTask {
                    await self.refreshData(for: provider, showSyncedMessage: showSyncedMessage)
                }
            }
        }

        // Update currency conversions after all data is fetched
        await currencyOrchestrator.updateCurrencyConversions(spendingData: spendingData)

        // Check limits and send notifications
        await currencyOrchestrator.checkLimitsAndNotify(spendingData: spendingData)
    }

    /// Refreshes data for a specific provider.
    @MainActor
    public func refreshData(for provider: ServiceProvider, showSyncedMessage _: Bool = false) async {
        logger.info("refreshData called for \(provider.displayName)")

        guard validateRefreshPreconditions(for: provider) else { return }
        guard let authToken = getAuthTokenOrHandleLogout(for: provider) else { return }

        await performRefreshOperation(for: provider, authToken: authToken)
    }

    // MARK: - Private Refresh Helpers

    @MainActor
    private func validateRefreshPreconditions(for provider: ServiceProvider) -> Bool {
        guard ProviderRegistry.shared.isEnabled(provider) else {
            logger.debug("Provider \(provider.displayName) is disabled, skipping refresh")
            return false
        }

        guard networkStateManager.isNetworkConnected else {
            logger.warning("No network connectivity for \(provider.displayName), skipping refresh")
            spendingData.updateConnectionStatus(for: provider, status: .error(message: "No internet connection"))
            return false
        }

        return true
    }

    @MainActor
    private func getAuthTokenOrHandleLogout(for provider: ServiceProvider) -> String? {
        guard let authToken = loginManager.getAuthToken(for: provider) else {
            logger.info("No auth token for \(provider.displayName), marking as logged out")
            if provider == .claude {
                logger.info("Claude: Token check failed - user needs to grant folder access")
            }
            userSessionData.handleLogout(from: provider)
            return nil
        }

        logger.info("Found auth token for \(provider.displayName), proceeding with data fetch")
        if provider == .claude {
            logger.info("Claude: Token found ('\(authToken)'), will fetch data")
        }
        return authToken
    }

    @MainActor
    private func performRefreshOperation(for provider: ServiceProvider, authToken: String) async {
        startRefresh(for: provider)

        do {
            let result = try await fetchProviderData(for: provider, authToken: authToken)
            await processSuccessfulRefresh(for: provider, result: result)
        } catch {
            handleRefreshError(for: provider, error: error)
        }

        finishRefresh(for: provider)
    }

    @MainActor
    private func startRefresh(for provider: ServiceProvider) {
        isRefreshing[provider] = true
        refreshErrors.removeValue(forKey: provider)
        spendingData.updateConnectionStatus(for: provider, status: .syncing)
        logger.info("Set isRefreshing=true for \(provider.displayName)")
    }

    private func fetchProviderData(for provider: ServiceProvider,
                                   authToken: String) async throws -> ProviderDataResult {
        let providerClient = providerFactory.createProvider(for: provider)

        return try await backgroundProcessor.processProviderData(
            provider: provider,
            authToken: authToken,
            providerClient: providerClient)
    }

    @MainActor
    private func processSuccessfulRefresh(for provider: ServiceProvider, result: ProviderDataResult) async {
        lastRefreshDates = await dataProcessor.processSuccessfulRefresh(
            for: provider,
            result: result,
            userSessionData: userSessionData,
            spendingData: spendingData,
            lastRefreshDates: lastRefreshDates)
    }

    @MainActor
    private func handleRefreshError(for provider: ServiceProvider, error: Error) {
        refreshErrors = errorHandler.handleRefreshError(
            for: provider,
            error: error,
            userSessionData: userSessionData,
            spendingData: spendingData,
            refreshErrors: refreshErrors)
    }

    @MainActor
    private func finishRefresh(for provider: ServiceProvider) {
        isRefreshing[provider] = false
        logger.info("Set isRefreshing=false for \(provider.displayName)")
    }

    /// Updates currency for all providers.
    public func updateCurrency(to currencyCode: String) {
        currencyOrchestrator.updateCurrency(to: currencyCode)
    }

    /// Logs out from a specific provider.
    public func logout(from provider: ServiceProvider) {
        sessionStateManager.handleLogout(
            from: provider,
            userSessionData: userSessionData,
            spendingData: spendingData)
    }

    /// Logs out from all providers.
    public func logoutFromAll() {
        sessionStateManager.handleLogoutFromAll(
            userSessionData: userSessionData,
            spendingData: spendingData)
    }

    // MARK: - Private Methods

    private func setupManagerCallbacks() {
        logger.info("Setting up manager callbacks")

        // Session state manager callbacks
        sessionStateManager.onLoginSuccess = { [weak self] provider in
            Task { @MainActor in
                guard let self else { return }
                self.logger.info("Starting data refresh after login for \(provider.displayName)")
                // Clear any existing data to ensure we don't show stale data from previous account
                self.spendingData.clear(provider: provider)
                self.logger.info("Cleared previous spending data for \(provider.displayName)")
                await self.refreshData(for: provider, showSyncedMessage: true)
            }
        }

        sessionStateManager.onLoginFailure = { [weak self] provider, error in
            self?.userSessionData.handleLoginFailure(for: provider, error: error)
        }

        sessionStateManager.onLoginDismiss = { [weak self] provider in
            self?.logger.info("Login dismissed for \(provider.displayName)")
        }

        // Network state manager callbacks
        networkStateManager.onNetworkRestored = { [weak self] in
            guard let self else { return }
            await self.networkStateManager.handleNetworkRestored(spendingData: self.spendingData)
        }

        networkStateManager.onNetworkLost = { [weak self] in
            guard let self else { return }
            await self.networkStateManager.handleNetworkLost(spendingData: self.spendingData)
        }

        networkStateManager.onAppBecameActive = { [weak self] in
            guard let self else { return }
            await self.networkStateManager.handleAppBecameActive(spendingData: self.spendingData)
        }

        // Currency orchestrator callbacks
        currencyOrchestrator.onCurrencyChanged = { [weak self] _ in
            guard let self else { return }
            // Re-convert all existing spending data to the new currency
            await self.currencyOrchestrator.updateCurrencyConversions(spendingData: self.spendingData)
        }
    }

    private func setupRefreshTimers() {
        let intervalMinutes = settingsManager.refreshIntervalMinutes
        let intervalSeconds = intervalMinutes * 60

        for provider in ServiceProvider.allCases {
            refreshTasks[provider]?.cancel()

            if provider == .claude {
                // Special handling for Claude with adaptive refresh rate
                refreshTasks[provider] = Task { [weak self] in
                    while !Task.isCancelled {
                        guard let self else { break }

                        // Check usage level to determine refresh interval
                        let refreshInterval = await self.getClaudeRefreshInterval()

                        try? await Task.sleep(for: .seconds(refreshInterval))

                        guard !Task.isCancelled else { break }

                        await MainActor.run {
                            guard ProviderRegistry.shared.isEnabled(provider),
                                  self.userSessionData.isLoggedIn(to: provider) else { return }

                            self.logger
                                .info("Claude adaptive timer fired (interval: \(refreshInterval)s), refreshing data")
                        }

                        await self.refreshData(for: provider, showSyncedMessage: false)
                    }
                }
            } else {
                // Regular timer for other providers
                refreshTasks[provider] = Task { [weak self] in
                    for await _ in AsyncTimerSequence.seconds(intervalSeconds) {
                        guard let self else { break }

                        await MainActor.run {
                            guard ProviderRegistry.shared.isEnabled(provider),
                                  self.userSessionData.isLoggedIn(to: provider) else { return }

                            self.logger.info("Timer fired for \(provider.displayName), refreshing data")
                        }

                        await self.refreshData(for: provider, showSyncedMessage: false)

                        // Check if task was cancelled
                        if Task.isCancelled { break }
                    }
                }
            }
        }
    }

    /// Determine refresh interval for Claude based on current usage
    private func getClaudeRefreshInterval() async -> TimeInterval {
        // Get current usage percentage
        if let claudeData = spendingData.getSpendingData(for: .claude),
           let usageData = claudeData.usageData {
            let usagePercentage = Double(usageData.currentRequests) // Already 0-100

            // Adaptive refresh rates based on usage
            switch usagePercentage {
            case 80 ... 100:
                // Very high usage: refresh every 30 seconds
                return 30
            case 60 ..< 80:
                // High usage: refresh every minute
                return 60
            case 40 ..< 60:
                // Medium usage: refresh every 2 minutes
                return 120
            default:
                // Low usage: use normal interval
                return Double(settingsManager.refreshIntervalMinutes * 60)
            }
        }

        // Default to normal interval
        return Double(settingsManager.refreshIntervalMinutes * 60)
    }
}
