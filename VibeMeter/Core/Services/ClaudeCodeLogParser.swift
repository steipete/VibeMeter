import Foundation
import os.log

/// Specialized parser for Claude Code log format
enum ClaudeCodeLogParser {
    private static let logger = Logger.vibeMeter(category: "ClaudeCodeLogParser")

    /// Parse a log line with multiple format support
    static func parseLogLine(_ line: String) -> ClaudeLogEntry? {
        // Skip empty lines
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        // Skip non-relevant lines early
        if line.contains("\"type\":\"summary\"") ||
            line.contains("\"type\":\"user\"") ||
            line.contains("leafUuid") {
            return nil
        }

        // Must have message.usage structure with token data
        guard line.contains("\"message\""),
              line.contains("\"usage\""),
              line.contains("input_tokens") || line.contains("output_tokens") else {
            return nil
        }

        // Try multiple parsing strategies

        // Strategy 1: Standard Claude Code format - message.usage
        if let entry = parseClaudeCodeFormat(line) {
            return entry
        }

        // Strategy 2: Standard nested format - message.usage
        if let entry = parseNestedFormat(line) {
            return entry
        }

        // Strategy 3: Top-level usage format
        if let entry = parseTopLevelFormat(line) {
            return entry
        }

        // Strategy 4: Flexible regex-based extraction
        if let entry = parseWithRegex(line) {
            return entry
        }

        return nil
    }

    private static func parseNestedFormat(_ line: String) -> ClaudeLogEntry? {
        guard let data = line.data(using: .utf8) else { return nil }

        do {
            return try JSONDecoder().decode(ClaudeLogEntry.self, from: data)
        } catch {
            // Expected to fail for many formats
            return nil
        }
    }

    private static func parseTopLevelFormat(_ line: String) -> ClaudeLogEntry? {
        guard let data = line.data(using: .utf8) else { return nil }

        struct TopLevelFormat: Decodable {
            let timestamp: String
            let model: String?
            let usage: Usage

            struct Usage: Decodable {
                let input_tokens: Int
                let output_tokens: Int
            }
        }

        do {
            let format = try JSONDecoder().decode(TopLevelFormat.self, from: data)
            let date = parseTimestamp(format.timestamp) ?? Date()

            return ClaudeLogEntry(
                timestamp: date,
                model: format.model,
                inputTokens: format.usage.input_tokens,
                outputTokens: format.usage.output_tokens)
        } catch {
            return nil
        }
    }

    private static func parseClaudeCodeFormat(_ line: String) -> ClaudeLogEntry? {
        guard let data = line.data(using: .utf8) else { return nil }

        // Claude Code log format based on actual log structure
        struct ClaudeCodeFormat: Decodable {
            let timestamp: String
            let version: String?
            let message: Message
            let costUSD: Double?

            struct Message: Decodable {
                let model: String?
                let usage: Usage

                struct Usage: Decodable {
                    let input_tokens: Int
                    let output_tokens: Int
                    let cache_creation_input_tokens: Int?
                    let cache_read_input_tokens: Int?
                }
            }
        }

        do {
            let format = try JSONDecoder().decode(ClaudeCodeFormat.self, from: data)
            let date = parseTimestamp(format.timestamp) ?? Date()

            // Get tokens from message.usage
            let inputTokens = format.message.usage.input_tokens
            let outputTokens = format.message.usage.output_tokens
            let cacheCreationTokens = format.message.usage.cache_creation_input_tokens
            let cacheReadTokens = format.message.usage.cache_read_input_tokens

            return ClaudeLogEntry(
                timestamp: date,
                model: format.message.model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens,
                costUSD: format.costUSD)
        } catch {
            // Log decoding error for debugging
            logger.debug("Failed to decode Claude Code format: \(error)")
        }

        return nil
    }

    private static func parseWithRegex(_ line: String) -> ClaudeLogEntry? {
        // Extract tokens using regex patterns
        let inputPattern = #"["\s](?:input_tokens|inputTokens)["\s]*:\s*(\d+)"#
        let outputPattern = #"["\s](?:output_tokens|outputTokens)["\s]*:\s*(\d+)"#
        let timestampPattern = #""timestamp"\s*:\s*"([^"]+)""#
        let modelPattern = #""model"\s*:\s*"([^"]+)""#

        guard let inputMatch = line.range(of: inputPattern, options: .regularExpression),
              let outputMatch = line.range(of: outputPattern, options: .regularExpression) else {
            return nil
        }

        // Extract values
        let inputTokensStr = String(line[inputMatch]).components(separatedBy: ":").last?
            .trimmingCharacters(in: .whitespaces)
        let outputTokensStr = String(line[outputMatch]).components(separatedBy: ":").last?
            .trimmingCharacters(in: .whitespaces)

        guard let inputTokens = inputTokensStr.flatMap(Int.init),
              let outputTokens = outputTokensStr.flatMap(Int.init) else {
            return nil
        }

        // Extract timestamp
        var timestamp = Date()
        if let timestampMatch = line.range(of: timestampPattern, options: .regularExpression) {
            let timestampStr = String(line[timestampMatch])
                .replacingOccurrences(of: "\"timestamp\"", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)

            if let parsedDate = parseTimestamp(timestampStr) {
                timestamp = parsedDate
            }
        }

        // Extract model
        var model: String?
        if let modelMatch = line.range(of: modelPattern, options: .regularExpression) {
            model = String(line[modelMatch])
                .replacingOccurrences(of: "\"model\"", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
        }

        return ClaudeLogEntry(
            timestamp: timestamp,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens)
    }

    private static func parseTimestamp(_ timestamp: String) -> Date? {
        // Try ISO8601 formatters first
        if let date = ISO8601DateFormatter.vibeMeterDefault.date(from: timestamp) {
            return date
        }
        if let date = ISO8601DateFormatter.vibeMeterStandard.date(from: timestamp) {
            return date
        }

        // Try custom date formatters
        let dateFormatters = [
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return formatter
            }(),
            { () -> DateFormatter in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return formatter
            }(),
        ]

        for formatter in dateFormatters {
            if let date = formatter.date(from: timestamp) {
                return date
            }
        }

        return nil
    }
}
