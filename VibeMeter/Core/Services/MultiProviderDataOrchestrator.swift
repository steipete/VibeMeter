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

    private let logger = Logger(subsystem: "com.vibemeter", category: "MultiProviderOrchestrator")
    private var refreshTimers: [ServiceProvider: Timer] = [:]
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

        // Initialize refresh states
        for provider in ServiceProvider.allCases {
            isRefreshing[provider] = false
            logger.info("Set isRefreshing=false for \(provider.displayName)")
        }

        setupManagerCallbacks()
        setupRefreshTimers()

        // Initialize user session state for providers with existing tokens
        // Also check for inconsistent states (stored session data but no token)
        sessionStateManager.validateSessionConsistency(
            userSessionData: userSessionData,
            spendingData: spendingData)

        sessionStateManager.initializeExistingProviderSessions(
            userSessionData: userSessionData)

        logger
            .info(
                "MultiProviderDataOrchestrator initialized with \(loginManager.loggedInProviders.count) logged-in providers")

        // Trigger initial data refresh for providers with existing tokens
        Task {
            logger.info("Starting initial data refresh for logged-in providers")
            for provider in loginManager.loggedInProviders {
                logger.info("Triggering initial refresh for \(provider.displayName)")
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
    public func refreshAllProviders(showSyncedMessage: Bool = false) async {
        let enabledProviders = ProviderRegistry.shared.activeProviders

        logger
            .info(
                "refreshAllProviders called for \(enabledProviders.count) providers: \(enabledProviders.map(\.displayName).joined(separator: ", "))")

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
    public func refreshData(for provider: ServiceProvider, showSyncedMessage _: Bool = false) async {
        logger.info("refreshData called for \(provider.displayName)")

        guard ProviderRegistry.shared.isEnabled(provider) else {
            logger.debug("Provider \(provider.displayName) is disabled, skipping refresh")
            return
        }

        guard let authToken = loginManager.getAuthToken(for: provider) else {
            logger.info("No auth token for \(provider.displayName), marking as logged out")
            userSessionData.handleLogout(from: provider)
            return
        }

        logger.info("Found auth token for \(provider.displayName), proceeding with data fetch")

        // Check network connectivity before attempting refresh
        if !networkStateManager.isNetworkConnected {
            logger.warning("No network connectivity for \(provider.displayName), skipping refresh")
            spendingData.updateConnectionStatus(for: provider, status: .error(message: "No internet connection"))
            return
        }

        isRefreshing[provider] = true
        refreshErrors.removeValue(forKey: provider)
        logger.info("Set isRefreshing=true for \(provider.displayName)")

        // Update connection status to syncing
        spendingData.updateConnectionStatus(for: provider, status: .syncing)

        do {
            let providerClient = providerFactory.createProvider(for: provider)

            // Process data on background actor for better concurrency
            let result = try await backgroundProcessor.processProviderData(
                provider: provider,
                authToken: authToken,
                providerClient: providerClient)
            
            let userInfo = result.userInfo
            let teamInfo = result.teamInfo
            let invoice = result.invoice
            let usage = result.usage

            logger.info("Fetched user info for \(provider.displayName): email=\(userInfo.email)")
            logger.info("Fetched team info for \(provider.displayName): name=\(teamInfo.name), id=\(teamInfo.id)")
            logger.info("Fetched invoice for \(provider.displayName): total cents=\(invoice.totalSpendingCents)")
            logger
                .info(
                    "Fetched usage for \(provider.displayName): \(usage.currentRequests)/\(usage.maxRequests ?? 0) requests")

            // Update session data via session manager
            sessionStateManager.updateSessionAfterDataFetch(
                for: provider,
                userInfo: userInfo.email,
                teamInfo: (name: teamInfo.name, id: teamInfo.id),
                userSessionData: userSessionData)
            logger.info("Updated session data for \(provider.displayName)")

            // Update spending data via currency orchestrator
            await currencyOrchestrator.updateProviderSpending(
                for: provider,
                from: invoice,
                spendingData: spendingData)
            logger.info("Updated spending data for \(provider.displayName)")

            spendingData.updateUsage(for: provider, from: usage)
            logger.info("Updated usage data for \(provider.displayName)")

            lastRefreshDates[provider] = Date()

            // Update Gravatar if this is the most recent user
            if let mostRecentSession = userSessionData.mostRecentSession,
               mostRecentSession.provider == provider {
                gravatarService.updateAvatar(for: userInfo.email)
            }

            logger.info("Successfully refreshed data for \(provider.displayName)")
            let providerSpending = self.spendingData.getSpendingData(for: provider)
            let usdSpending = providerSpending?.currentSpendingUSD ?? 0
            let displaySpending = providerSpending?.displaySpending ?? 0
            logger
                .info(
                    "Current spending for \(provider.displayName): USD=\(usdSpending), display=\(displaySpending)")

            // Update connection status to connected on success
            spendingData.updateConnectionStatus(for: provider, status: .connected)

        } catch let error as ProviderError where error == .unauthorized || error == .noTeamFound {
            let errorMessage = error == .unauthorized ? "Authentication failed" : "Team data unavailable"
            logger.warning("\(errorMessage) for \(provider.displayName)")

            // Only clear session data for actual authentication failures
            if error == .unauthorized {
                logger.warning("Clearing session data due to authentication failure")
                // Update connection status
                spendingData.updateConnectionStatus(for: provider, status: .error(message: errorMessage))

                // Handle authentication error via session manager
                sessionStateManager.handleAuthenticationError(
                    for: provider,
                    error: error,
                    userSessionData: userSessionData,
                    spendingData: spendingData)
            } else {
                // For team not found, just set a warning but keep user logged in
                logger.info("Team data unavailable but user remains authenticated")
                spendingData.updateConnectionStatus(for: provider, status: .connected)
                userSessionData.setTeamFetchError(
                    for: provider,
                    message: "Team data unavailable, but you remain logged in.")
            }

        } catch let error as ProviderError where error == .rateLimitExceeded {
            logger.warning("Rate limit exceeded for \(provider.displayName)")
            spendingData.updateConnectionStatus(for: provider, status: .rateLimited(until: nil))
            refreshErrors[provider] = "Rate limit exceeded"

        } catch let error as NetworkRetryHandler.RetryableError {
            logger.error("Network error for \(provider.displayName): \(error)")
            if let status = ProviderConnectionStatus.from(error) {
                spendingData.updateConnectionStatus(for: provider, status: status)
            } else {
                spendingData.updateConnectionStatus(for: provider, status: .error(message: "Network error"))
            }
            refreshErrors[provider] = error.localizedDescription

        } catch {
            logger.error("Failed to refresh data for \(provider.displayName): \(error)")
            let errorMessage = "Error fetching data: \(error.localizedDescription)".prefix(50)
            refreshErrors[provider] = String(errorMessage)
            userSessionData.setErrorMessage(for: provider, message: String(errorMessage))

            // Update connection status for generic errors
            if let providerError = error as? ProviderError {
                spendingData.updateConnectionStatus(for: provider, status: .from(providerError))
            } else {
                spendingData.updateConnectionStatus(for: provider, status: .error(message: String(errorMessage)))
            }
        }

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
                self?.logger.info("Starting data refresh after login for \(provider.displayName)")
                await self?.refreshData(for: provider, showSyncedMessage: true)
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
        let interval = TimeInterval(settingsManager.refreshIntervalMinutes * 60)

        for provider in ServiceProvider.allCases {
            refreshTimers[provider]?.invalidate()

            refreshTimers[provider] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self,
                          ProviderRegistry.shared.isEnabled(provider),
                          self.userSessionData.isLoggedIn(to: provider) else { return }

                    self.logger.info("Timer fired for \(provider.displayName), refreshing data")
                    await self.refreshData(for: provider, showSyncedMessage: false)
                }
            }
        }
    }
}
