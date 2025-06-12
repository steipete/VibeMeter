import Foundation
import os.log

/// Specialized parser for Claude Code log format
enum ClaudeCodeLogParser {
    private static let logger = Logger.vibeMeter(category: "ClaudeCodeLogParser")

    // Pre-compiled regex patterns for better performance
    private static let inputTokensRegex = try! NSRegularExpression(
        pattern: #"["']?(?:input_tokens|inputTokens)["']?\s*:\s*(\d+)"#,
        options: [])
    private static let outputTokensRegex = try! NSRegularExpression(
        pattern: #"["']?(?:output_tokens|outputTokens)["']?\s*:\s*(\d+)"#,
        options: [])
    private static let timestampRegex = try! NSRegularExpression(
        pattern: #""timestamp"\s*:\s*"([^"]+)""#,
        options: [])
    private static let modelRegex = try! NSRegularExpression(
        pattern: #""model"\s*:\s*"([^"]+)""#,
        options: [])

    // Cached date formatters
    private static let dateFormatters: [DateFormatter] = {
        let formatters = [
            DateFormatter().configure { $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ" },
            DateFormatter().configure { $0.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" },
        ]
        return formatters
    }()

    // Pattern detection flags
    private enum PatternFlags {
        static let skipPatterns: UInt8 = 0b0000_0001 // type:summary, type:user, leafUuid
        static let hasMessage: UInt8 = 0b0000_0010
        static let hasUsage: UInt8 = 0b0000_0100
        static let hasTokens: UInt8 = 0b0000_1000
        static let requiredFlags: UInt8 = hasMessage | hasUsage | hasTokens
    }

    /// Parse a log line with multiple format support
    static func parseLogLine(_ line: String, projectName: String? = nil) -> ClaudeLogEntry? {
        // Skip empty lines
        guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        // Quick skip pattern check first - only skip if no usage data
        if (line.contains("\"type\":\"summary\"") ||
            line.contains("\"type\":\"user\"") ||
            line.contains("leafUuid")) && !line.contains("\"usage\"") {
            return nil
        }

        // Check for token data - the most important indicator
        let hasTokens = line.contains("input_tokens") || line.contains("output_tokens") ||
            line.contains("inputTokens") || line.contains("outputTokens")

        // Must have token data
        guard hasTokens else {
            return nil
        }

        // Additionally check for usage structure (but don't require it for regex fallback)
        _ = line.contains("\"usage\"") ||
            (line.contains("input_tokens") && line.contains("output_tokens"))

        // Convert to Data once for all parsing attempts
        guard let data = line.data(using: .utf8) else { return nil }

        // Try parsing strategies in order of likelihood
        // Strategy 1: Standard Claude Code format - most common
        if let entry = parseClaudeCodeFormat(data, projectName: projectName) {
            return entry
        }

        // Strategy 2: Standard nested format
        if let entry = parseNestedFormat(data, projectName: projectName) {
            return entry
        }

        // Strategy 3: Top-level usage format
        if let entry = parseTopLevelFormat(data, projectName: projectName) {
            return entry
        }

        // Strategy 4: Flexible regex-based extraction (slowest)
        if let entry = parseWithRegex(line, projectName: projectName) {
            return entry
        }

        return nil
    }

    private static func parseNestedFormat(_ data: Data, projectName: String? = nil) -> ClaudeLogEntry? {
        do {
            var entry = try JSONDecoder().decode(ClaudeLogEntry.self, from: data)
            if let projectName, entry.projectName == nil {
                // Create new entry with project name
                entry = ClaudeLogEntry(
                    timestamp: entry.timestamp,
                    model: entry.model,
                    inputTokens: entry.inputTokens,
                    outputTokens: entry.outputTokens,
                    cacheCreationTokens: entry.cacheCreationTokens,
                    cacheReadTokens: entry.cacheReadTokens,
                    costUSD: entry.costUSD,
                    projectName: projectName)
            }
            return entry
        } catch {
            // Expected to fail for many formats
            return nil
        }
    }

    private static func parseTopLevelFormat(_ data: Data, projectName: String? = nil) -> ClaudeLogEntry? {
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
                outputTokens: format.usage.output_tokens,
                projectName: projectName)
        } catch {
            return nil
        }
    }

    private static func parseClaudeCodeFormat(_ data: Data, projectName: String? = nil) -> ClaudeLogEntry? {
        // Claude Code log format based on actual log structure
        struct ClaudeCodeFormat: Decodable {
            let timestamp: String
            let version: String?
            let message: Message
            let costUSD: Double?
            let type: String? // Can be "assistant"
            let parentUuid: String? // Can be present in Claude logs

            struct Message: Decodable {
                let model: String?
                let usage: Usage? // Make optional to handle variations

                // Handle both formats
                struct Usage: Decodable {
                    let input_tokens: Int?
                    let output_tokens: Int?
                    let cache_creation_input_tokens: Int?
                    let cache_read_input_tokens: Int?
                }
            }
        }

        do {
            let format = try JSONDecoder().decode(ClaudeCodeFormat.self, from: data)
            let date = parseTimestamp(format.timestamp) ?? Date()

            // Skip synthetic entries (API errors with zero tokens)
            if let model = format.message.model, model == "<synthetic>" {
                return nil
            }

            // Get tokens from message.usage
            guard let usage = format.message.usage,
                  let inputTokens = usage.input_tokens,
                  let outputTokens = usage.output_tokens else {
                return nil
            }

            let cacheCreationTokens = usage.cache_creation_input_tokens
            let cacheReadTokens = usage.cache_read_input_tokens

            return ClaudeLogEntry(
                timestamp: date,
                model: format.message.model,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens,
                costUSD: format.costUSD,
                projectName: projectName)
        } catch {
            // Log decoding error for debugging
            logger.debug("Failed to decode Claude Code format: \(error)")
        }

        return nil
    }

    private static func parseWithRegex(_ line: String, projectName: String? = nil) -> ClaudeLogEntry? {
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)

        // Extract tokens using pre-compiled regex
        guard let inputMatch = inputTokensRegex.firstMatch(in: line, options: [], range: range),
              let outputMatch = outputTokensRegex.firstMatch(in: line, options: [], range: range) else {
            return nil
        }

        // Extract token values efficiently
        let inputTokens = Int(nsString.substring(with: inputMatch.range(at: 1))) ?? 0
        let outputTokens = Int(nsString.substring(with: outputMatch.range(at: 1))) ?? 0

        guard inputTokens > 0, outputTokens > 0 else {
            return nil
        }

        // Extract timestamp
        var timestamp = Date()
        if let timestampMatch = timestampRegex.firstMatch(in: line, options: [], range: range) {
            let timestampStr = nsString.substring(with: timestampMatch.range(at: 1))
            if let parsedDate = parseTimestamp(timestampStr) {
                timestamp = parsedDate
            }
        }

        // Extract model
        var model: String?
        if let modelMatch = modelRegex.firstMatch(in: line, options: [], range: range) {
            model = nsString.substring(with: modelMatch.range(at: 1))
        }

        return ClaudeLogEntry(
            timestamp: timestamp,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            projectName: projectName)
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

// MARK: - Helper Extensions

private extension DateFormatter {
    func configure(_ closure: (DateFormatter) -> Void) -> DateFormatter {
        closure(self)
        return self
    }
}
