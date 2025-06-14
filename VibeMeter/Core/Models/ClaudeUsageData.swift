import Foundation

/// Represents a single log entry from Claude's usage logs
public struct ClaudeLogEntry: Codable, Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let model: String?
    public let inputTokens: Int
    public let outputTokens: Int
    public let cacheCreationTokens: Int?
    public let cacheReadTokens: Int?
    public let costUSD: Double?
    public let projectName: String?

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case model
        case message
        case costUSD
        case projectName
    }

    private enum MessageKeys: String, CodingKey {
        case usage
    }

    private enum UsageKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationTokens = "cache_creation_input_tokens"
        case cacheReadTokens = "cache_read_input_tokens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode timestamp with robust date formatting
        let dateString = try container.decode(String.self, forKey: .timestamp)

        if let date = ISO8601DateFormatter.vibeMeterDefault.date(from: dateString) {
            self.timestamp = date
        } else {
            // Try without fractional seconds
            if let date = ISO8601DateFormatter.vibeMeterStandard.date(from: dateString) {
                self.timestamp = date
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .timestamp,
                    in: container,
                    debugDescription: "Date string '\(dateString)' does not match expected ISO8601 format.")
            }
        }

        self.model = try container.decodeIfPresent(String.self, forKey: .model)
        self.costUSD = try container.decodeIfPresent(Double.self, forKey: .costUSD)
        self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName)

        let messageContainer = try container.nestedContainer(keyedBy: MessageKeys.self, forKey: .message)
        let usageContainer = try messageContainer.nestedContainer(keyedBy: UsageKeys.self, forKey: .usage)

        self.inputTokens = try usageContainer.decode(Int.self, forKey: .inputTokens)
        self.outputTokens = try usageContainer.decode(Int.self, forKey: .outputTokens)
        self.cacheCreationTokens = try usageContainer.decodeIfPresent(Int.self, forKey: .cacheCreationTokens)
        self.cacheReadTokens = try usageContainer.decodeIfPresent(Int.self, forKey: .cacheReadTokens)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode timestamp as ISO8601 string
        let dateString = ISO8601DateFormatter.vibeMeterDefault.string(from: timestamp)
        try container.encode(dateString, forKey: .timestamp)

        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(costUSD, forKey: .costUSD)
        try container.encodeIfPresent(projectName, forKey: .projectName)

        var messageContainer = container.nestedContainer(keyedBy: MessageKeys.self, forKey: .message)
        var usageContainer = messageContainer.nestedContainer(keyedBy: UsageKeys.self, forKey: .usage)

        try usageContainer.encode(inputTokens, forKey: .inputTokens)
        try usageContainer.encode(outputTokens, forKey: .outputTokens)
        try usageContainer.encodeIfPresent(cacheCreationTokens, forKey: .cacheCreationTokens)
        try usageContainer.encodeIfPresent(cacheReadTokens, forKey: .cacheReadTokens)
    }

    /// For testing and manual initialization
    public init(
        timestamp: Date,
        model: String?,
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int? = nil,
        cacheReadTokens: Int? = nil,
        costUSD: Double? = nil,
        projectName: String? = nil) {
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheCreationTokens = cacheCreationTokens
        self.cacheReadTokens = cacheReadTokens
        self.costUSD = costUSD
        self.projectName = projectName
    }

    /// Calculate cost based on the selected strategy
    public func calculateCost(strategy: CostCalculationStrategy = .auto) -> Double {
        switch strategy {
        case .auto:
            // Use predefined cost if available, otherwise calculate
            if let predefinedCost = costUSD {
                predefinedCost
            } else {
                calculateCostFromTokens()
            }

        case .calculate:
            // Always calculate from tokens
            calculateCostFromTokens()

        case .display:
            // Only use predefined cost, return 0 if not available
            costUSD ?? 0.0
        }
    }

    /// Calculate cost from token usage
    private func calculateCostFromTokens() -> Double {
        let pricing = ClaudeModelPricingTier.pricing(for: model)
        return pricing.calculateCost(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens ?? 0,
            cacheReadTokens: cacheReadTokens ?? 0)
    }
}

