import Foundation
import Testing
@testable import VibeMeter

@Suite("Claude Log Parsing Tests", .tags(.claudeLogManager))
struct ClaudeLogParsingTests {
    // MARK: - Test Data

    private func createValidLogLine(
        timestamp: String = "2025-01-06T10:30:00.000Z",
        model: String = "claude-3-5-sonnet",
        inputTokens: Int = 100,
        outputTokens: Int = 50) -> String {
        """
        {"timestamp":"\(timestamp)","model":"\(model)","message":{"usage":{"input_tokens":\(
            inputTokens),"output_tokens":\(outputTokens)}}}
        """
    }

    private func createLogLineWithExtraFields() -> String {
        """
        {"timestamp":"2025-01-06T10:30:00.000Z","type":"assistant","model":"claude-3-5-sonnet","message":{"role":"assistant","content":"Hello","usage":{"input_tokens":150,"output_tokens":75}},"metadata":{"request_id":"123"}}
        """
    }

    private func createSummaryLogLine() -> String {
        """
        {"timestamp":"2025-01-06T10:30:00.000Z","type":"summary","sessionId":"abc123","leafUuid":"def456"}
        """
    }

    private func createUserLogLine() -> String {
        """
        {"timestamp":"2025-01-06T10:30:00.000Z","type":"user","message":{"content":"Hello Claude"}}
        """
    }

    private func createMalformedLogLine() -> String {
        """
        {"timestamp":"2025-01-06T10:30:00.000Z","message":{"content":"No usage data"}}
        """
    }

    private func createIncompleteUsageLogLine() -> String {
        """
        {"timestamp":"2025-01-06T10:30:00.000Z","message":{"usage":{"input_tokens":100}}}
        """
    }

    // MARK: - JSON Decoding Tests

    @Test("Parse valid log line with basic structure")
    func parseValidBasicLogLine() {
        let logLine = createValidLogLine()

        if let data = logLine.data(using: .utf8),
           let entry = try? JSONDecoder().decode(ClaudeLogEntry.self, from: data) {
            #expect(entry.inputTokens == 100)
            #expect(entry.outputTokens == 50)
            #expect(entry.model == "claude-3-5-sonnet")
        } else {
            Issue.record("Failed to parse valid log line")
        }
    }

    @Test("Parse log line with extra fields")
    func parseLogLineWithExtraFields() {
        let logLine = createLogLineWithExtraFields()

        if let data = logLine.data(using: .utf8),
           let entry = try? JSONDecoder().decode(ClaudeLogEntry.self, from: data) {
            #expect(entry.inputTokens == 150)
            #expect(entry.outputTokens == 75)
            #expect(entry.model == "claude-3-5-sonnet")
        } else {
            Issue.record("Failed to parse log line with extra fields")
        }
    }

    @Test("Fail to parse malformed log lines")
    func failToParseMalformedLogLines() {
        let logLine = createMalformedLogLine()

        if let data = logLine.data(using: .utf8) {
            do {
                _ = try JSONDecoder().decode(ClaudeLogEntry.self, from: data)
                Issue.record("Should have failed to parse malformed log line")
            } catch {
                // Expected to fail
                #expect(error is DecodingError)
            }
        }
    }

    @Test("Parse various timestamp formats")
    func parseVariousTimestampFormats() {
        let timestamps = [
            "2025-01-06T10:30:00.123Z", // With milliseconds
            "2025-01-06T10:30:00Z", // Without milliseconds
            "2025-01-06T10:30:00.123456Z", // With microseconds
        ]

        for timestamp in timestamps {
            let logLine = createValidLogLine(timestamp: timestamp)

            if let data = logLine.data(using: .utf8),
               let entry = try? JSONDecoder().decode(ClaudeLogEntry.self, from: data) {
                #expect(entry.timestamp != nil)
            } else {
                Issue.record("Failed to parse timestamp: \(timestamp)")
            }
        }
    }

    @Test("Parse real-world Claude log format")
    func parseRealWorldFormat() {
        // This is a more realistic log line structure based on typical Claude API responses
        let logLine = """
        {"timestamp":"2025-01-06T10:30:00.123Z","level":"info","type":"api_response","model":"claude-3-5-sonnet-20241022","message":{"id":"msg_01XYZ","type":"message","role":"assistant","content":[{"type":"text","text":"Hello! How can I help you today?"}],"model":"claude-3-5-sonnet-20241022","stop_reason":"end_turn","stop_sequence":null,"usage":{"input_tokens":25,"output_tokens":12}}}
        """

        if let data = logLine.data(using: .utf8),
           let entry = try? JSONDecoder().decode(ClaudeLogEntry.self, from: data) {
            #expect(entry.inputTokens == 25)
            #expect(entry.outputTokens == 12)
            #expect(entry.model == "claude-3-5-sonnet-20241022")
        } else {
            Issue.record("Failed to parse real-world log format")
        }
    }

