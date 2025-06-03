import Foundation

/// Manages currency selection and formatting for the application.
final class CurrencyManager: Sendable {
    static let shared = CurrencyManager()

    private init() {}

    /// Available currencies from macOS system with commonly used currencies prioritized
    var availableCurrencies: [(String, String)] {
        let availableCurrencies = Locale.availableIdentifiers
            .compactMap { identifier -> (String, String)? in
                let locale = Locale(identifier: identifier)
                guard let currencyCode = locale.currency?.identifier,
                      let currencySymbol = locale.currencySymbol,
                      let currencyName = locale.localizedString(forCurrencyCode: currencyCode) else {
                    return nil
                }
                let capitalizedCurrencyName = currencyName.prefix(1).uppercased() + currencyName.dropFirst()
                return (currencyCode, "\(capitalizedCurrencyName) (\(currencySymbol))")
            }

        // Remove duplicates and sort with commonly used currencies first
        let uniqueCurrencies = Dictionary(availableCurrencies) { _, second in second }
        let commonCurrencies = [
            "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "SEK", "NOK", "DKK", "PLN",
            "CZK", "HUF", "RON", "BGN", "HRK", "RUB", "UAH", "TRY", "INR", "KRW", "SGD", "HKD",
            "TWD", "THB", "MYR", "IDR", "PHP", "VND", "BRL", "MXN", "ARS", "CLP", "COP", "PEN",
            "UYU", "ZAR", "EGP", "MAD", "TND", "KES", "NGN", "GHS", "XOF", "XAF", "ILS", "SAR",
            "AED", "QAR", "KWD", "BHD", "OMR", "JOD", "LBP", "PKR", "BDT", "LKR", "NPR", "AFN",
            "IRR", "IQD", "SYP", "YER", "AZN", "AMD", "GEL", "KZT", "KGS", "TJS", "TMT", "UZS",
            "MNT", "LAK", "KHR", "MMK", "NZD",
        ]

        return uniqueCurrencies.sorted { first, second in
            let firstIndex = commonCurrencies.firstIndex(of: first.key) ?? Int.max
            let secondIndex = commonCurrencies.firstIndex(of: second.key) ?? Int.max

            if firstIndex != secondIndex {
                return firstIndex < secondIndex
            }
            return first.key < second.key
        }
    }

    /// Gets the system default currency code
    var systemCurrencyCode: String? {
        Locale.current.currency?.identifier
    }

    /// Checks if a currency code is available in the system
    func isValidCurrencyCode(_ code: String) -> Bool {
        availableCurrencies.contains { $0.0 == code }
    }
}
