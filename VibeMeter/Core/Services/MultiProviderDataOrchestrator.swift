import Foundation
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

    // MARK: - Data Models

    public private(set) var spendingData: MultiProviderSpendingData
    public private(set) var userSessionData: MultiProviderUserSessionData
    public private(set) var currencyData: CurrencyData
    public private(set) var gravatarService: GravatarService

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
        self.currencyData = currencyData
        self.gravatarService = gravatarService

        // Initialize refresh states
        for provider in ServiceProvider.allCases {
            isRefreshing[provider] = false
            logger.info("Set isRefreshing=false for \(provider.displayName)")
        }

        setupLoginCallbacks()
        setupRefreshTimers()
        observeCurrencyChanges()

        // Initialize user session state for providers with existing tokens
        // Also check for inconsistent states (stored session data but no token)
        validateSessionConsistency()
        
        for provider in loginManager.loggedInProviders {
            logger.info("Initializing session state for logged-in provider: \(provider.displayName)")
            // Create a basic logged-in session state until we fetch full data
            userSessionData.handleLoginSuccess(
                for: provider,
                email: "", // Will be updated when data is fetched
                teamName: nil,
                teamId: nil)
        }

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
        }
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
        await updateCurrencyConversions()

        // Check limits and send notifications
        await checkLimitsAndNotify()
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

        isRefreshing[provider] = true
        refreshErrors.removeValue(forKey: provider)
        logger.info("Set isRefreshing=true for \(provider.displayName)")

        do {
            let providerClient = providerFactory.createProvider(for: provider)

            // Process data on background actor for better concurrency
            let (userInfo, teamInfo, invoice, usage) = try await backgroundProcessor.processProviderData(
                provider: provider,
                authToken: authToken,
                providerClient: providerClient)

            logger.info("Fetched user info for \(provider.displayName): email=\(userInfo.email)")
            logger.info("Fetched team info for \(provider.displayName): name=\(teamInfo.name), id=\(teamInfo.id)")
            logger.info("Fetched invoice for \(provider.displayName): total cents=\(invoice.totalSpendingCents)")
            logger
                .info(
                    "Fetched usage for \(provider.displayName): \(usage.currentRequests)/\(usage.maxRequests ?? 0) requests")

            // Update session data on main actor
            userSessionData.handleLoginSuccess(
                for: provider,
                email: userInfo.email,
                teamName: teamInfo.name,
                teamId: teamInfo.id)
            logger.info("Updated userSessionData for \(provider.displayName)")

            // Sync with SettingsManager
            let providerSession = ProviderSession(
                provider: provider,
                teamId: teamInfo.id,
                teamName: teamInfo.name,
                userEmail: userInfo.email,
                isActive: true)
            settingsManager.updateSession(for: provider, session: providerSession)
            logger.info("Updated SettingsManager session for \(provider.displayName)")

            // Update spending data
            let rates = await exchangeRateManager.getExchangeRates()
            let targetCurrency = settingsManager.selectedCurrencyCode
            logger.info("Currency conversion: target=\(targetCurrency), rates available=\(!rates.isEmpty)")

            spendingData.updateSpending(
                for: provider,
                from: invoice,
                rates: rates,
                targetCurrency: targetCurrency)
            logger.info("Updated spending data for \(provider.displayName)")

            spendingData.updateUsage(for: provider, from: usage)
            logger.info("Updated usage data for \(provider.displayName)")

            spendingData.updateLimits(
                for: provider,
                warningUSD: settingsManager.warningLimitUSD,
                upperUSD: settingsManager.upperLimitUSD,
                rates: rates,
                targetCurrency: targetCurrency)

            lastRefreshDates[provider] = Date()

            // Update Gravatar if this is the most recent user
            if let mostRecentSession = userSessionData.mostRecentSession,
               mostRecentSession.provider == provider {
                gravatarService.updateAvatar(for: userInfo.email)
            }

            logger.info("Successfully refreshed data for \(provider.displayName)")
            logger
                .info(
                    "Current spending for \(provider.displayName): USD=\(self.spendingData.getSpendingData(for: provider)?.currentSpendingUSD ?? 0), display=\(self.spendingData.getSpendingData(for: provider)?.displaySpending ?? 0)")

        } catch let error as ProviderError where error == .unauthorized {
            logger.warning("Unauthorized for \(provider.displayName), clearing session and logging out")
            // Clear all stored session data since the token is invalid
            userSessionData.handleLogout(from: provider)
            spendingData.clear(provider: provider)
            settingsManager.clearUserSessionData(for: provider)
            loginManager.logOut(from: provider)

        } catch let error as ProviderError where error == .noTeamFound {
            logger.error("Team not found for \(provider.displayName), clearing session data")
            // Clear session data since the stored team ID is invalid
            userSessionData.handleLogout(from: provider)
            spendingData.clear(provider: provider)
            settingsManager.clearUserSessionData(for: provider)
            loginManager.logOut(from: provider)
            userSessionData.setTeamFetchError(
                for: provider,
                message: "Team not found. Please log in again.")

        } catch {
            logger.error("Failed to refresh data for \(provider.displayName): \(error)")
            let errorMessage = "Error fetching data: \(error.localizedDescription)".prefix(50)
            refreshErrors[provider] = String(errorMessage)
            userSessionData.setErrorMessage(for: provider, message: String(errorMessage))
        }

        isRefreshing[provider] = false
        logger.info("Set isRefreshing=false for \(provider.displayName)")
    }

    /// Updates currency for all providers.
    public func updateCurrency(to currencyCode: String) {
        currencyData.updateSelectedCurrency(currencyCode)

        Task {
            await updateCurrencyConversions()
        }
    }

    /// Logs out from a specific provider.
    public func logout(from provider: ServiceProvider) {
        loginManager.logOut(from: provider)
        userSessionData.handleLogout(from: provider)
        spendingData.clear(provider: provider)
        settingsManager.clearUserSessionData(for: provider)

        logger.info("Logged out from \(provider.displayName)")
    }

    /// Logs out from all providers.
    public func logoutFromAll() {
        for provider in ServiceProvider.allCases {
            if userSessionData.isLoggedIn(to: provider) {
                logout(from: provider)
            }
        }

        logger.info("Logged out from all providers")
    }

    // MARK: - Private Methods

    private func validateSessionConsistency() {
        logger.info("Validating session consistency at startup")
        
        for provider in ServiceProvider.allCases {
            // Check if we have stored session data but no keychain token
            if let storedSession = settingsManager.getSession(for: provider),
               storedSession.isActive {
                
                let hasToken = loginManager.getAuthToken(for: provider) != nil
                
                if !hasToken {
                    logger.warning("Inconsistent state detected for \(provider.displayName): stored session active but no keychain token")
                    logger.warning("Clearing stale session data for \(provider.displayName)")
                    
                    // Clear the inconsistent session data
                    settingsManager.clearUserSessionData(for: provider)
                    userSessionData.handleLogout(from: provider)
                    spendingData.clear(provider: provider)
                } else {
                    logger.info("Session consistency validated for \(provider.displayName): both session and token present")
                }
            }
        }
    }

    private func observeCurrencyChanges() {
        // Observe settings manager currency changes
        Task {
            // Initial currency setup
            let selectedCurrency = settingsManager.selectedCurrencyCode
            currencyData.updateSelectedCurrency(selectedCurrency)

            // Watch for currency changes
            NotificationCenter.default.addObserver(
                forName: UserDefaults.didChangeNotification,
                object: nil,
                queue: .main) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        let newCurrency = self.settingsManager.selectedCurrencyCode
                        if newCurrency != self.currencyData.selectedCode {
                            self.logger
                                .info("Currency changed from \(self.currencyData.selectedCode) to \(newCurrency)")
                            self.updateCurrency(to: newCurrency)
                        }
                    }
                }
        }
    }

    private func setupLoginCallbacks() {
        logger.info("Setting up login callbacks")

        loginManager.onLoginSuccess = { [weak self] provider in
            self?.logger.info("Login success callback triggered for \(provider.displayName)")
            Task { @MainActor in
                self?.logger.info("Starting data refresh after login for \(provider.displayName)")
                await self?.refreshData(for: provider, showSyncedMessage: true)
            }
        }

        loginManager.onLoginFailure = { [weak self] provider, error in
            self?.logger
                .info("Login failure callback triggered for \(provider.displayName): \(error.localizedDescription)")
            self?.userSessionData.handleLoginFailure(for: provider, error: error)
        }

        loginManager.onLoginDismiss = { [weak self] provider in
            // Handle dismiss if needed
            self?.logger.info("Login dismissed for \(provider.displayName)")
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

    private func updateCurrencyConversions() async {
        logger.info("Updating currency conversions")
        let rates = await exchangeRateManager.getExchangeRates()
        let targetCurrency = settingsManager.selectedCurrencyCode
        logger.info("Got exchange rates: \(rates.count) rates, target currency: \(targetCurrency)")

        currencyData.updateExchangeRates(rates, available: !rates.isEmpty)

        // Update conversions for all providers
        for provider in ServiceProvider.allCases {
            guard let providerData = spendingData.getSpendingData(for: provider),
                  let invoice = providerData.latestInvoiceResponse else { continue }

            // Re-convert spending data with new currency
            self.spendingData.updateSpending(
                for: provider,
                from: invoice,
                rates: rates,
                targetCurrency: targetCurrency)

            // Update limits conversions
            self.spendingData.updateLimits(
                for: provider,
                warningUSD: settingsManager.warningLimitUSD,
                upperUSD: settingsManager.upperLimitUSD,
                rates: rates,
                targetCurrency: targetCurrency)
        }
    }

    private func checkLimitsAndNotify() async {
        let targetCurrency = settingsManager.selectedCurrencyCode
        _ = currencyData.currentExchangeRates

        for provider in ServiceProvider.allCases {
            guard let providerData = spendingData.getSpendingData(for: provider),
                  let spendingUSD = providerData.currentSpendingUSD else { continue }

            let warningLimitUSD = settingsManager.warningLimitUSD
            let upperLimitUSD = settingsManager.upperLimitUSD

            // Convert amounts for display
            let displaySpending = currencyData
                .convertAmount(spendingUSD, from: "USD", to: targetCurrency) ?? spendingUSD
            let displayWarningLimit = currencyData
                .convertAmount(warningLimitUSD, from: "USD", to: targetCurrency) ?? warningLimitUSD
            let displayUpperLimit = currencyData
                .convertAmount(upperLimitUSD, from: "USD", to: targetCurrency) ?? upperLimitUSD

            // Check and send notifications
            if spendingUSD >= upperLimitUSD {
                await notificationManager.showUpperLimitNotification(
                    currentSpending: displaySpending,
                    limitAmount: displayUpperLimit,
                    currencyCode: targetCurrency)
            } else if spendingUSD >= warningLimitUSD {
                await notificationManager.showWarningNotification(
                    currentSpending: displaySpending,
                    limitAmount: displayWarningLimit,
                    currencyCode: targetCurrency)
            }
        }
    }
}
