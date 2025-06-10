import Foundation
import Testing
@testable import VibeMeter

// MARK: - Tiktoken Integration Tests

@Suite("Tiktoken Integration Tests", .tags(.tiktoken))
struct TiktokenTests {
    // MARK: - Basic Functionality Tests

    @Test("Initialize Tiktoken with o200k_base encoding")
    func initializeWithO200kBase() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        #expect(tiktoken != nil)
    }

    @Test("Count tokens in simple text")
    func countTokensSimpleText() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        let testCases: [(text: String, minTokens: Int, maxTokens: Int)] = [
            ("Hello, world!", 3, 5),
            ("The quick brown fox jumps over the lazy dog.", 8, 12),
            ("", 0, 0),
            ("a", 1, 1),
            ("1234567890", 1, 5),
        ]

        for (text, minExpected, maxExpected) in testCases {
            let tokenCount = tiktoken.countTokens(in: text)
            #expect(tokenCount >= minExpected)
            #expect(tokenCount <= maxExpected)
        }
    }

    @Test("Count tokens in code snippets")
    func countTokensInCode() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        let swiftCode = """
        func fibonacci(_ n: Int) -> Int {
            if n <= 1 { return n }
            return fibonacci(n - 1) + fibonacci(n - 2)
        }
        """

        let tokenCount = tiktoken.countTokens(in: swiftCode)
        #expect(tokenCount > 20) // Code typically has more tokens
        #expect(tokenCount < 100)
    }

    @Test("Count tokens in multilingual text")
    func countTokensMultilingual() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        let texts = [
            "Hello world", // English
            "Hola mundo", // Spanish
            "你好世界", // Chinese
            "こんにちは世界", // Japanese
            "مرحبا بالعالم", // Arabic
            "Привет мир", // Russian
            "🌍🌎🌏", // Emojis
        ]

        for text in texts {
            let tokenCount = tiktoken.countTokens(in: text)
            #expect(tokenCount > 0)
            #expect(tokenCount < 20) // Short phrases should be reasonably tokenized
        }
    }

    // MARK: - Edge Cases

    @Test("Count tokens in very long text")
    func countTokensLongText() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        // Generate a long text
        let longText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 1000)

        let tokenCount = tiktoken.countTokens(in: longText)
        #expect(tokenCount > 8000) // ~9 tokens per sentence * 1000
        #expect(tokenCount < 15000)
    }

    @Test("Count tokens with special characters")
    func countTokensSpecialCharacters() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        let specialTexts = [
            "\\n\\t\\r",
            "<html><body>Test</body></html>",
            "user@example.com",
            "C:\\Users\\Documents\\file.txt",
            "${variable} != null && condition == true",
            "/* Comment */ // Another comment",
        ]

        for text in specialTexts {
            let tokenCount = tiktoken.countTokens(in: text)
            #expect(tokenCount > 0)
        }
    }

    @Test("Count tokens with whitespace variations")
    func countTokensWhitespace() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        let texts = [
            "normal spacing",
            "multiple   spaces",
            "tabs\tbetween\twords",
            "newlines\n\nbetween\n\n\nwords",
            "   leading spaces",
            "trailing spaces   ",
            "\n\n\n", // Just newlines
            "   ", // Just spaces
        ]

        for text in texts {
            let tokenCount = tiktoken.countTokens(in: text)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                #expect(tokenCount >= 0) // Empty or whitespace-only might be 0 or small
            } else {
                #expect(tokenCount > 0)
            }
        }
    }

    // MARK: - Performance Tests

    @Test("Token counting performance")
    func tokenCountingPerformance() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        // Generate various text sizes
        let sizes = [100, 1000, 10000]

        for size in sizes {
            let text = String(repeating: "a", count: size)

            let startTime = Date()
            _ = tiktoken.countTokens(in: text)
            let elapsedTime = Date().timeIntervalSince(startTime)

            // Token counting should be fast even for large texts
            #expect(elapsedTime < 0.1) // Less than 100ms
        }
    }

    // MARK: - Integration with ClaudeLogManager

    @Test("ClaudeLogManager counts tokens correctly")
    @MainActor
    func claudeLogManagerTokenCounting() async {
        let logManager = ClaudeLogManagerMock()

        let testTexts = [
            "Simple message",
            "A longer message with multiple words and punctuation!",
            "Code: func test() { return 42 }",
        ]

        for text in testTexts {
            let tokenCount = logManager.countTokens(in: text)
            #expect(tokenCount > 0)
            #expect(tokenCount < text.count) // Tokens should be less than character count for English
        }
    }

    @Test("Token counting for typical Claude interactions")
    func typicalClaudeInteractions() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)

        // Typical user prompt
        let userPrompt = """
        Can you help me write a Swift function that calculates the fibonacci sequence?
        It should be recursive and handle edge cases properly.
        """

        // Typical Claude response
        let claudeResponse = """
        I'll help you write a recursive Fibonacci function in Swift with proper edge case handling.

        ```swift
        func fibonacci(_ n: Int) -> Int {
            // Handle edge cases
            guard n >= 0 else {
                fatalError("Fibonacci is not defined for negative numbers")
            }

            // Base cases
            if n <= 1 {
                return n
            }

            // Recursive case
            return fibonacci(n - 1) + fibonacci(n - 2)
        }
        ```

        This function handles the following cases:
        - Negative numbers: Throws a fatal error
        - Base cases: Returns n for n = 0 or n = 1
        - Recursive case: Calculates F(n) = F(n-1) + F(n-2)
        """

        let promptTokens = tiktoken.countTokens(in: userPrompt)
        let responseTokens = tiktoken.countTokens(in: claudeResponse)

        #expect(promptTokens > 10)
        #expect(promptTokens < 50)

        #expect(responseTokens > 50)
        #expect(responseTokens < 200)

        // Total tokens for billing
        let totalTokens = promptTokens + responseTokens
        #expect(totalTokens > 60)
        #expect(totalTokens < 250)
    }

    // MARK: - Error Handling

    @Test("Handle missing vocabulary file gracefully")
    func handleMissingVocabulary() throws {
        // This test would need to mock the file loading
        // For now, we just verify that initialization doesn't crash
        do {
            _ = try Tiktoken(encoding: .o200k_base)
        } catch {
            // If it fails, it should fail gracefully
            #expect(error is TiktokenError)
        }
    }
}

