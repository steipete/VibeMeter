import Foundation
import os.log

/// Service responsible for processing fetched data and updating the application state.
@MainActor
final class DataProcessingService {
    // MARK: - Dependencies
    
    private let settingsManager: any SettingsManagerProtocol
    private let notificationManager: NotificationManagerProtocol
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.vibemeter", category: "DataProcessing")
    
    // MARK: - Initialization
    
    init(
        settingsManager: any SettingsManagerProtocol,
        notificationManager: NotificationManagerProtocol
    ) {
        self.settingsManager = settingsManager
        self.notificationManager = notificationManager
    }
    
    // MARK: - Public Methods
    
    /// Processes provider data result and updates all relevant data models.
    func processProviderData(
        _ result: ProviderDataResult,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        gravatarService: GravatarService
    ) {
        let provider = result.provider
        
        logger.info("Processing data for \(provider.displayName)")
        
        // Update session data
        userSessionData.handleLoginSuccess(
            for: provider,
            email: result.userInfo.email,
            teamName: result.teamInfo.name,
            teamId: result.teamInfo.id
        )
        
        // Sync with SettingsManager
        let providerSession = ProviderSession(
            provider: provider,
            teamId: result.teamInfo.id,
            teamName: result.teamInfo.name,
            userEmail: result.userInfo.email,
            isActive: true
        )
        settingsManager.updateSession(for: provider, session: providerSession)
        
        // Update spending data with currency conversion
        spendingData.updateSpending(
            for: provider,
            from: result.invoice,
            rates: result.exchangeRates,
            targetCurrency: result.targetCurrency
        )
        
        // Update usage data
        spendingData.updateUsage(for: provider, from: result.usage)
        
        // Update spending limits
        spendingData.updateLimits(
            for: provider,
            warningUSD: settingsManager.warningLimitUSD,
            upperUSD: settingsManager.upperLimitUSD,
            rates: result.exchangeRates,
            targetCurrency: result.targetCurrency
        )
        
        // Update Gravatar if this is the most recent user
        if let mostRecentSession = userSessionData.mostRecentSession,
           mostRecentSession.provider == provider {
            gravatarService.updateAvatar(for: result.userInfo.email)
        }
        
        logger.info("Successfully processed data for \(provider.displayName)")
    }
    
    /// Processes multiple provider data results.
    func processMultipleProviderData(
        _ results: [ServiceProvider: Result<ProviderDataResult, Error>],
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData,
        gravatarService: GravatarService
    ) -> [ServiceProvider: String] {
        var errors: [ServiceProvider: String] = [:]
        
        for (provider, result) in results {
            switch result {
            case .success(let data):
                processProviderData(data, userSessionData: userSessionData, spendingData: spendingData, gravatarService: gravatarService)
                
            case .failure(let error):
                let errorMessage = handleProviderError(error, for: provider, userSessionData: userSessionData, spendingData: spendingData)
                if let errorMessage {
                    errors[provider] = errorMessage
                }
            }
        }
        
        return errors
    }
    
    /// Updates currency conversions for all providers.
    func updateCurrencyConversions(
        spendingData: MultiProviderSpendingData,
        exchangeRates: [String: Double],
        targetCurrency: String
    ) {
        logger.info("Updating currency conversions to \(targetCurrency)")
        
        for provider in ServiceProvider.allCases {
            if spendingData.getSpendingData(for: provider) != nil {
                spendingData.updateLimits(
                    for: provider,
                    warningUSD: settingsManager.warningLimitUSD,
                    upperUSD: settingsManager.upperLimitUSD,
                    rates: exchangeRates,
                    targetCurrency: targetCurrency
                )
            }
        }
    }
    
    /// Checks spending limits and sends notifications if thresholds are exceeded.
    func checkLimitsAndNotify(spendingData: MultiProviderSpendingData) async {
        logger.info("Checking spending limits and notifications")
        
        let totalSpendingUSD = spendingData.totalSpendingUSD
        let warningLimit = settingsManager.warningLimitUSD
        let upperLimit = settingsManager.upperLimitUSD
        
        logger.info("Total spending: $\(totalSpendingUSD), Warning: $\(warningLimit), Upper: $\(upperLimit)")
        
        if totalSpendingUSD >= upperLimit {
            await notificationManager.showUpperLimitNotification(
                currentSpending: totalSpendingUSD,
                limitAmount: upperLimit,
                currencyCode: "USD"
            )
        } else if totalSpendingUSD >= warningLimit {
            await notificationManager.showWarningNotification(
                currentSpending: totalSpendingUSD,
                limitAmount: warningLimit,
                currencyCode: "USD"
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func handleProviderError(
        _ error: Error,
        for provider: ServiceProvider,
        userSessionData: MultiProviderUserSessionData,
        spendingData: MultiProviderSpendingData
    ) -> String? {
        logger.error("Error processing data for \(provider.displayName): \(error)")
        
        if let providerError = error as? ProviderError {
            switch providerError {
            case .unauthorized:
                logger.warning("Unauthorized for \(provider.displayName)")
                userSessionData.handleLogout(from: provider)
                return nil
                
            case .noTeamFound:
                logger.error("Team not found for \(provider.displayName)")
                userSessionData.setTeamFetchError(
                    for: provider,
                    message: "Hmm, can't find your team vibe right now. 😕 Try a refresh?"
                )
                spendingData.clear(provider: provider)
                return nil
                
            default:
                break
            }
        }
        
        let errorMessage = "Error fetching data: \(error.localizedDescription)".prefix(50)
        userSessionData.setErrorMessage(for: provider, message: String(errorMessage))
        return String(errorMessage)
    }
}