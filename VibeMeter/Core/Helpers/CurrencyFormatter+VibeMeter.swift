import Foundation

/// Custom currency formatting with k suffix support for large amounts
public enum VibeMeterCurrencyFormatter {
    /// Formats currency with appropriate precision using native formatting where possible
    public static func format(_ amount: Double, currencyCode: String = "USD") -> String {
        if amount < 1000 {
            // Use native currency formatting for amounts under $1,000
            let formatter = FloatingPointFormatStyle<Double>.Currency(code: currencyCode, locale: .current)

            // Apply precision based on amount
            switch amount {
            case 0 ..< 0.01:
                return formatter.precision(.fractionLength(2)).format(amount)
            case 0.01 ..< 10.0:
                return formatter.precision(.fractionLength(2)).format(amount)
            case 10.0 ..< 100.0:
                return formatter.precision(.fractionLength(0 ... 1)).format(amount)
            default: // 100.0..<1000.0
                return formatter.precision(.fractionLength(0)).format(amount)
            }
        } else {
            // Use k suffix for thousands
            let value = amount / 1000.0
            if value < 10 {
                return String(format: "$%.1fk", value)
            } else {
                return String(format: "$%.0fk", value)
            }
        }
    }
}

// MARK: - Convenience Extensions

public extension Double {
    /// Formats currency with appropriate precision using native formatting
    var formattedCurrency: String {
        VibeMeterCurrencyFormatter.format(self)
    }

    /// Formats currency with a specific currency code
    func formattedCurrency(code: String) -> String {
        VibeMeterCurrencyFormatter.format(self, currencyCode: code)
    }
}