/// Represents the 5-hour window usage for Claude Pro accounts
public struct FiveHourWindow: Sendable, Equatable {
    public let used: Double
    public let total: Double
    public let resetDate: Date
    public let tokensUsed: Int
    public let estimatedTokenLimit: Int

    public var remaining: Double {
        max(0, total - used)
    }

    public var percentageUsed: Double {
        total > 0 ? min(100, (used / total) * 100) : 0
    }

    public var percentageRemaining: Double {
        100 - percentageUsed
    }

    public var isExhausted: Bool {
        remaining <= 0
    }

    public var tokensRemaining: Int {
        max(0, estimatedTokenLimit - tokensUsed)
    }
}

/// Aggregated daily usage data
public struct ClaudeDailyUsage: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let entries: [ClaudeLogEntry]

    public var totalInputTokens: Int {
        entries.reduce(0) { $0 + $1.inputTokens }
    }

    public var totalOutputTokens: Int {
        entries.reduce(0) { $0 + $1.outputTokens }
    }

    public var totalCacheCreationTokens: Int {
        entries.reduce(0) { $0 + ($1.cacheCreationTokens ?? 0) }
    }

    public var totalCacheReadTokens: Int {
        entries.reduce(0) { $0 + ($1.cacheReadTokens ?? 0) }
    }

    public var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }

    /// Calculate cost in USD using the specified strategy
    public func calculateCost(strategy: CostCalculationStrategy = .auto) -> Double {
        switch strategy {
        case .auto, .calculate:
            // For daily aggregates, sum individual entry costs
            entries.reduce(0.0) { $0 + $1.calculateCost(strategy: strategy) }

        case .display:
            // Only sum entries that have predefined costs
            entries.reduce(0.0) { $0 + ($1.costUSD ?? 0.0) }
        }
    }

    /// Calculate cost with custom pricing (legacy method for backwards compatibility)
    public func calculateCostWithPricing(inputPricePerMillion: Double = 3.0,
                                         outputPricePerMillion: Double = 15.0) -> Double {
        let inputCost = Double(totalInputTokens) / 1_000_000 * inputPricePerMillion
        let outputCost = Double(totalOutputTokens) / 1_000_000 * outputPricePerMillion
        return inputCost + outputCost
    }
}

/// Claude pricing tiers
public enum ClaudePricingTier: String, CaseIterable, Sendable, Codable {
    case free = "Free"
    case pro = "Pro"
    case max100 = "Max100"
    case max200 = "Max200"

    public var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro ($20/mo)"
        case .max100: "Max 5× ($100/mo)"
        case .max200: "Max 20× ($200/mo)"
        }
    }

    /// Monthly price in USD
    public var monthlyPrice: Double? {
        switch self {
        case .free: nil
        case .pro: 20.0
        case .max100: 100.0
        case .max200: 200.0
        }
    }

    /// Messages per day for free tier
    public var dailyMessageLimit: Int? {
        switch self {
        case .free: 50 // 50 messages per day
        case .pro, .max100, .max200: nil // No daily limit, uses 5-hour windows
        }
    }

    /// Whether this tier uses the 5-hour window system
    public var usesFiveHourWindow: Bool {
        switch self {
        case .free: false
        case .pro, .max100, .max200: true
        }
    }

    /// Approximate messages per 5-hour window
    public var messagesPerFiveHours: Int? {
        switch self {
        case .free: nil
        case .pro: 45 // ~45 messages per 5 hours
        case .max100: 225 // 5× Pro usage
        case .max200: 900 // 20× Pro usage
        }
    }

    /// Context window in tokens
    public var contextWindowTokens: Int {
        200_000 // All tiers have 200K token context window
    }

    /// Description for UI
    public var description: String {
        switch self {
        case .free:
            "50 messages/day • Resets at midnight PT"
        case .pro:
            "~45 messages per 5-hour window • Priority access"
        case .max100:
            "~225 messages per 5-hour window • 5× Pro usage • Priority features"
        case .max200:
            "~900 messages per 5-hour window • 20× Pro usage • All features"
        }
    }
}
