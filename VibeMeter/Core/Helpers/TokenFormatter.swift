import Foundation

/// Formats token counts with k/M suffixes for better readability
public enum TokenFormatter {
    /// Formats tokens with k/M suffixes for readability
    public static func format(_ tokens: Int) -> String {
        switch tokens {
        case 0 ..< 1000:
            return tokens.formatted()
        case 1000 ..< 10000:
            // Show one decimal for values under 10k (e.g., 1.5k)
            let value = Double(tokens) / 1000.0
            return String(format: "%.1fk", value)
        case 10000 ..< 1_000_000:
            // No decimals for values 10k and above
            return "\(tokens / 1000)k"
        case 1_000_000 ..< 10_000_000:
            // Show one decimal for values under 10M
            let value = Double(tokens) / 1_000_000.0
            return String(format: "%.1fM", value)
        default:
            // No decimals for values 10M and above
            return "\(tokens / 1_000_000)M"
        }
    }
    
    /// Formats token rate (per hour) with k/M suffixes
    public static func formatRate(_ tokensPerHour: Double) -> String {
        let tokens = Int(tokensPerHour)
        
        if tokensPerHour < 1 {
            return "0/hr"
        } else if tokensPerHour < 1000 {
            return "\(Int(tokensPerHour))/hr"
        } else {
            return "\(format(tokens))/hr"
        }
    }
    
    /// Formats a range of tokens with k/M suffixes
    public static func formatRange(from: Int, to: Int) -> String {
        return "\(format(from))-\(format(to))"
    }
}

// MARK: - Convenience Extensions

public extension Int {
    /// Formats tokens with k/M suffixes for readability
    var formattedTokens: String {
        TokenFormatter.format(self)
    }
}
