import Foundation
import SwiftUI

// MARK: - Provider-Specific Spending Data

/// Spending data for a specific service provider.
///
/// This model contains all spending information for a single provider,
/// including invoices, limits, and currency conversions.
public struct ProviderSpendingData: Codable, Sendable {
    public let provider: ServiceProvider
    public var currentSpendingUSD: Double?
    public var currentSpendingConverted: Double?
    public var warningLimitConverted: Double?
    public var upperLimitConverted: Double?
    public var latestInvoiceResponse: ProviderMonthlyInvoice?
    public var usageData: ProviderUsageData?
    public var lastUpdated: Date

    public init(
        provider: ServiceProvider,
        currentSpendingUSD: Double? = nil,
        currentSpendingConverted: Double? = nil,
        warningLimitConverted: Double? = nil,
        upperLimitConverted: Double? = nil,
        latestInvoiceResponse: ProviderMonthlyInvoice? = nil,
        usageData: ProviderUsageData? = nil,
        lastUpdated: Date = Date()) {
        self.provider = provider
        self.currentSpendingUSD = currentSpendingUSD
        self.currentSpendingConverted = currentSpendingConverted
        self.warningLimitConverted = warningLimitConverted
        self.upperLimitConverted = upperLimitConverted
        self.latestInvoiceResponse = latestInvoiceResponse
        self.usageData = usageData
        self.lastUpdated = lastUpdated
    }

    /// Returns the current spending in the preferred currency.
    public var displaySpending: Double? {
        currentSpendingConverted ?? currentSpendingUSD
    }

    /// Returns the warning limit in the preferred currency.
    public var displayWarningLimit: Double? {
        warningLimitConverted
    }

    /// Returns the upper limit in the preferred currency.
    public var displayUpperLimit: Double? {
        upperLimitConverted
    }

    /// Updates spending data from a monthly invoice and exchange rates.
    public mutating func updateSpending(
        from invoice: ProviderMonthlyInvoice,
        rates: [String: Double],
        targetCurrency: String) {
        currentSpendingUSD = Double(invoice.totalSpendingCents) / 100.0
        latestInvoiceResponse = invoice
        lastUpdated = Date()

        // Convert spending if not USD
        if targetCurrency != "USD", let spendingUSD = currentSpendingUSD {
            currentSpendingConverted = ExchangeRateManager.shared.convert(
                spendingUSD,
                from: "USD",
                to: targetCurrency,
                rates: rates)
        } else {
            currentSpendingConverted = currentSpendingUSD
        }
    }

    /// Updates limit conversions based on settings and exchange rates.
    public mutating func updateLimits(
        warningUSD: Double,
        upperUSD: Double,
        rates: [String: Double],
        targetCurrency: String) {
        if targetCurrency != "USD" {
            warningLimitConverted = ExchangeRateManager.shared.convert(
                warningUSD,
                from: "USD",
                to: targetCurrency,
                rates: rates) ?? warningUSD

            upperLimitConverted = ExchangeRateManager.shared.convert(
                upperUSD,
                from: "USD",
                to: targetCurrency,
                rates: rates) ?? upperUSD
        } else {
            warningLimitConverted = warningUSD
            upperLimitConverted = upperUSD
        }
        lastUpdated = Date()
    }

    /// Updates usage data from a provider usage response.
    public mutating func updateUsage(from usageData: ProviderUsageData) {
        self.usageData = usageData
        lastUpdated = Date()
    }

    /// Clears all spending data for this provider.
    public mutating func clear() {
        currentSpendingUSD = nil
        currentSpendingConverted = nil
        warningLimitConverted = nil
        upperLimitConverted = nil
        latestInvoiceResponse = nil
        usageData = nil
        lastUpdated = Date()
    }
}

// MARK: - Multi-Provider Spending Data Model

/// Enhanced observable model for spending data across multiple providers.
///
/// This model maintains spending information for all enabled providers
/// while providing backward compatibility with existing Cursor-only code.
@Observable
@MainActor
public final class MultiProviderSpendingData {
    // Provider-specific spending data
    public private(set) var providerSpending: [ServiceProvider: ProviderSpendingData] = [:]

    public init() {}

    // MARK: - Multi-Provider Methods

    /// Updates spending data for a specific provider.
    public func updateSpending(
        for provider: ServiceProvider,
        from invoice: ProviderMonthlyInvoice,
        rates: [String: Double],
        targetCurrency: String) {
        var data = providerSpending[provider] ?? ProviderSpendingData(provider: provider)
        data.updateSpending(from: invoice, rates: rates, targetCurrency: targetCurrency)
        providerSpending[provider] = data
    }

    /// Updates spending limits for a specific provider.
    public func updateLimits(
        for provider: ServiceProvider,
        warningUSD: Double,
        upperUSD: Double,
        rates: [String: Double],
        targetCurrency: String) {
        var data = providerSpending[provider] ?? ProviderSpendingData(provider: provider)
        data.updateLimits(warningUSD: warningUSD, upperUSD: upperUSD, rates: rates, targetCurrency: targetCurrency)
        providerSpending[provider] = data
    }

    /// Updates usage data for a specific provider.
    public func updateUsage(for provider: ServiceProvider, from usageData: ProviderUsageData) {
        var data = providerSpending[provider] ?? ProviderSpendingData(provider: provider)
        data.updateUsage(from: usageData)
        providerSpending[provider] = data
    }

    /// Clears spending data for a specific provider.
    public func clear(provider: ServiceProvider) {
        providerSpending.removeValue(forKey: provider)
    }

    /// Clears all spending data.
    public func clearAll() {
        providerSpending.removeAll()
    }

    /// Gets spending data for a specific provider.
    public func getSpendingData(for provider: ServiceProvider) -> ProviderSpendingData? {
        providerSpending[provider]
    }

    /// Gets all providers with spending data.
    public var providersWithData: [ServiceProvider] {
        Array(providerSpending.keys).sorted { $0.rawValue < $1.rawValue }
    }

    /// Gets total spending across all providers in USD.
    public var totalSpendingUSD: Double {
        providerSpending.values.compactMap(\.currentSpendingUSD).reduce(0, +)
    }

    /// Gets total spending across all providers in the target currency.
    public func totalSpendingConverted(to currency: String, rates: [String: Double]) -> Double {
        let totalUSD = totalSpendingUSD
        guard currency != "USD" else { return totalUSD }

        // Use direct conversion with fallback handling
        if let rate = rates[currency] {
            return totalUSD * rate
        }

        // If no rate available, try ExchangeRateManager fallback
        return ExchangeRateManager.shared.convert(
            totalUSD,
            from: "USD",
            to: currency,
            rates: rates) ?? totalUSD
    }

    /// Gets spending data for the most recently updated provider.
    public var mostRecentProvider: ServiceProvider? {
        providerSpending.values
            .sorted { $0.lastUpdated > $1.lastUpdated }
            .first?.provider
    }
}
