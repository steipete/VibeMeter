import Foundation

// Protocol for ExchangeRateManager
@MainActor
protocol ExchangeRateManagerProtocol {
    var supportedCurrencies: [String] { get }
    var fallbackRates: [String: Double] { get }

    func fetchExchangeRates() async -> [String: Double]?
    func getRates() async -> [String: Double]
    func convert(
        _ amount: Double,
        from sourceCurrency: String,
        to targetCurrency: String,
        rates: [String: Double]?
    ) -> Double?
}

// Companion object for shared instance and testability
@MainActor
final class ExchangeRateManagerImpl {
    static var shared: ExchangeRateManagerProtocol = RealExchangeRateManager()

    // Test-only method to inject a mock shared instance
    static func _test_setSharedInstance(instance: ExchangeRateManagerProtocol) {
        shared = instance
    }

    // Test-only method to reset to the real shared instance
    static func _test_resetSharedInstance() {
        shared = RealExchangeRateManager()
    }

    private init() {} // Prevent direct instantiation
}

// Make the existing ExchangeRateManager class conform to the protocol
// and rename it to RealExchangeRateManager
@MainActor
class RealExchangeRateManager: ExchangeRateManagerProtocol {
    private let userDefaults: UserDefaults
    private let session: URLSessionProtocol

    // Publicly accessible keys for UserDefaults, useful for testing or other modules if ever needed.
    enum Keys {
        static let cachedExchangeRates = "cachedExchangeRates"
        static let lastExchangeRateFetchTimestamp = "lastExchangeRateFetchTimestamp"
    }

    let supportedCurrencies: [String] = ["USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY", "INR", "PHP"]

    // Fallback rates, ensure these match the supportedCurrencies list in terms of keys.
    // Values should be relative to USD = 1.0.
    let fallbackRates: [String: Double] = [
        "USD": 1.0,
        "EUR": 0.93, // Example rate
        "GBP": 0.82, // Example rate
        "JPY": 149.0, // Example rate
        "CAD": 1.37, // Example rate
        "AUD": 1.56, // Example rate
        "CHF": 0.90, // Example rate
        "CNY": 7.30, // Example rate
        "INR": 83.20, // Example rate
        "PHP": 56.80, // Example rate
    ]

    private let apiBaseURL = "https://api.frankfurter.app/latest"

    init(userDefaults: UserDefaults = .standard, session: URLSessionProtocol = URLSession.shared) {
        self.userDefaults = userDefaults
        self.session = session
        LoggingService.info("RealExchangeRateManager initialized.", category: .exchangeRate)
    }

    func fetchExchangeRates() async -> [String: Double]? {
        // Construct the 'to' currencies string, excluding USD itself as it's the base
        let toCurrencies = supportedCurrencies.filter { $0 != "USD" }.joined(separator: ",")
        guard !toCurrencies.isEmpty else {
            LoggingService.warning(
                "No currencies (excluding USD) configured for fetching rates.",
                category: .exchangeRate
            )
            // If only USD is supported, effectively no rates to fetch, return base USD rate.
            var ratesWithUSD = fallbackRates // Start with fallbacks in case of an odd setup
            ratesWithUSD["USD"] = 1.0
            return ratesWithUSD
        }

        guard var urlComponents = URLComponents(string: apiBaseURL) else {
            LoggingService.error("Invalid base API URL for exchange rates: \(apiBaseURL)", category: .exchangeRate)
            return nil
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "from", value: "USD"),
            URLQueryItem(name: "to", value: toCurrencies),
        ]

        guard let url = urlComponents.url else {
            LoggingService.error("Failed to construct final API URL with components.", category: .exchangeRate)
            return nil
        }

