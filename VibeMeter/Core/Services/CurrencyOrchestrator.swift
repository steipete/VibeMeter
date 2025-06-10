import Foundation
import os.log

/// Manages currency conversion and spending limit notifications.
///
/// This orchestrator handles exchange rate updates, currency change observation,
/// limit notifications, and currency conversion coordination across all providers.
/// It ensures all spending data is properly converted and limits are checked.
@Observable
@MainActor
public final class CurrencyOrchestrator {
    // MARK: - Dependencies

    private let exchangeRateManager: ExchangeRateManagerProtocol
    private let notificationManager: NotificationManagerProtocol
    private let settingsManager: any SettingsManagerProtocol
    private let logger = Logger.vibeMeter(category: "CurrencyOrchestrator")

    // MARK: - Data Models

    public private(set) var currencyData: CurrencyData

    // MARK: - Callbacks

    public var onCurrencyChanged: ((String) async -> Void)?

    // MARK: - Initialization

    public init(
        exchangeRateManager: ExchangeRateManagerProtocol,
        notificationManager: NotificationManagerProtocol,
        settingsManager: any SettingsManagerProtocol,
        currencyData: CurrencyData = CurrencyData()) {
        self.exchangeRateManager = exchangeRateManager
        self.notificationManager = notificationManager
        self.settingsManager = settingsManager
        self.currencyData = currencyData

        setupCurrencyObservation()
        initializeCurrency()
        logger.info("CurrencyOrchestrator initialized")
    }

    // MARK: - Public Methods

    /// Updates currency for all providers and triggers conversion updates
    public func updateCurrency(to currencyCode: String) {
        logger.info("Updating currency from \(self.currencyData.selectedCode) to \(currencyCode)")

        Task {
            // Update exchange rates first
            await updateCurrencyConversions()

            // Trigger the callback to re-convert spending data BEFORE updating CurrencyData
            await onCurrencyChanged?(currencyCode)

            // Update CurrencyData LAST (this will trigger UI updates including status bar)
            currencyData.updateSelectedCurrency(currencyCode)
        }
    }

    /// Updates currency conversions for all providers using latest exchange rates
    public func updateCurrencyConversions(spendingData: MultiProviderSpendingData) async {
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
            spendingData.updateSpending(
                for: provider,
                from: invoice,
                rates: rates,
                targetCurrency: targetCurrency)

            // Update limits conversions
            spendingData.updateLimits(
                for: provider,
                warningUSD: settingsManager.warningLimitUSD,
                upperUSD: settingsManager.upperLimitUSD,
                rates: rates,
                targetCurrency: targetCurrency)
        }

        logger.info("Currency conversions updated for all providers")
    }

    /// Updates provider spending data with current currency settings
    public func updateProviderSpending(
        for provider: ServiceProvider,
        from invoice: ProviderMonthlyInvoice,
        spendingData: MultiProviderSpendingData) async {
        let rates = await exchangeRateManager.getExchangeRates()
        let targetCurrency = settingsManager.selectedCurrencyCode

        logger.info("Updating spending for \(provider.displayName) with currency: \(targetCurrency)")

        // Update CurrencyData with the fetched exchange rates
        currencyData.updateExchangeRates(rates, available: !rates.isEmpty)

        spendingData.updateSpending(
            for: provider,
            from: invoice,
            rates: rates,
            targetCurrency: targetCurrency)

        spendingData.updateLimits(
            for: provider,
            warningUSD: settingsManager.warningLimitUSD,
            upperUSD: settingsManager.upperLimitUSD,
            rates: rates,
            targetCurrency: targetCurrency)
    }

    /// Checks spending limits and sends notifications for all providers
    public func checkLimitsAndNotify(spendingData: MultiProviderSpendingData) async {
        logger.info("Checking spending limits and sending notifications")

        let targetCurrency = settingsManager.selectedCurrencyCode
        let exchangeRates = currencyData.currentExchangeRates

        for provider in ServiceProvider.allCases {
            await checkProviderLimitsAndNotify(
                provider: provider,
                spendingData: spendingData,
                targetCurrency: targetCurrency,
                exchangeRates: exchangeRates)
        }
    }

    /// Checks spending limits for a specific provider and sends notifications if needed
    public func checkProviderLimitsAndNotify(
        provider: ServiceProvider,
        spendingData: MultiProviderSpendingData,
        targetCurrency: String? = nil,
        exchangeRates: [String: Double]? = nil) async {
        guard let providerData = spendingData.getSpendingData(for: provider),
              let spendingUSD = providerData.currentSpendingUSD else {
            return
        }

        let currency = targetCurrency ?? settingsManager.selectedCurrencyCode
        let rates = exchangeRates ?? currencyData.currentExchangeRates
        let warningLimitUSD = settingsManager.warningLimitUSD
        let upperLimitUSD = settingsManager.upperLimitUSD

        // Convert amounts for display using CurrencyConversionHelper
        let exchangeRate = rates[currency]
        let displaySpending = CurrencyConversionHelper.convert(amount: spendingUSD, rate: exchangeRate)
        let displayWarningLimit = CurrencyConversionHelper.convert(amount: warningLimitUSD, rate: exchangeRate)
        let displayUpperLimit = CurrencyConversionHelper.convert(amount: upperLimitUSD, rate: exchangeRate)

        // Check and send notifications
        if spendingUSD >= upperLimitUSD {
            let upperLimitMessage = "Upper limit exceeded for \(provider.displayName): " +
                "\(displaySpending) \(currency) >= \(displayUpperLimit) \(currency)"
            logger.info("\(upperLimitMessage)")
            await notificationManager.showUpperLimitNotification(
                currentSpending: displaySpending,
                limitAmount: displayUpperLimit,
                currencyCode: currency)
        } else if spendingUSD >= warningLimitUSD {
            let warningLimitMessage = "Warning limit exceeded for \(provider.displayName): " +
                "\(displaySpending) \(currency) >= \(displayWarningLimit) \(currency)"
            logger.info("\(warningLimitMessage)")
            await notificationManager.showWarningNotification(
                currentSpending: displaySpending,
                limitAmount: displayWarningLimit,
                currencyCode: currency)
        }
    }

    // MARK: - Private Methods

    private func initializeCurrency() {
        let selectedCurrency = settingsManager.selectedCurrencyCode
        currencyData.updateSelectedCurrency(selectedCurrency)
        logger.info("Initialized currency to: \(selectedCurrency)")
    }

    private func setupCurrencyObservation() {
        logger.info("Setting up currency change observation")

        // Watch for currency changes in settings
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    let newCurrency = self.settingsManager.selectedCurrencyCode
                    if newCurrency != self.currencyData.selectedCode {
                        self.logger.info(
                            "Currency changed from \(self.currencyData.selectedCode) to \(newCurrency)")
                        self.updateCurrency(to: newCurrency)
                    }
                }
            }
    }

    private func updateCurrencyConversions() async {
        // This method updates just the currency data without spending data
        // It's used internally when currency changes
        let rates = await exchangeRateManager.getExchangeRates()
        currencyData.updateExchangeRates(rates, available: !rates.isEmpty)
        logger.info("Updated currency exchange rates: \(rates.count) rates available")
    }
}
