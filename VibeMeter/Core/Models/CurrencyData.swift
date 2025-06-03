import Foundation
import SwiftUI

/// Observable data model for currency-related state.
///
/// Handles:
/// - Selected currency preferences
/// - Exchange rates and availability
/// - Currency symbol display
@Observable
@MainActor
public final class CurrencyData {
    public private(set) var selectedCode = "USD"
    public private(set) var selectedSymbol = "$"
    public private(set) var exchangeRatesAvailable = true
    public private(set) var currentExchangeRates: [String: Double] = [:]

    public init() {}

    /// Updates the selected currency and symbol.
    public func updateSelectedCurrency(_ code: String) {
        selectedCode = code
        selectedSymbol = ExchangeRateManager.getSymbol(for: code)
    }

    /// Updates exchange rates and availability.
    public func updateExchangeRates(_ rates: [String: Double], available: Bool = true) {
        currentExchangeRates = rates
        exchangeRatesAvailable = available && !rates.isEmpty
    }

    /// Sets exchange rates as unavailable.
    public func setExchangeRatesUnavailable() {
        exchangeRatesAvailable = false
        currentExchangeRates = ExchangeRateManager.shared.fallbackRates
    }

    /// Converts an amount from one currency to another.
    public func convertAmount(_ amount: Double, from fromCurrency: String, to toCurrency: String) -> Double? {
        guard fromCurrency != toCurrency else { return amount }

        let rates = effectiveRates

        guard let fromRate = rates[fromCurrency],
              let toRate = rates[toCurrency] else {
            return nil
        }

        // Convert to USD first, then to target currency
        let usdAmount = amount / fromRate
        return usdAmount * toRate
    }

    /// Resets currency data to defaults.
    public func reset() {
        selectedCode = "USD"
        selectedSymbol = "$"
        exchangeRatesAvailable = true
        currentExchangeRates = [:]
    }

    /// Returns whether the current currency is USD.
    public var isUSD: Bool {
        selectedCode == "USD"
    }

    /// Returns the effective exchange rates (current or fallback).
    public var effectiveRates: [String: Double] {
        exchangeRatesAvailable ? currentExchangeRates : ExchangeRateManager.shared.fallbackRates
    }
}
