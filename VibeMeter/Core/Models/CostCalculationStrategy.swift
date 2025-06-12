import Foundation

/// Strategy for calculating costs from Claude usage data
public enum CostCalculationStrategy: String, CaseIterable, Codable, Sendable {
    /// Use predefined costUSD when available, fallback to calculating from tokens (default)
    case auto

    /// Always calculate costs from token counts, ignoring predefined costs
    case calculate

    /// Always use predefined costUSD, show $0.00 if not available
    case display

    public var displayName: String {
        switch self {
        case .auto:
            "Auto (Predefined or Calculate)"
        case .calculate:
            "Always Calculate from Tokens"
        case .display:
            "Display Predefined Only"
        }
    }

    public var description: String {
        switch self {
        case .auto:
            "Uses predefined cost when available, otherwise calculates from token usage"
        case .calculate:
            "Always calculates cost based on token usage and current pricing"
        case .display:
            "Only shows predefined costs, displays $0.00 if not available"
        }
    }
}

/// Claude model pricing information
public struct ClaudeModelPricing: Sendable {
    public let inputPricePerMillion: Double
    public let outputPricePerMillion: Double
    public let cacheWritePricePerMillion: Double
    public let cacheReadPricePerMillion: Double

    public init(
        inputPricePerMillion: Double,
        outputPricePerMillion: Double,
        cacheWritePricePerMillion: Double = 0.0,
        cacheReadPricePerMillion: Double = 0.0) {
        self.inputPricePerMillion = inputPricePerMillion
        self.outputPricePerMillion = outputPricePerMillion
        self.cacheWritePricePerMillion = cacheWritePricePerMillion
        self.cacheReadPricePerMillion = cacheReadPricePerMillion
    }

    /// Calculate cost for given token counts
    public func calculateCost(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int = 0,
        cacheReadTokens: Int = 0) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000 * inputPricePerMillion
        let outputCost = Double(outputTokens) / 1_000_000 * outputPricePerMillion
        let cacheWriteCost = Double(cacheCreationTokens) / 1_000_000 * cacheWritePricePerMillion
        let cacheReadCost = Double(cacheReadTokens) / 1_000_000 * cacheReadPricePerMillion

        return inputCost + outputCost + cacheWriteCost + cacheReadCost
    }
}

/// Pricing for different Claude models
public enum ClaudeModelPricingTier: Sendable {
    /// Get pricing for a specific model
    public static func pricing(for model: String?) -> ClaudeModelPricing {
        guard let model = model?.lowercased() else {
            // Default to Sonnet pricing if model unknown
            return ClaudeModelPricing(
                inputPricePerMillion: 3.0,
                outputPricePerMillion: 15.0,
                cacheWritePricePerMillion: 3.75,
                cacheReadPricePerMillion: 0.30)
        }

        // Pricing as of January 2025
        if model.contains("opus-4") || model.contains("claude-3-opus") {
            return ClaudeModelPricing(
                inputPricePerMillion: 15.0,
                outputPricePerMillion: 75.0,
                cacheWritePricePerMillion: 18.75,
                cacheReadPricePerMillion: 1.50)
        } else if model.contains("sonnet") || model.contains("claude-3-5") {
            return ClaudeModelPricing(
                inputPricePerMillion: 3.0,
                outputPricePerMillion: 15.0,
                cacheWritePricePerMillion: 3.75,
                cacheReadPricePerMillion: 0.30)
        } else if model.contains("haiku") {
            return ClaudeModelPricing(
                inputPricePerMillion: 0.25,
                outputPricePerMillion: 1.25,
                cacheWritePricePerMillion: 0.30,
                cacheReadPricePerMillion: 0.03)
        } else {
            // Default to Sonnet pricing
            return ClaudeModelPricing(
                inputPricePerMillion: 3.0,
                outputPricePerMillion: 15.0,
                cacheWritePricePerMillion: 3.75,
                cacheReadPricePerMillion: 0.30)
        }
    }
}
