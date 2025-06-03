import Foundation
@testable import VibeMeter

@MainActor
final class ExchangeRateManagerMock: ExchangeRateManagerProtocol, MockResetProtocol, @unchecked Sendable {
    var supportedCurrencies: [String] = ["USD", "EUR", "GBP"]

    // Make this nonisolated to match protocol requirement
    nonisolated var fallbackRates: [String: Double] {
        ["USD": 1.0, "EUR": 0.9, "GBP": 0.8]
    }

    var fetchExchangeRatesCallCount = 0
    var getRatesCallCount = 0
    var convertCallCount = 0

    var ratesToReturn: [String: Double]? = ["USD": 1.0, "EUR": 0.92, "GBP": 0.82]
    var errorToReturn: Error?

    // To control specific conversion results if needed for fine-grained tests
    var mockConvertedAmount: Double?

    func getExchangeRates() async -> [String: Double] {
        fetchExchangeRatesCallCount += 1
        if errorToReturn != nil {
            return [:] // Return empty rates to simulate unavailable
        }
        return ratesToReturn ?? fallbackRates
    }

    nonisolated func convert(
        _ amount: Double,
        from sourceCurrency: String,
        to targetCurrency: String,
        rates: [String: Double]) -> Double? {
        // Basic mock conversion, not a full re-implementation
        if sourceCurrency == targetCurrency { return amount }

        let sourceRate = rates[sourceCurrency] ?? (sourceCurrency == "USD" ? 1.0 : nil)
        let targetRate = rates[targetCurrency] ?? (targetCurrency == "USD" ? 1.0 : nil)

        guard let sRate = sourceRate, let tRate = targetRate, sRate != 0 else { return nil }

        let amountInUSD = amount / sRate
        return amountInUSD * tRate
    }

    static func getSymbol(for currencyCode: String) -> String {
        // Return a simple mock symbol or delegate to the real one if complex logic isn't needed for most tests
        ExchangeRateManager.getSymbol(for: currencyCode)
    }

    func reset() {
        resetTracking()
        resetReturnValues()
    }

    func resetTracking() {
        fetchExchangeRatesCallCount = 0
        getRatesCallCount = 0
        convertCallCount = 0
    }

    func resetReturnValues() {
        ratesToReturn = ["USD": 1.0, "EUR": 0.92, "GBP": 0.82]
        errorToReturn = nil
        mockConvertedAmount = nil
        supportedCurrencies = ["USD", "EUR", "GBP"]
    }
}
