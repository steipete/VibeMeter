import Foundation
import os.log

/// Service responsible for fetching data from providers and updating the data models.
@MainActor
final class DataFetchingService {
    // MARK: - Dependencies

    private let providerFactory: ProviderFactory
    private let settingsManager: any SettingsManagerProtocol
    private let exchangeRateManager: ExchangeRateManagerProtocol
    private let loginManager: MultiProviderLoginManager

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.vibemeter", category: "DataFetching")

    // MARK: - Initialization

    init(
        providerFactory: ProviderFactory,
        settingsManager: any SettingsManagerProtocol,
        exchangeRateManager: ExchangeRateManagerProtocol,
        loginManager: MultiProviderLoginManager) {
        self.providerFactory = providerFactory
        self.settingsManager = settingsManager
        self.exchangeRateManager = exchangeRateManager
        self.loginManager = loginManager
    }

    // MARK: - Public Methods

    /// Fetches all data for a specific provider and returns the results.
    func fetchProviderData(for provider: ServiceProvider) async throws -> ProviderDataResult {
        logger.info("Starting data fetch for \(provider.displayName)")

        guard ProviderRegistry.shared.isEnabled(provider) else {
            throw DataFetchingError.providerDisabled(provider)
        }

        guard let authToken = loginManager.getAuthToken(for: provider) else {
            throw DataFetchingError.noAuthToken(provider)
        }

        let providerClient = providerFactory.createProvider(for: provider)

        // Fetch user and team info concurrently
        async let userTask = providerClient.fetchUserInfo(authToken: authToken)
        async let teamTask = providerClient.fetchTeamInfo(authToken: authToken)

        let userInfo = try await userTask
        let teamInfo = try await teamTask

        logger.info("Fetched user info for \(provider.displayName): email=\(userInfo.email)")
        logger.info("Fetched team info for \(provider.displayName): name=\(teamInfo.name), id=\(teamInfo.id)")

        // Fetch current month invoice and usage data
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date()) - 1 // 0-based for API
        let year = calendar.component(.year, from: Date())

        async let invoiceTask = providerClient.fetchMonthlyInvoice(
            authToken: authToken,
            month: month,
            year: year)
        async let usageTask = providerClient.fetchUsageData(authToken: authToken)

        let invoice = try await invoiceTask
        let usage = try await usageTask

        logger.info("Fetched invoice for \(provider.displayName): total cents=\(invoice.totalSpendingCents)")
        logger
            .info(
                "Fetched usage for \(provider.displayName): \(usage.currentRequests)/\(usage.maxRequests ?? 0) requests")

        // Get exchange rates for currency conversion
        let rates = await exchangeRateManager.getExchangeRates()
        let targetCurrency = settingsManager.selectedCurrencyCode

        return ProviderDataResult(
            provider: provider,
            userInfo: userInfo,
            teamInfo: teamInfo,
            invoice: invoice,
            usage: usage,
            exchangeRates: rates,
            targetCurrency: targetCurrency)
    }

    /// Fetches data for multiple providers concurrently.
    func fetchMultipleProviderData(for providers: [ServiceProvider]) async -> [ServiceProvider: Result<
        ProviderDataResult,
        Error
    >] {
        logger.info("Starting concurrent data fetch for \(providers.count) providers")

        var results: [ServiceProvider: Result<ProviderDataResult, Error>] = [:]

        await withTaskGroup(of: (ServiceProvider, Result<ProviderDataResult, Error>).self) { group in
            for provider in providers {
                group.addTask {
                    do {
                        let result = try await self.fetchProviderData(for: provider)
                        return (provider, .success(result))
                    } catch {
                        return (provider, .failure(error))
                    }
                }
            }

            for await (provider, result) in group {
                results[provider] = result
            }
        }

        return results
    }
}

// MARK: - Data Models

/// Result of fetching data from a provider.
struct ProviderDataResult {
    let provider: ServiceProvider
    let userInfo: ProviderUserInfo
    let teamInfo: ProviderTeamInfo
    let invoice: ProviderMonthlyInvoice
    let usage: ProviderUsageData
    let exchangeRates: [String: Double]
    let targetCurrency: String
}

// MARK: - Error Types

enum DataFetchingError: Error, LocalizedError {
    case providerDisabled(ServiceProvider)
    case noAuthToken(ServiceProvider)

    var errorDescription: String? {
        switch self {
        case let .providerDisabled(provider):
            "Provider \(provider.displayName) is disabled"
        case let .noAuthToken(provider):
            "No authentication token found for \(provider.displayName)"
        }
    }
}