    // MARK: - FastScanner Tests

    @Test("FastScanner correctly finds nested JSON fields")
    func fastScannerParsing() {
        let logLine = createValidLogLine(inputTokens: 123, outputTokens: 456)
        let scanner = FastScanner(string: logLine)

        // Test finding "message" field
        let beforeMessage = scanner.scanUpTo(string: "\"message\"")
        #expect(beforeMessage != nil)
        scanner.location += 9 // Skip past "message"

        // Test finding "usage" within message
        let beforeUsage = scanner.scanUpTo(string: "\"usage\"")
        #expect(beforeUsage != nil)
        scanner.location += 7 // Skip past "usage"

        // Test finding "input_tokens"
        let beforeInputTokens = scanner.scanUpTo(string: "\"input_tokens\"")
        #expect(beforeInputTokens != nil)
        scanner.location += 14 // Skip past "input_tokens"
        _ = scanner.scanUpTo(string: ":")
        scanner.location += 1 // Skip colon
        let inputTokens = scanner.scanInteger()
        #expect(inputTokens == 123)

        // Test finding "output_tokens"
        let beforeOutputTokens = scanner.scanUpTo(string: "\"output_tokens\"")
        #expect(beforeOutputTokens != nil)
        scanner.location += 15 // Skip past "output_tokens"
        _ = scanner.scanUpTo(string: ":")
        scanner.location += 1 // Skip colon
        let outputTokens = scanner.scanInteger()
        #expect(outputTokens == 456)
    }

    @Test("FastScanner handles missing fields gracefully")
    func fastScannerMissingFields() {
        let logLine = createMalformedLogLine()
        let scanner = FastScanner(string: logLine)

        // Should find message
        let beforeMessage = scanner.scanUpTo(string: "\"message\"")
        #expect(beforeMessage != nil)
        scanner.location += 9

        // Should NOT find usage
        let beforeUsage = scanner.scanUpTo(string: "\"usage\"")
        #expect(beforeUsage == nil || !beforeUsage!.contains("usage"))
    }

    // MARK: - Alternative Log Format Tests

    @Test("Test alternative Claude log format without nested message")
    func alternativeLogFormat() {
        // Some Claude logs might have usage at the top level
        let alternativeFormat = """
        {"timestamp":"2025-01-06T10:30:00.000Z","model":"claude-3-5-sonnet","usage":{"input_tokens":200,"output_tokens":100}}
        """

        // This format would fail with current parser
        if let data = alternativeFormat.data(using: .utf8) {
            do {
                _ = try JSONDecoder().decode(ClaudeLogEntry.self, from: data)
                Issue.record("Current parser shouldn't handle this format")
            } catch {
                // Expected to fail with current implementation
                #expect(error is DecodingError)
            }
        }
    }

    @Test("Test Claude Code log format")
    func claudeCodeLogFormat() {
        // Claude Code might have a different log format
        let claudeCodeFormat = """
        {"timestamp":"2025-01-06T10:30:00.000Z","event":"api_call","model":"claude-3-5-sonnet","message":{"role":"assistant","usage":{"input_tokens":500,"output_tokens":250,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """

        if let data = claudeCodeFormat.data(using: .utf8),
           let entry = try? JSONDecoder().decode(ClaudeLogEntry.self, from: data) {
            #expect(entry.inputTokens == 500)
            #expect(entry.outputTokens == 250)
            #expect(entry.model == "claude-3-5-sonnet")
        } else {
            Issue.record("Failed to parse Claude Code log format")
        }
    }
    
    // MARK: - New tests for enhanced parsing
    
    @Test("Parse Claude Code top-level usage format")
    func parseClaudeCodeTopLevelFormat() {
        let logLine = """
        {"timestamp":"2024-01-10T15:30:00Z","model":"claude-3-5-sonnet","usage":{"input_tokens":1500,"output_tokens":800}}
        """
        
        let entry = ClaudeCodeLogParser.parseLogLine(logLine)
        #expect(entry != nil)
        #expect(entry?.inputTokens == 1500)
        #expect(entry?.outputTokens == 800)
        #expect(entry?.model == "claude-3-5-sonnet")
    }
    
