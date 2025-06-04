import Foundation

// MARK: - Exchange Rate Manager Protocol

/// Protocol defining the interface for currency exchange rate operations.
public protocol ExchangeRateManagerProtocol: Sendable {
    func getExchangeRates() async -> [String: Double]
    func convert(_ amount: Double, from: String, to: String, rates: [String: Double]) -> Double?
    var fallbackRates: [String: Double] { get }
}
