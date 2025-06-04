import Foundation

/// Manages currency selection and formatting for the application.
final class CurrencyManager: Sendable {
    static let shared = CurrencyManager()
    
    // Cache for available currencies to improve performance
    private let _availableCurrencies: [(String, String)]

    private init() {
        self._availableCurrencies = Self.generateAvailableCurrencies()
    }

    /// Available currencies from macOS system with commonly used currencies prioritized
    var availableCurrencies: [(String, String)] {
        return _availableCurrencies
    }
    
    /// Generates the available currencies list (called once during initialization)
    private static func generateAvailableCurrencies() -> [(String, String)] {
        // Get all unique currency codes from available locales
        let allCurrencyCodes = Set(Locale.availableIdentifiers.compactMap { identifier in
            Locale(identifier: identifier).currency?.identifier
        })
        
        // Use en_US locale for consistent symbols and names
        let enUSLocale = Locale(identifier: "en_US")
        
        let availableCurrencies = allCurrencyCodes.compactMap { currencyCode -> (String, String)? in
            // Create a locale that uses this currency code with en_US as base
            let localeIdentifier = "en_US@currency=\(currencyCode)"
            let currencyLocale = Locale(identifier: localeIdentifier)
            
            guard let currencySymbol = currencyLocale.currencySymbol else {
                return nil
            }

            // Use custom names for common currencies to ensure consistent English names
            let currencyName = customCurrencyName(for: currencyCode) ??
                enUSLocale.localizedString(forCurrencyCode: currencyCode) ?? currencyCode

            let capitalizedCurrencyName = currencyName.prefix(1).uppercased() + currencyName.dropFirst()
            return (currencyCode, "\(capitalizedCurrencyName) (\(currencySymbol))")
        }

        // Convert to dictionary to ensure uniqueness, then back to array
        let uniqueCurrencies = Dictionary(availableCurrencies.map { ($0.0, $0.1) }) { _, second in second }
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

    /// Provides custom English names for common currencies to ensure consistency
    private static func customCurrencyName(for currencyCode: String) -> String? {
        let customNames: [String: String] = [
            "USD": "US Dollar",
            "EUR": "Euro",
            "GBP": "British Pound",
            "JPY": "Japanese Yen",
            "AUD": "Australian Dollar",
            "CAD": "Canadian Dollar",
            "CHF": "Swiss Franc",
            "CNY": "Chinese Yuan",
            "SEK": "Swedish Krona",
            "NOK": "Norwegian Krone",
            "DKK": "Danish Krone",
            "PLN": "Polish Zloty",
            "CZK": "Czech Koruna",
            "HUF": "Hungarian Forint",
            "INR": "Indian Rupee",
            "KRW": "South Korean Won",
            "SGD": "Singapore Dollar",
            "HKD": "Hong Kong Dollar",
            "BRL": "Brazilian Real",
            "MXN": "Mexican Peso",
            "RUB": "Russian Ruble",
            "TRY": "Turkish Lira",
            "ZAR": "South African Rand",
            "ILS": "Israeli Shekel",
            "SAR": "Saudi Riyal",
            "AED": "UAE Dirham",
            "NZD": "New Zealand Dollar",
        ]

        return customNames[currencyCode]
    }
}