    @Test("Parse Claude Code format with message.usage")
    func parseClaudeCodeMessageUsageFormat() {
        let logLine = """
        {"timestamp":"2024-01-10T16:00:00Z","model":"claude-3-5-sonnet","message":{"usage":{"inputTokens":2000,"outputTokens":1200}}}
        """
        
        let entry = ClaudeCodeLogParser.parseLogLine(logLine)
        #expect(entry != nil)
        #expect(entry?.inputTokens == 2000)
        #expect(entry?.outputTokens == 1200)
    }
    
    @Test("Parse Claude Code format with mixed case tokens")
    func parseClaudeCodeMixedCaseTokens() {
        let logLine = """
        {"timestamp":"2024-01-10T16:30:00Z","event":"message","usage":{"inputTokens":3000,"outputTokens":1500}}
        """
        
        let entry = ClaudeCodeLogParser.parseLogLine(logLine)
        #expect(entry != nil)
        #expect(entry?.inputTokens == 3000)
        #expect(entry?.outputTokens == 1500)
    }
    
    @Test("Parse Claude Code format with regex fallback")
    func parseClaudeCodeRegexFallback() {
        // Malformed JSON that still contains token data
        let logLine = """
        {timestamp:"2024-01-10T17:00:00Z" "model":"claude-3-5-sonnet" "inputTokens": 4000, "outputTokens": 2000, extra_field}
        """
        
        let entry = ClaudeCodeLogParser.parseLogLine(logLine)
        #expect(entry != nil)
        #expect(entry?.inputTokens == 4000)
        #expect(entry?.outputTokens == 2000)
    }
    
    @Test("Skip non-relevant log lines")
    func skipNonRelevantLines() {
        let nonRelevantLines = [
            "{\"type\":\"summary\",\"data\":\"some data\"}",
            "{\"type\":\"user\",\"message\":\"hello\"}",
            "{\"leafUuid\":\"123\",\"sessionId\":\"456\"}",
            "{\"parentUuid\":\"789\",\"data\":\"test\"}",
            "{\"timestamp\":\"2024-01-10T18:00:00Z\",\"message\":\"no tokens here\"}"
        ]
        
        for line in nonRelevantLines {
            let entry = ClaudeCodeLogParser.parseLogLine(line)
            #expect(entry == nil)
        }
    }
    
    @Test("Parse actual Claude Opus 4 log format from VibeMeter session")
    func parseActualClaudeOpus4LogFormat() {
        // This is the actual format from Claude logs in ~/.claude/projects
        let logLine = """
        {"parentUuid":"b466f005-5b11-4532-b72c-93006f87716f","isSidechain":false,"userType":"external","cwd":"/Users/steipete/Projects/VibeMeter","sessionId":"07c29a6a-07b2-4a35-aeb1-1f06d681a021","version":"1.0.17","message":{"id":"msg_01FiQEZV78tZd1oJNBMocio1","type":"message","role":"assistant","model":"claude-opus-4-20250514","content":[{"type":"text","text":"All changes have been committed successfully."}],"stop_reason":null,"stop_sequence":null,"usage":{"input_tokens":1,"cache_creation_input_tokens":386,"cache_read_input_tokens":104929,"output_tokens":1,"service_tier":"standard"}},"requestId":"req_011CQ1B6WwgtsdNVGvKo1476","type":"assistant","uuid":"7f5176ce-7905-426c-9179-91b50b23e38a","timestamp":"2025-06-10T20:30:58.469Z"}
        """
        
        let entry = ClaudeCodeLogParser.parseLogLine(logLine)
        
        #expect(entry != nil)
        #expect(entry?.model == "claude-opus-4-20250514")
        #expect(entry?.inputTokens == 1)
        #expect(entry?.outputTokens == 1)
    }
    
    @Test("Parse Claude Code log entry with cache tokens")
    func parseClaudeCodeEntryWithCacheTokens() {
        // Test with cache tokens which VibeMeter currently doesn't track
        let logLine = """
        {"message":{"usage":{"input_tokens":2,"cache_creation_input_tokens":645,"cache_read_input_tokens":78393,"output_tokens":125,"service_tier":"standard"},"model":"claude-opus-4-20250514"},"timestamp":"2025-06-10T20:30:38.321Z","type":"assistant"}
        """
        
        let entry = ClaudeCodeLogParser.parseLogLine(logLine)
        
        #expect(entry != nil)
        #expect(entry?.model == "claude-opus-4-20250514")
        #expect(entry?.inputTokens == 2)
        #expect(entry?.outputTokens == 125)
        // Note: cache tokens are ignored in current implementation
    }
}
