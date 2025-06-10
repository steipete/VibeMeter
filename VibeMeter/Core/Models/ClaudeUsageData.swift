import Foundation

/// Represents a single log entry from Claude's usage logs
public struct ClaudeLogEntry: Decodable, Identifiable, Sendable {
    public let id = UUID()
    public let timestamp: Date
    public let model: String?
    public let inputTokens: Int
    public let outputTokens: Int

    private enum CodingKeys: String, CodingKey {
        case timestamp
        case model
        case message
    }

    private enum MessageKeys: String, CodingKey {
        case usage
    }

    private enum UsageKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode timestamp with robust date formatting
        let dateString = try container.decode(String.self, forKey: .timestamp)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: dateString) {
            self.timestamp = date
        } else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                self.timestamp = date
            } else {
                throw DecodingError.dataCorruptedError(
                    forKey: .timestamp,
                    in: container,
                    debugDescription: "Date string '\(dateString)' does not match expected ISO8601 format.")
            }
        }

        self.model = try container.decodeIfPresent(String.self, forKey: .model)

        let messageContainer = try container.nestedContainer(keyedBy: MessageKeys.self, forKey: .message)
        let usageContainer = try messageContainer.nestedContainer(keyedBy: UsageKeys.self, forKey: .usage)

        self.inputTokens = try usageContainer.decode(Int.self, forKey: .inputTokens)
        self.outputTokens = try usageContainer.decode(Int.self, forKey: .outputTokens)
    }

    /// For testing and manual initialization
    public init(timestamp: Date, model: String?, inputTokens: Int, outputTokens: Int) {
        self.timestamp = timestamp
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}

/// Represents the 5-hour window usage for Claude Pro accounts
public struct FiveHourWindow: Sendable {
    public let used: Double
    public let total: Double
    public let resetDate: Date

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

    public var totalTokens: Int {
        totalInputTokens + totalOutputTokens
    }

    /// Calculate cost in USD
    public func calculateCost(inputPricePerMillion: Double = 3.0, outputPricePerMillion: Double = 15.0) -> Double {
        let inputCost = Double(totalInputTokens) / 1_000_000 * inputPricePerMillion
        let outputCost = Double(totalOutputTokens) / 1_000_000 * outputPricePerMillion
        return inputCost + outputCost
    }
}

/// Claude pricing tiers
public enum ClaudePricingTier: String, CaseIterable, Sendable {
    case free = "Free"
    case pro = "Pro"

    public var displayName: String { rawValue }

    /// Monthly token limits for each tier (if applicable)
    public var monthlyTokenLimit: Int? {
        switch self {
        case .free:
            1_000_000 // Example limit
        case .pro:
            nil // No hard monthly limit, uses 5-hour windows
        }
    }

    /// Whether this tier uses the 5-hour window system
    public var usesFiveHourWindow: Bool {
        self == .pro
    }
}
