import Foundation
@testable import VibeMeter

@MainActor // If any methods are expected to be called on main actor
class ExchangeRateManagerMock: ExchangeRateManagerProtocol {
    var supportedCurrencies: [String] = ["USD", "EUR", "GBP"]
    var fallbackRates: [String: Double] = ["USD": 1.0, "EUR": 0.9, "GBP": 0.8]

    var fetchExchangeRatesCallCount = 0
    var getRatesCallCount = 0
    var convertCallCount = 0

    var ratesToReturn: [String: Double]? = ["USD": 1.0, "EUR": 0.92, "GBP": 0.82]
    var errorToReturn: Error?

    // To control specific conversion results if needed for fine-grained tests
    var mockConvertedAmount: Double?

    func fetchExchangeRates() async -> [String: Double]? {
        fetchExchangeRatesCallCount += 1
        if let error = errorToReturn {
            // In a real scenario, `fetchExchangeRates` might throw, but here it returns optional based on current
            // protocol.
            // For testing errors, you might set ratesToReturn to nil.
            LoggingService.debug(
                "[Mock] fetchExchangeRates returning nil due to simulated error: \(error.localizedDescription)",
                category: .exchangeRate
            )
            return nil
        }
        return ratesToReturn
    }

    func getRates() async -> [String: Double] {
        getRatesCallCount += 1
        if let error = errorToReturn {
            LoggingService.debug(
                "[Mock] getRates returning fallback due to simulated error: \(error.localizedDescription)",
                category: .exchangeRate
            )
            return fallbackRates
        }
        return ratesToReturn ?? fallbackRates
    }

    func convert(
        _ amount: Double,
        from sourceCurrency: String,
        to targetCurrency: String,
        rates: [String: Double]?
    ) -> Double? {
        convertCallCount += 1
        if let mockAmount = mockConvertedAmount {
            return mockAmount
        }
        // Basic mock conversion, not a full re-implementation
        guard let currentRates = rates, !currentRates.isEmpty else { return nil }
        if sourceCurrency == targetCurrency { return amount }

        let sourceRate = currentRates[sourceCurrency] ?? (sourceCurrency == "USD" ? 1.0 : nil)
        let targetRate = currentRates[targetCurrency] ?? (targetCurrency == "USD" ? 1.0 : nil)

        guard let sRate = sourceRate, let tRate = targetRate, sRate != 0 else { return nil }

        let amountInUSD = amount / sRate
        return amountInUSD * tRate
    }

    static func getSymbol(for currencyCode: String) -> String {
        // Return a simple mock symbol or delegate to the real one if complex logic isn't needed for most tests
        RealExchangeRateManager.getSymbol(for: currencyCode)
    }

    func reset() {
        fetchExchangeRatesCallCount = 0
        getRatesCallCount = 0
        convertCallCount = 0
        ratesToReturn = ["USD": 1.0, "EUR": 0.92, "GBP": 0.82] // Reset to default mock rates
        errorToReturn = nil
        mockConvertedAmount = nil
        supportedCurrencies = ["USD", "EUR", "GBP"]
        fallbackRates = ["USD": 1.0, "EUR": 0.9, "GBP": 0.8]
    }
}