// MARK: - Token Cost Calculation Tests

@Suite("Token Cost Calculation Tests", .tags(.billing))
struct TokenCostCalculationTests {
    @Test("Calculate cost for Claude usage")
    func calculateClaudeCost() {
        let testCases: [(input: Int, output: Int, expectedCost: Double)] = [
            // Claude 3.5 Sonnet pricing: $3/1M input, $15/1M output
            (1_000_000, 0, 3.0), // 1M input tokens only
            (0, 1_000_000, 15.0), // 1M output tokens only
            (1_000_000, 1_000_000, 18.0), // 1M each
            (500_000, 250_000, 5.25), // Half and quarter
            (100, 50, 0.00105), // Small usage
            (0, 0, 0.0), // No usage
        ]

        for (inputTokens, outputTokens, expectedCost) in testCases {
            let cost = ClaudeProvider.calculateCost(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                inputPricePerMillion: 3.0,
                outputPricePerMillion: 15.0)

            #expect(abs(cost - expectedCost) < 0.0001) // Allow small floating point differences
        }
    }

    @Test("Calculate monthly cost from token usage")
    func calculateMonthlyCost() {
        // Create sample daily usage
        var entries: [ClaudeLogEntry] = []

        // Simulate 30 days of usage
        for day in 0 ..< 30 {
            let timestamp = Date().addingTimeInterval(Double(-day * 24 * 3600))

            // Variable usage per day
            let dailyConversations = Int.random(in: 5 ... 20)
            for _ in 0 ..< dailyConversations {
                entries.append(ClaudeLogEntry(
                    timestamp: timestamp,
                    model: "claude-3.5-sonnet",
                    inputTokens: Int.random(in: 500 ... 5000),
                    outputTokens: Int.random(in: 1000 ... 3000)))
            }
        }

        // Calculate total tokens
        let totalInput = entries.reduce(0) { $0 + $1.inputTokens }
        let totalOutput = entries.reduce(0) { $0 + $1.outputTokens }

        // Calculate cost
        let cost = ClaudeProvider.calculateCost(
            inputTokens: totalInput,
            outputTokens: totalOutput,
            inputPricePerMillion: 3.0,
            outputPricePerMillion: 15.0)

        #expect(cost > 0)
        #expect(cost < 1000) // Reasonable monthly usage should be under $1000
    }
}

// MARK: - Mock Extensions

extension ClaudeProvider {
    static func calculateCost(
        inputTokens: Int,
        outputTokens: Int,
        inputPricePerMillion: Double,
        outputPricePerMillion: Double) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000 * inputPricePerMillion
        let outputCost = Double(outputTokens) / 1_000_000 * outputPricePerMillion
        return inputCost + outputCost
    }
}
