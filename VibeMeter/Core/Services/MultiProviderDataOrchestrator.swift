import Foundation
import os.log

// MARK: - Multi-Provider Data Orchestrator

/// Orchestrates data operations across multiple service providers.
///
/// This orchestrator manages data fetching, authentication, and synchronization
/// for all enabled providers simultaneously, allowing users to track costs
/// across multiple services in a unified interface.
@MainActor
public final class MultiProviderDataOrchestrator: ObservableObject {
    // MARK: - Dependencies

    private let providerFactory: ProviderFactory
    private let settingsManager: any SettingsManagerProtocol
    private let exchangeRateManager: ExchangeRateManagerProtocol
    private let notificationManager: NotificationManagerProtocol
    private let loginManager: MultiProviderLoginManager

    // MARK: - Data Models

    @Published
    public private(set) var spendingData: MultiProviderSpendingData
    @Published
    public private(set) var userSessionData: MultiProviderUserSessionData
    @Published
    public private(set) var currencyData: CurrencyData
    @Published
    public private(set) var gravatarService: GravatarService

    // MARK: - State

    @Published
    public private(set) var isRefreshing: [ServiceProvider: Bool] = [:]
    @Published
    public private(set) var lastRefreshDates: [ServiceProvider: Date] = [:]
    @Published
    public private(set) var refreshErrors: [ServiceProvider: String] = [:]

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.vibemeter", category: "MultiProviderOrchestrator")
    private var refreshTimers: [ServiceProvider: Timer] = [:]

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

        // Initialize user session state for providers with existing tokens
        for provider in loginManager.loggedInProviders {
            logger.info("Initializing session state for logged-in provider: \(provider.displayName)")
            // Create a basic logged-in session state until we fetch full data
            userSessionData.handleLoginSuccess(
                for: provider,
                email: "", // Will be updated when data is fetched
                teamName: nil,
                teamId: nil)
        }

        logger.info("MultiProviderDataOrchestrator initialized with \(loginManager.loggedInProviders.count) logged-in providers")
        
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

        logger.info("refreshAllProviders called for \(enabledProviders.count) providers: \(enabledProviders.map { $0.displayName }.joined(separator: ", "))")

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

            // Fetch user and team info
            async let userTask = providerClient.fetchUserInfo(authToken: authToken)
            async let teamTask = providerClient.fetchTeamInfo(authToken: authToken)

            let userInfo = try await userTask
            let teamInfo = try await teamTask

            logger.info("Fetched user info for \(provider.displayName): email=\(userInfo.email)")
            logger.info("Fetched team info for \(provider.displayName): name=\(teamInfo.name), id=\(teamInfo.id)")
            
            // Update session data
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

            // Fetch current month invoice
            let calendar = Calendar.current
            let month = calendar.component(.month, from: Date()) - 1 // 0-based for API
            let year = calendar.component(.year, from: Date())

            let invoice = try await providerClient.fetchMonthlyInvoice(
                authToken: authToken,
                month: month,
                year: year)

            logger.info("Fetched invoice for \(provider.displayName): total cents=\(invoice.totalSpendingCents)")
            
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
            logger.info("Current spending for \(provider.displayName): USD=\(self.spendingData.getSpendingData(for: provider)?.currentSpendingUSD ?? 0), display=\(self.spendingData.getSpendingData(for: provider)?.displaySpending ?? 0)")

        } catch let error as ProviderError where error == .unauthorized {
            logger.warning("Unauthorized for \(provider.displayName), logging out")
            loginManager.logOut(from: provider)

        } catch let error as ProviderError where error == .noTeamFound {
            logger.error("Team not found for \(provider.displayName)")
            userSessionData.setTeamFetchError(
                for: provider,
                message: "Hmm, can't find your team vibe right now. 😕 Try a refresh?")
            spendingData.clear(provider: provider)

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
            self?.logger.info("Login failure callback triggered for \(provider.displayName): \(error.localizedDescription)")
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
            guard spendingData.getSpendingData(for: provider) != nil else { continue }

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
