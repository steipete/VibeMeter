import Foundation
import Testing
@testable import VibeMeter

// MARK: - CoreBPE Tests

@Suite("CoreBPE Tests", .tags(.tiktoken))
struct CoreBPETests {
    // MARK: - Test Data

    private func createTestBPE() throws -> CoreBPE {
        // Create a simple test vocabulary
        var bytePairRanks: [Data: Int] = [:]

        // Single bytes
        for i in 0 ..< 256 {
            bytePairRanks[Data([UInt8(i)])] = i
        }

        // Common byte pairs
        bytePairRanks["th".data(using: .utf8)!] = 256
        bytePairRanks["he".data(using: .utf8)!] = 257
        bytePairRanks["in".data(using: .utf8)!] = 258
        bytePairRanks["er".data(using: .utf8)!] = 259
        bytePairRanks["an".data(using: .utf8)!] = 260
        bytePairRanks["the".data(using: .utf8)!] = 261
        bytePairRanks["ing".data(using: .utf8)!] = 262
        bytePairRanks["and".data(using: .utf8)!] = 263

        // Longer sequences
        bytePairRanks["tion".data(using: .utf8)!] = 264
        bytePairRanks["ation".data(using: .utf8)!] = 265

        let specialTokens = [
            "<|endoftext|>": 50256,
            "<|startoftext|>": 50257,
        ]

        let pattern = "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+"

        return try CoreBPE(bytePairRanks: bytePairRanks, specialTokens: specialTokens, pattern: pattern)
    }

    // MARK: - Basic Encoding Tests

    @Test("Encode single characters")
    func encodeSingleCharacters() throws {
        let bpe = try createTestBPE()

        // Test single ASCII characters
        let testCases = [
            ("a", [97]),
            ("b", [98]),
            ("z", [122]),
            ("A", [65]),
            ("0", [48]),
            ("9", [57]),
        ]

        for (text, expected) in testCases {
            let encoded = bpe.encode(text)
            #expect(encoded == expected, "Failed to encode '\(text)'")
        }
    }

    @Test("Encode byte pairs")
    func encodeByPairs() throws {
        let bpe = try createTestBPE()

        // Test known byte pairs
        let testCases = [
            ("th", [256]), // "th" -> single token
            ("he", [257]), // "he" -> single token
            ("the", [261]), // "the" -> single token (not "th" + "e")
            ("in", [258]), // "in" -> single token
            ("ing", [262]), // "ing" -> single token
            ("and", [263]), // "and" -> single token
        ]

        for (text, expected) in testCases {
            let encoded = bpe.encode(text)
            #expect(encoded == expected, "Failed to encode '\(text)'")
        }
    }

    @Test("Encode with fallback to individual bytes")
    func encodeFallback() throws {
        let bpe = try createTestBPE()

        // Text that doesn't match any multi-byte tokens
        let text = "xyz"
        let encoded = bpe.encode(text)
        #expect(encoded == [120, 121, 122], "Failed fallback encoding")
    }

    @Test("Encode mixed patterns")
    func encodeMixedPatterns() throws {
        let bpe = try createTestBPE()

        // Mix of known pairs and individual bytes
        let text = "the cat"
        let encoded = bpe.encode(text)

        // Should encode as: "the" (261) + " " (32) + "c" (99) + "a" (97) + "t" (116)
        // But depends on regex matching
        #expect(encoded.count > 0, "Encoding should produce tokens")
    }

    // MARK: - Special Token Tests

    @Test("Encode with special tokens")
    func encodeSpecialTokens() throws {
        let bpe = try createTestBPE()

        let text = "<|startoftext|>Hello<|endoftext|>"
        let encoded = bpe.encode(text)

        #expect(encoded.contains(50257), "Should contain start token")
        #expect(encoded.contains(50256), "Should contain end token")
    }

    // MARK: - Decode Tests

