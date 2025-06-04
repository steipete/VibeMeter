import Foundation
import os.log

// MARK: - Modern Exchange Rate Manager using Actor

/// Manages currency exchange rates with caching and fallback support.
///
/// ExchangeRateManager provides:
/// - Real-time exchange rates from the Frankfurter API
/// - Intelligent caching with 1-hour validity
/// - Fallback rates for offline operation
/// - Currency conversion calculations
///
/// The manager uses the actor model for thread-safe access to cached data.
/// All rates are based on USD as the base currency.
public actor ExchangeRateManager: ExchangeRateManagerProtocol {
    // MARK: - Properties

    private let urlSession: URLSessionProtocol
    private let logger = Logger(subsystem: "com.vibemeter", category: "ExchangeRate")

    // Cache
    private var cachedRates: [String: Double] = [:]
    private var lastFetchDate: Date?
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour

    // API Configuration
    private let apiURL = URL(string: "https://api.frankfurter.app/latest")!
    private let baseCurrency = "USD"

    // Supported currencies
    public nonisolated let supportedCurrencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "SEK", "NZD"]

    // MARK: - Singleton

    public static let shared = ExchangeRateManager()

    // MARK: - Initialization

    public init(urlSession: URLSessionProtocol = URLSession.shared) {
        self.urlSession = urlSession
    }

    // MARK: - Public Methods

    public func getExchangeRates() async -> [String: Double] {
        // Check cache validity
        if let lastFetch = lastFetchDate,
           !cachedRates.isEmpty,
           Date().timeIntervalSince(lastFetch) < cacheValidityDuration {
            logger.debug("Returning cached exchange rates")
            return cachedRates
        }

        // Fetch fresh rates
        do {
            let rates = try await fetchExchangeRates()
            cachedRates = rates
            lastFetchDate = Date()
            logger.info("Successfully fetched exchange rates for \(rates.count) currencies")
            return rates
        } catch {
            logger.error("Failed to fetch exchange rates: \(error)")
            return fallbackRates
        }
    }

    public nonisolated func convert(
        _ amount: Double,
        from sourceCurrency: String,
        to targetCurrency: String,
        rates: [String: Double]) -> Double? {
        // Same currency - no conversion needed
        if sourceCurrency == targetCurrency {
            return amount
        }

        // Direct conversion if available
        if sourceCurrency == "USD", let rate = rates[targetCurrency] {
            return amount * rate
        }

        // Reverse conversion
        if targetCurrency == "USD", let rate = rates[sourceCurrency], rate > 0 {
            return amount / rate
        }

        // Cross-currency conversion through USD
        if let sourceRate = rates[sourceCurrency],
           let targetRate = rates[targetCurrency],
           sourceRate > 0,
           targetRate > 0 {
            let amountInUSD = amount / sourceRate
            return amountInUSD * targetRate
        }

        return nil
    }

    public nonisolated var fallbackRates: [String: Double] {
        [
            "EUR": 0.85,
            "GBP": 0.73,
            "JPY": 110.0,
            "AUD": 1.35,
            "CAD": 1.25,
            "CHF": 0.92,
            "CNY": 6.45,
            "SEK": 8.8,
            "NZD": 1.4,
        ]
    }

    // MARK: - Private Methods

    private func fetchExchangeRates() async throws -> [String: Double] {
        var components = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "base", value: baseCurrency),
            URLQueryItem(
                name: "symbols",
                value: supportedCurrencies.filter { $0 != baseCurrency }.joined(separator: ",")),
        ]

        guard let url = components.url else {
            throw ExchangeRateError.invalidURL
        }

        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExchangeRateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ExchangeRateError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let ratesResponse = try decoder.decode(ExchangeRatesResponse.self, from: data)

        return ratesResponse.rates
    }

    // MARK: - Static Helpers

    private static let currencySymbols: [String: String] = [
        "USD": "$",
        "EUR": "€",
        "GBP": "£",
        "JPY": "¥",
        "AUD": "A$",
        "CAD": "C$",
        "CHF": "CHF",
        "CNY": "¥",
        "SEK": "kr",
        "NZD": "NZ$",
    ]

    public static func getSymbol(for currencyCode: String) -> String {
        currencySymbols[currencyCode] ?? currencyCode
    }
}

// MARK: - Supporting Types

/// API response structure for the Frankfurter exchange rate service.
///
/// Contains the base currency, date of rates, and a dictionary of
/// currency codes to their exchange rates relative to the base.
private struct ExchangeRatesResponse: Codable {
    let base: String
    let date: String
    let rates: [String: Double]
}
