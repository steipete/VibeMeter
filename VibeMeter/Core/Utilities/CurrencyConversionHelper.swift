import Foundation

/// Helper for currency conversion operations
@MainActor
final class CurrencyConversionHelper {
    static func convert(amount: Double, rate: Double?) -> Double {
        guard let rate, rate > 0, rate.isFinite else { return amount }
        return amount * rate
    }

    static func formatAmount(_ amount: Double, currencySymbol: String, locale: Locale = .current) -> String {
        // Handle special cases for infinity
        if amount.isInfinite {
            if amount > 0 {
                return "\(currencySymbol)∞"
            } else {
                return "\(currencySymbol)-∞"
            }
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = locale

        let formattedNumber = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        return "\(currencySymbol)\(formattedNumber)"
    }

    static func calculateMonthlyLimit(yearlyLimit: Double, using _: Calendar = .current) -> Double {
        yearlyLimit / 12.0
    }
}
