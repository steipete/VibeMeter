// VibeMeter/Core/Models/ClaudeUsageData.swift
// Created by Codegen

import Foundation

/// Represents a single Claude log entry parsed from local JSONL files.
public struct ClaudeLogEntry: Decodable, Identifiable, Sendable {
    public var id = UUID()
    public let timestamp: Date
    public let model: String?
    public let inputTokens: Int
    public let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case timestamp, model, message
    }
    enum MessageKeys: String, CodingKey {
        case usage
    }
    enum UsageKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateString = try container.decode(String.self, forKey: .timestamp)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(forKey: .timestamp, in: container, debugDescription: "Invalid date format")
        }
        timestamp = date
        model = try container.decodeIfPresent(String.self, forKey: .model)

        let messageContainer = try container.nestedContainer(keyedBy: MessageKeys.self, forKey: .message)
        let usageContainer = try messageContainer.nestedContainer(keyedBy: UsageKeys.self, forKey: .usage)
        inputTokens = try usageContainer.decode(Int.self, forKey: .inputTokens)
        outputTokens = try usageContainer.decode(Int.self, forKey: .outputTokens)
    }
}

/// Aggregated 5-hour window information for Claude Pro accounts.
public struct FiveHourWindow: Sendable {
    public let used: Double // seconds
    public let total: Double // seconds
    public let resetDate: Date

    public var remaining: Double { total - used }
    public var percentageUsed: Double { total == 0 ? 0 : used / total }
}

