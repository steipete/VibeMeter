import Foundation
import os.log

// MARK: - Multi-Provider Data Processor

/// Processes successful data fetches from providers and updates internal state.
///
/// This processor handles the complex logic of updating user sessions, spending data,
/// currency conversions, and avatar updates after successful provider data retrieval.
final class MultiProviderDataProcessor: Sendable {
    // MARK: - Properties

    private let logger = Logger.vibeMeter(category: "MultiProviderDataProcessor")
    private let sessionStateManager: SessionStateManager
    private let currencyOrchestrator: CurrencyOrchestrator
    private let gravatarService: GravatarService
    private let burnRateCalculator = BurnRateCalculator()

    // MARK: - Initialization

    init(
        sessionStateManager: SessionStateManager,
        currencyOrchestrator: CurrencyOrchestrator,
        gravatarService: GravatarService) {
        self.sessionStateManager = sessionStateManager
        self.currencyOrchestrator = currencyOrchestrator
        self.gravatarService = gravatarService
    }

    // MARK: - Public Methods

    /// Processes a successful data fetch result from a provider.
    @MainActor
    func processSuccessfulRefresh(
        for provider: ServiceProvider,
        result: ProviderDataResult,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        lastRefreshDates: [ServiceProvider: Date]) async -> [ServiceProvider: Date] {
        let userInfo = result.userInfo
        let teamInfo = result.teamInfo
        let invoice = result.invoice
        let usage = result.usage

        logFetchedData(for: provider, userInfo: userInfo, teamInfo: teamInfo, invoice: invoice, usage: usage)

        var context = DataStoreContext(
            userSessionData: userSessionData,
            spendingData: spendingData,
            lastRefreshDates: lastRefreshDates)
        updateDataStores(
            for: provider,
            userInfo: userInfo,
            teamInfo: teamInfo,
            usage: usage,
            context: &context)

        await updateCurrencyAndSpending(for: provider, invoice: invoice, spendingData: spendingData)
        updateGravatarIfNeeded(for: provider, userEmail: userInfo.email, userSessionData: userSessionData)
        
        // Calculate and update burn rate
        await updateBurnRate(
            for: provider,
            invoice: invoice,
            usage: usage,
            spendingData: spendingData)
        
        logSuccessAndSpending(for: provider, spendingData: spendingData)

        spendingData.updateConnectionStatus(for: provider, status: .connected)

        return context.lastRefreshDates
    }

    // MARK: - Private Methods

    private func logFetchedData(
        for provider: ServiceProvider,
        userInfo: ProviderUserInfo,
        teamInfo: ProviderTeamInfo,
        invoice: ProviderMonthlyInvoice,
        usage: ProviderUsageData) {
        logger.info("Fetched user info for \(provider.displayName): email=\(userInfo.email)")
        logger.info("Fetched team info for \(provider.displayName): name=\(teamInfo.name), id=\(teamInfo.id)")
        logger.info("Fetched invoice for \(provider.displayName): total cents=\(invoice.totalSpendingCents)")
        let usageInfo = "Fetched usage for \(provider.displayName): " +
            "\(usage.currentRequests)/\(usage.maxRequests ?? 0) requests"
        logger.info("\(usageInfo)")
    }

    private struct DataStoreContext {
        let userSessionData: MultiProviderUserSessionData
        let spendingData: MultiProviderSpendingData
        var lastRefreshDates: [ServiceProvider: Date]
    }

    @MainActor
    private func updateDataStores(
        for provider: ServiceProvider,
        userInfo: ProviderUserInfo,
        teamInfo: ProviderTeamInfo,
        usage: ProviderUsageData,
        context: inout DataStoreContext) {
        sessionStateManager.updateSessionAfterDataFetch(
            for: provider,
            userInfo: userInfo.email,
            teamInfo: (name: teamInfo.name, id: teamInfo.id),
            userSessionData: context.userSessionData)
        logger.info("Updated session data for \(provider.displayName)")

        context.spendingData.updateUsage(for: provider, from: usage)
        logger.info("Updated usage data for \(provider.displayName)")

        context.lastRefreshDates[provider] = Date()
    }

    @MainActor
    private func updateCurrencyAndSpending(
        for provider: ServiceProvider,
        invoice: ProviderMonthlyInvoice,
        spendingData: MultiProviderSpendingData) async {
        await currencyOrchestrator.updateProviderSpending(
            for: provider,
            from: invoice,
            spendingData: spendingData)
        logger.info("Updated spending data for \(provider.displayName)")
    }

    @MainActor
    private func updateGravatarIfNeeded(
        for provider: ServiceProvider,
        userEmail: String,
        userSessionData: MultiProviderUserSessionData) {
        if let mostRecentSession = userSessionData.mostRecentSession,
           mostRecentSession.provider == provider {
            gravatarService.updateAvatar(for: userEmail)
        }
    }

    @MainActor
    private func logSuccessAndSpending(for provider: ServiceProvider, spendingData: MultiProviderSpendingData) {
        logger.info("Successfully refreshed data for \(provider.displayName)")
        let providerSpending = spendingData.getSpendingData(for: provider)
        let usdSpending = providerSpending?.currentSpendingUSD ?? 0
        let displaySpending = providerSpending?.displaySpending ?? 0
        logger.info("Current spending for \(provider.displayName): USD=\(usdSpending), display=\(displaySpending)")
    }
    
    @MainActor
    private func updateBurnRate(
        for provider: ServiceProvider,
        invoice: ProviderMonthlyInvoice,
        usage: ProviderUsageData,
        spendingData: MultiProviderSpendingData) async {
        
        // For Claude, we'll need to get token data from ClaudeProvider
        if provider == .claude {
            // Claude burn rate is calculated in MultiProviderDataOrchestrator.updateClaudeBurnRate()
            // because it needs access to ClaudeProvider's token data
            logger.info("Claude burn rate will be calculated separately using token data")
            return
        }
        
        // Calculate spending burn rate for other providers
        let spendingHistory: [(date: Date, amountCents: Int)]
        if !invoice.items.isEmpty {
            // Use recent invoice items as spending data points
            let now = Date()
            spendingHistory = [(date: now, amountCents: invoice.totalSpendingCents)]
        } else {
            spendingHistory = []
        }
        
        // Calculate burn rate
        let burnRate = burnRateCalculator.calculateSpendingBurnRate(
            provider: provider,
            spendingHistory: spendingHistory)
        
        // Calculate burn rate info with limits
        if let burnRate = burnRate {
            let currentSpending = Double(invoice.totalSpendingCents)
            let limit = spendingData.getSpendingData(for: provider)?.upperLimitConverted ?? 0
            let limitCents = limit * 100 // Convert to cents
            
            let burnRateInfo = burnRateCalculator.calculateBurnRateInfo(
                for: provider,
                currentUsage: currentSpending,
                limit: limitCents,
                burnRate: burnRate)
            
            spendingData.updateBurnRate(for: provider, burnRateInfo: burnRateInfo)
            
            logger.info("Updated burn rate for \(provider.displayName): \(burnRate.formattedRate)")
        }
    }
}
