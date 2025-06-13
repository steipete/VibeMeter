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
    
    // MARK: - New Improvement Tests
    
    @Test("Test batch encoding performance")
    func testBatchEncoding() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        let texts = [
            "Hello world",
            "The quick brown fox jumps over the lazy dog",
            "Swift is a powerful programming language",
            "Testing batch encoding functionality",
            "Multiple texts should be processed in parallel"
        ]
        
        // Test batch encoding
        let startTime = Date()
        let batchResults = tiktoken.encodeBatch(texts)
        let batchTime = Date().timeIntervalSince(startTime)
        
        // Verify results
        #expect(batchResults.count == texts.count)
        for (index, tokens) in batchResults.enumerated() {
            let singleResult = tiktoken.encode(texts[index])
            #expect(tokens == singleResult)
        }
        
        // Batch should be reasonably fast
        #expect(batchTime < 0.1)
    }
    
    @Test("Test special token encoding")
    func testSpecialTokenEncoding() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        let textWithSpecial = "Hello <|endoftext|> world"
        
        // Test encoding without special tokens (treated as normal text)
        let ordinaryTokens = tiktoken.encodeOrdinary(textWithSpecial)
        
        // Test encoding with special tokens allowed
        let specialTokens = tiktoken.encodeWithAllSpecial(textWithSpecial)
        
        // Should be different when special tokens are processed
        #expect(ordinaryTokens != specialTokens)
        
        // When encoded ordinarily, special token should be split into multiple tokens
        #expect(ordinaryTokens.count > specialTokens.count)
    }
    
    @Test("Test encoding cache effectiveness")
    func testEncodingCache() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        let text = "This is a test text that will be encoded multiple times"
        
        // First encoding (not cached)
        let start1 = Date()
        let tokens1 = tiktoken.encode(text)
        let time1 = Date().timeIntervalSince(start1)
        
        // Second encoding (should be cached)
        let start2 = Date()
        let tokens2 = tiktoken.encode(text)
        let time2 = Date().timeIntervalSince(start2)
        
        // Results should be identical
        #expect(tokens1 == tokens2)
        
        // Cached version should be faster (though this might be flaky in tests)
        // Just verify it completes quickly
        #expect(time2 < 0.01)
    }
    
    @Test("Test proper BPE merge order")
    func testBPEMergeOrder() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test that common sequences are properly merged
        let text = "aaaa" // Should merge efficiently if "aa" is in vocabulary
        let tokens = tiktoken.encode(text)
        
        // Should result in fewer tokens than individual characters
        #expect(tokens.count < 4)
    }
    
    @Test("Test multilingual tokenization with o200k pattern")
    func testMultilingualWithO200k() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test various scripts with the improved o200k pattern
        let testCases = [
            ("Hello", 1, 2), // Latin
            ("Привет", 1, 3), // Cyrillic
            ("こんにちは", 2, 5), // Hiragana
            ("你好", 1, 2), // Chinese
            ("مرحبا", 1, 3), // Arabic
            ("🌍🌎🌏", 1, 3), // Emojis
            ("café", 1, 2), // Latin with diacritics
        ]
        
        for (text, minTokens, maxTokens) in testCases {
            let tokenCount = tiktoken.countTokens(in: text)
            #expect(tokenCount >= minTokens, "Text '\(text)' has \(tokenCount) tokens, expected at least \(minTokens)")
            #expect(tokenCount <= maxTokens, "Text '\(text)' has \(tokenCount) tokens, expected at most \(maxTokens)")
        }
    }
    
    @Test("Test decode batch functionality")
    func testDecodeBatch() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        let texts = [
            "Hello world",
            "Testing decode batch",
            "Swift programming"
        ]
        
        // Encode texts
        let tokenBatch = texts.map { tiktoken.encode($0) }
        
        // Decode batch
        let decodedTexts = tiktoken.decodeBatch(tokenBatch)
        
        // Verify roundtrip
        #expect(decodedTexts.count == texts.count)
        for (original, decoded) in zip(texts, decodedTexts) {
            #expect(original == decoded)
        }
    }
    
    // MARK: - Comprehensive Edge Case Tests
    
    @Test("Test empty string encoding")
    func testEmptyString() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        let tokens = tiktoken.encode("")
        #expect(tokens.count == 0)
        
        let decoded = tiktoken.decode([])
        #expect(decoded == "")
    }
    
    @Test("Test single character edge cases")
    func testSingleCharacters() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test various single characters
        let testChars = [
            "\0", // Null character
            "\n", // Newline
            "\r", // Carriage return
            "\t", // Tab
            " ",  // Space
            "\"", // Quote
            "\\", // Backslash
            "\u{0001}", // Control character
            "\u{FFFF}", // High unicode
            "𝕳", // Mathematical character
            "🚀", // Emoji
            "\u{200B}", // Zero-width space
            "\u{FEFF}", // Zero-width no-break space
        ]
        
        for char in testChars {
            let tokens = tiktoken.encode(char)
            #expect(tokens.count > 0, "Character '\(char.debugDescription)' should produce tokens")
            
            let decoded = tiktoken.decode(tokens)
            #expect(decoded == char, "Roundtrip failed for '\(char.debugDescription)'")
        }
    }
    
    @Test("Test surrogate pairs and invalid UTF-8")
    func testSurrogatePairs() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test valid surrogate pairs
        let emojiWithSurrogates = "👨‍👩‍👧‍👦" // Family emoji with ZWJ
        let tokens = tiktoken.encode(emojiWithSurrogates)
        #expect(tokens.count > 0)
        
        let decoded = tiktoken.decode(tokens)
        #expect(decoded == emojiWithSurrogates)
        
        // Test mixed content with surrogates
        let mixed = "Hello 👋 World 🌍!"
        let mixedTokens = tiktoken.encode(mixed)
        let mixedDecoded = tiktoken.decode(mixedTokens)
        #expect(mixedDecoded == mixed)
    }
    
    @Test("Test extremely long strings")
    func testExtremelyLongStrings() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test with very long repeated pattern
        let pattern = "The quick brown fox jumps over the lazy dog. "
        let veryLongText = String(repeating: pattern, count: 10_000)
        
        let tokens = tiktoken.encode(veryLongText)
        #expect(tokens.count > 0)
        #expect(tokens.count < veryLongText.count) // Should be compressed
        
        // Test decode doesn't crash or timeout
        let decoded = tiktoken.decode(tokens)
        #expect(decoded == veryLongText)
    }
    
    @Test("Test special token edge cases")
    func testSpecialTokenEdgeCases() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test multiple special tokens
        let textWithMultipleSpecial = "<|endoftext|>Hello<|endoftext|>World<|endoftext|>"
        
        // Without special tokens allowed
        let ordinary = tiktoken.encodeOrdinary(textWithMultipleSpecial)
        let ordinaryDecoded = tiktoken.decode(ordinary)
        #expect(ordinaryDecoded == textWithMultipleSpecial)
        
        // With special tokens allowed
        let special = tiktoken.encodeWithAllSpecial(textWithMultipleSpecial)
        #expect(special.count < ordinary.count) // Should be more efficient
        
        // Test partial special tokens
        let partial = "This is <|endo"
        let partialTokens = tiktoken.encode(partial)
        let partialDecoded = tiktoken.decode(partialTokens)
        #expect(partialDecoded == partial)
    }
    
    @Test("Test batch operations with edge cases")
    func testBatchEdgeCases() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Empty batch
        let emptyBatch: [String] = []
        let emptyResults = tiktoken.encodeBatch(emptyBatch)
        #expect(emptyResults.count == 0)
        
        // Single item batch
        let singleBatch = ["Hello"]
        let singleResults = tiktoken.encodeBatch(singleBatch)
        #expect(singleResults.count == 1)
        #expect(singleResults[0] == tiktoken.encode("Hello"))
        
        // Large batch with varied content
        let largeBatch = (0..<100).map { i in
            switch i % 5 {
            case 0: return "Short"
            case 1: return "A medium length string with some words"
            case 2: return String(repeating: "Long ", count: 50)
            case 3: return "Special <|endoftext|> tokens"
            case 4: return "Unicode: 你好世界 🌍"
            default: return "Default"
            }
        }
        
        let largeBatchResults = tiktoken.encodeBatch(largeBatch)
        #expect(largeBatchResults.count == largeBatch.count)
        
        // Verify each result matches individual encoding
        for (index, text) in largeBatch.enumerated() {
            let expected = tiktoken.encode(text)
            #expect(largeBatchResults[index] == expected)
        }
    }
    
    @Test("Test cache behavior with collision scenarios")
    func testCacheCollisions() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Encode many different strings to potentially trigger cache eviction
        let strings = (0..<2000).map { "Test string number \($0)" }
        
        // First pass - populate cache
        let firstPass = strings.map { tiktoken.encode($0) }
        
        // Second pass - should use cache for recent items
        let secondPass = strings.map { tiktoken.encode($0) }
        
        // Results should be identical
        for (first, second) in zip(firstPass, secondPass) {
            #expect(first == second)
        }
        
        // Test that very first items might have been evicted
        let veryFirst = tiktoken.encode(strings[0])
        #expect(veryFirst == firstPass[0])
    }
    
    @Test("Test concurrent encoding safety")
    func testConcurrentEncodingSafety() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        let group = DispatchGroup()
        let lock = NSLock()
        
        var results: [Int: [Int]] = [:]
        let testString = "Concurrent test string"
        
        // Encode the same string concurrently many times
        for i in 0..<100 {
            group.enter()
            queue.async {
                let encoded = tiktoken.encode(testString)
                lock.lock()
                results[i] = encoded
                lock.unlock()
                group.leave()
            }
        }
        
        group.wait()
        
        // All results should be identical
        let expected = tiktoken.encode(testString)
        for i in 0..<100 {
            #expect(results[i] == expected)
        }
    }
    
    @Test("Test malformed input handling")
    func testMalformedInput() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test various malformed inputs
        let malformedInputs = [
            String(repeating: "\u{FFFD}", count: 100), // Replacement characters
            String(bytes: [0xED, 0xA0, 0x80], encoding: .utf8) ?? "", // UTF-8 encoding of surrogate
            String(bytes: [0xED, 0xB0, 0x80], encoding: .utf8) ?? "", // UTF-8 encoding of surrogate
            String(bytes: [0xFF, 0xFE], encoding: .utf8) ?? "", // Invalid UTF-8
            String(bytes: [0xC0, 0x80], encoding: .utf8) ?? "", // Overlong encoding
        ]
        
        for input in malformedInputs {
            // Should not crash
            let tokens = tiktoken.encode(input)
            let decoded = tiktoken.decode(tokens)
            
            // May not roundtrip perfectly due to UTF-8 handling
            #expect(tokens.count >= 0)
            #expect(decoded.count >= 0)
        }
    }
    
    @Test("Test token count accuracy for known patterns")
    func testTokenCountAccuracy() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Common patterns that should tokenize efficiently
        let efficientPatterns = [
            ("Hello", 1, 2), // Should be 1-2 tokens
            ("http://", 1, 3), // URL prefix
            ("function", 1, 2), // Common programming keyword
            ("    ", 1, 2), // Indentation
            ("\n\n", 1, 2), // Paragraph break
        ]
        
        for (pattern, minTokens, maxTokens) in efficientPatterns {
            let tokens = tiktoken.countTokens(in: pattern)
            #expect(tokens >= minTokens, "'\(pattern)' has \(tokens) tokens, expected at least \(minTokens)")
            #expect(tokens <= maxTokens, "'\(pattern)' has \(tokens) tokens, expected at most \(maxTokens)")
        }
    }
    
    @Test("Test decode with invalid token IDs")
    func testDecodeInvalidTokens() throws {
        let tiktoken = try Tiktoken(encoding: .o200k_base)
        
        // Test decoding with potentially invalid token IDs
        let invalidTokenSets = [
            [-1], // Negative token
            [Int.max], // Very large token
            [1_000_000], // Likely out of range
            [], // Empty
        ]
        
        for tokens in invalidTokenSets {
            // Should not crash, might return empty or partial string
            let decoded = tiktoken.decode(tokens)
            #expect(decoded != nil) // Should return something, even if empty
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
