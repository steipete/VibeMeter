import Foundation

/// Helper for currency conversion operations
@MainActor
final class CurrencyConversionHelper {
    static func convert(amount: Double, rate: Double?) -> Double {
        guard let rate = rate, rate > 0 else { return amount }
        return amount * rate
    }
    
    static func formatAmount(_ amount: Double, currencySymbol: String, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.locale = locale
        
        let formattedNumber = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        return "\(currencySymbol)\(formattedNumber)"
    }
    
    static func calculateMonthlyLimit(yearlyLimit: Double, using calendar: Calendar = .current) -> Double {
        return yearlyLimit / 12.0
    }
}