        do {
            LoggingService.info("Fetching exchange rates from: \(url.absoluteString)", category: .exchangeRate)
            let (data, response) = try await session.data(for: URLRequest(url: url))

            guard let httpResponse = response as? HTTPURLResponse else {
                LoggingService.error("Did not receive HTTPURLResponse from exchange rate API.", category: .exchangeRate)
                return nil
            }

            guard httpResponse.statusCode == 200 else {
                LoggingService.error(
                    "Exchange rate API request failed with status code: \(httpResponse.statusCode)",
                    category: .exchangeRate
                )
                // Attempt to log response body for debugging if non-200
                if let responseBody = String(data: data, encoding: .utf8) {
                    LoggingService.debug(
                        "Exchange rate API error response body: \(responseBody)",
                        category: .exchangeRate
                    )
                }
                return nil
            }

            let decoder = JSONDecoder()
            let apiResponse = try decoder.decode(FrankfurterResponse.self, from: data)

            var rates = apiResponse.rates
            rates["USD"] = 1.0 // Ensure USD is explicitly included as 1.0, as it's the base

            userDefaults.set(rates, forKey: Keys.cachedExchangeRates)
            userDefaults.set(Date(), forKey: Keys.lastExchangeRateFetchTimestamp)
            LoggingService.info(
                "Successfully fetched and cached \(rates.count) exchange rates.",
                category: .exchangeRate
            )
            return rates
        } catch let decodingError as DecodingError {
            LoggingService.error(
                "Failed to decode exchange rates JSON: \(decodingError.localizedDescription). " +
                    "Details: \(decodingError)",
                category: .exchangeRate
            )
            return nil
        } catch {
            LoggingService.error(
                "Failed to fetch or process exchange rates: \(error.localizedDescription)",
                category: .exchangeRate
            )
            return nil
        }
    }

    func getRates() async -> [String: Double] {
        if let lastFetchTimestamp = userDefaults.object(forKey: Keys.lastExchangeRateFetchTimestamp) as? Date,
           let cachedRates = userDefaults.dictionary(forKey: Keys.cachedExchangeRates) as? [String: Double] {
            // Cache is considered valid if fetched within the last 24 hours (spec implies daily refresh)
            let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date()) ?? Date.distantPast
            if lastFetchTimestamp > twentyFourHoursAgo {
                LoggingService.info("Using cached exchange rates (fetched within 24 hours).", category: .exchangeRate)
                return cachedRates
            }
        }

        LoggingService.info(
            "Cache outdated, missing, or older than 24 hours. Fetching new exchange rates.",
            category: .exchangeRate
        )
        if let fetchedRates = await fetchExchangeRates() {
            return fetchedRates
        } else {
            LoggingService.warning("Failed to fetch new rates, using fallback rates.", category: .exchangeRate)
            return fallbackRates
        }
    }

    func convert(
        _ amount: Double,
        from sourceCurrency: String,
        to targetCurrency: String,
        rates: [String: Double]?
    ) -> Double? {
        guard let validRates = rates, !validRates.isEmpty else {
            LoggingService.warning(
                "Conversion attempted with nil or empty rates for \(sourceCurrency) to \(targetCurrency).",
                category: .exchangeRate
            )
            return nil
        }

        if sourceCurrency == targetCurrency {
            return amount
        }

        let amountInUSD: Double
        if sourceCurrency != "USD" {
            guard let sourceRateAgainstUSD = validRates[sourceCurrency] else {
                LoggingService.warning(
                    "Source currency \(sourceCurrency) rate not found in provided rates for conversion.",
                    category: .exchangeRate
                )
                return nil
            }
            guard sourceRateAgainstUSD != 0 else {
                LoggingService.error(
                    "Source currency \(sourceCurrency) rate is zero, cannot convert.",
                    category: .exchangeRate
                )
                return nil
            }
            amountInUSD = amount / sourceRateAgainstUSD
        } else {
            amountInUSD = amount
        }

        if targetCurrency == "USD" {
            return amountInUSD
        }

        guard let targetRateAgainstUSD = validRates[targetCurrency] else {
            LoggingService.warning(
                "Target currency \(targetCurrency) rate not found in provided rates for conversion.",
                category: .exchangeRate
            )
            return nil
        }

        return amountInUSD * targetRateAgainstUSD
    }

    nonisolated static func getSymbol(for currencyCode: String) -> String {
        let locale = Locale(identifier: "en_US@currency=\(currencyCode)")
        // Fallback for currency codes that don't have a symbol in the current locale configuration
        // or for which the system cannot provide one.
        return locale.currencySymbol ?? currencyCode + " "
    }
}

struct FrankfurterResponse: Codable {
    // We only care about the `rates` dictionary from the response.
    // The API also sends `amount`, `base`, `date` which can be ignored if not needed.
    let rates: [String: Double]
}