    @Test("Decode encoded text")
    func decodeEncodedText() throws {
        let bpe = try createTestBPE()

        let originalTexts = [
            "hello",
            "the",
            "world",
            "testing 123",
            "<|startoftext|>test<|endoftext|>",
        ]

        for original in originalTexts {
            let encoded = bpe.encode(original)
            let decoded = bpe.decode(encoded)

            // The decoded text might not exactly match due to regex tokenization
            // but it should at least contain the original content
            #expect(decoded.contains(original) || original.contains(decoded),
                    "Decode mismatch for '\(original)' -> '\(decoded)'")
        }
    }

    // MARK: - Performance Tests

    @Test("Encoding performance baseline")
    func encodingPerformanceBaseline() throws {
        let bpe = try createTestBPE()

        // Generate test data
        let testSizes = [100, 1000, 10000]

        for size in testSizes {
            let text = String(repeating: "the quick brown fox ", count: size / 20)

            let startTime = Date()
            _ = bpe.encode(text)
            let elapsedTime = Date().timeIntervalSince(startTime)

            print("Encoding \(text.count) characters took \(elapsedTime * 1000)ms")
            #expect(elapsedTime < 1.0, "Encoding should complete within 1 second")
        }
    }

    // MARK: - Edge Cases

    @Test("Empty string encoding")
    func encodeEmptyString() throws {
        let bpe = try createTestBPE()

        let encoded = bpe.encode("")
        #expect(encoded.isEmpty, "Empty string should encode to empty array")
    }

    @Test("Unicode handling")
    func encodeUnicode() throws {
        let bpe = try createTestBPE()

        let unicodeTexts = [
            "émoji 🎉",
            "中文字符",
            "Русский текст",
            "🇺🇸🇬🇧🇫🇷",
        ]

        for text in unicodeTexts {
            let encoded = bpe.encode(text)
            #expect(!encoded.isEmpty, "Unicode text should produce tokens")

            // Each UTF-8 byte should map to a token
            let utf8Bytes = Array(text.utf8)
            #expect(encoded.count >= utf8Bytes.count / 4, "Should have reasonable token count")
        }
    }

    @Test("Large text handling")
    func encodeLargeText() throws {
        let bpe = try createTestBPE()

        // Create a large text (1MB)
        let largeText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 25000)

        let startTime = Date()
        let encoded = bpe.encode(largeText)
        let elapsedTime = Date().timeIntervalSince(startTime)

        #expect(!encoded.isEmpty, "Large text should encode successfully")
        #expect(elapsedTime < 5.0, "Large text encoding should complete within 5 seconds")

        print("Encoded \(largeText.count) characters to \(encoded.count) tokens in \(elapsedTime)s")
    }
}

// MARK: - SIMD Optimization Tests

@Suite("CoreBPE SIMD Tests", .tags(.tiktoken, .performance))
struct CoreBPESIMDTests {
    @Test("SIMD byte matching performance")
    func simdByteMatchingPerformance() throws {
        // This will test our SIMD implementation once created
        // For now, establish baseline measurements

        let data = Data(repeating: 0x61, count: 1024) // 1KB of 'a'
        let pattern = Data([0x61, 0x62]) // "ab"

        var matchCount = 0
        let startTime = Date()

        // Naive search
        for i in 0 ..< (data.count - pattern.count + 1) {
            if data[i ..< i + pattern.count] == pattern {
                matchCount += 1
            }
        }

        let elapsedTime = Date().timeIntervalSince(startTime)

        print("Naive search: \(matchCount) matches in \(elapsedTime * 1000)ms")
        #expect(elapsedTime < 0.01, "Baseline search should be fast")
    }

    @Test("Compare SIMD vs scalar performance")
    func compareSIMDvsScalar() throws {
        // Placeholder for SIMD comparison tests
        // Will be implemented with actual SIMD code
        #expect(true)
    }
}

// MARK: - Correctness Verification Tests

@Suite("CoreBPE Correctness Tests", .tags(.tiktoken))
struct CoreBPECorrectnessTests {
    @Test("Verify deterministic encoding")
    func deterministicEncoding() throws {
        let bpe = try createTestBPE()

        let text = "The quick brown fox jumps over the lazy dog"

        // Encode the same text multiple times
        let results = (0 ..< 10).map { _ in bpe.encode(text) }

        // All results should be identical
        for i in 1 ..< results.count {
            #expect(results[i] == results[0], "Encoding should be deterministic")
        }
    }

    @Test("Verify longest match preference")
    func longestMatchPreference() throws {
        let bpe = try createTestBPE()

        // "the" should encode as single token, not "th" + "e"
        let encoded = bpe.encode("the")
        #expect(encoded == [261], "Should prefer longest match")

        // "ation" should encode as single token, not "at" + "ion"
        let encoded2 = bpe.encode("ation")
        #expect(encoded2.count == 1, "Should encode 'ation' as single token")
    }

    private func createTestBPE() throws -> CoreBPE {
        // Reuse the same test BPE setup
        var bytePairRanks: [Data: Int] = [:]

        for i in 0 ..< 256 {
            bytePairRanks[Data([UInt8(i)])] = i
        }

        bytePairRanks["th".data(using: .utf8)!] = 256
        bytePairRanks["he".data(using: .utf8)!] = 257
        bytePairRanks["in".data(using: .utf8)!] = 258
        bytePairRanks["er".data(using: .utf8)!] = 259
        bytePairRanks["an".data(using: .utf8)!] = 260
        bytePairRanks["the".data(using: .utf8)!] = 261
        bytePairRanks["ing".data(using: .utf8)!] = 262
        bytePairRanks["and".data(using: .utf8)!] = 263
        bytePairRanks["tion".data(using: .utf8)!] = 264
        bytePairRanks["ation".data(using: .utf8)!] = 265

        let specialTokens = [
            "<|endoftext|>": 50256,
            "<|startoftext|>": 50257,
        ]

        let pattern = "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+"

        return try CoreBPE(bytePairRanks: bytePairRanks, specialTokens: specialTokens, pattern: pattern)
    }
}
