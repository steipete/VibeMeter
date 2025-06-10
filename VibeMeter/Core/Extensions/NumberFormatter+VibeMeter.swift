import Foundation

extension NumberFormatter {
    /// Standard currency formatter for VibeMeter
    /// - No grouping separator (no commas)
    /// - 0-2 decimal places
    /// - Decimal style
    static let vibeMeterCurrency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }()

    /// Currency formatter with currency symbol
    /// - Includes currency symbol
    /// - 0-2 decimal places
    static func vibeMeterCurrency(with currencyCode: String) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter
    }

    /// Percentage formatter for VibeMeter
    /// - 0-1 decimal places
    /// - Includes % symbol
    static let vibeMeterPercentage: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    /// Compact formatter for large numbers
    /// - Uses K, M, B suffixes
    static let vibeMeterCompact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 1
        return formatter
    }()
}
