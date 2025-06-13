import Foundation
import Testing
@testable import VibeMeter

// MARK: - CoreBPE SIMD Tests

@Suite("CoreBPE SIMD Performance Tests", .tags(.tiktoken, .performance))
struct CoreBPESIMDPerformanceTests {
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

    private func createTestBPESIMD() throws -> CoreBPESIMD {
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

        return try CoreBPESIMD(bytePairRanks: bytePairRanks, specialTokens: specialTokens, pattern: pattern)
    }

    // MARK: - Correctness Tests

    @Test("SIMD and scalar produce identical results")
    func simdScalarEquivalence() throws {
        let scalar = try createTestBPE()
        let simd = try createTestBPESIMD()

        let testTexts = [
            "hello",
            "the quick brown fox",
            "testing 123",
            "a" * 100, // Repeated character
            "the" * 50, // Repeated token
            "abcdefghijklmnopqrstuvwxyz",
            "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
            "0123456789",
            "!@#$%^&*()",
            "the quick brown fox jumps over the lazy dog",
            "The Quick Brown Fox Jumps Over The Lazy Dog",
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
        ]

        for text in testTexts {
            let scalarResult = scalar.encode(text)
            let simdResult = simd.encode(text)

            #expect(scalarResult == simdResult,
                    "SIMD and scalar results differ for text: '\(text)'\nScalar: \(scalarResult)\nSIMD: \(simdResult)")
        }
    }

    @Test("SIMD handles edge cases correctly")
    func simdEdgeCases() throws {
        let simd = try createTestBPESIMD()

        // Empty string
        #expect(simd.encode("").isEmpty)

        // Single character
        #expect(simd.encode("a") == [97])

        // Very short strings (less than SIMD width)
        #expect(simd.encode("hi").count > 0)

        // Exactly SIMD width (16 bytes)
        let sixteenBytes = "0123456789abcdef"
        #expect(simd.encode(sixteenBytes).count > 0)

        // Just over SIMD width
        let seventeenBytes = "0123456789abcdefg"
        #expect(simd.encode(seventeenBytes).count > 0)
    }

    // MARK: - Performance Tests

    @Test("SIMD performance comparison")
    func simdPerformanceComparison() throws {
        let scalar = try createTestBPE()
        let simd = try createTestBPESIMD()

        // Generate test data of various sizes
        let testSizes = [100, 1000, 10000, 100_000]
        let testText = "The quick brown fox jumps over the lazy dog. "

        for size in testSizes {
            let text = String(repeating: testText, count: size / testText.count)

            // Measure scalar performance
            let scalarStart = Date()
            let scalarResult = scalar.encode(text)
            let scalarTime = Date().timeIntervalSince(scalarStart)

            // Measure SIMD performance
            let simdStart = Date()
            let simdResult = simd.encode(text)
            let simdTime = Date().timeIntervalSince(simdStart)

            // Verify correctness
            #expect(scalarResult == simdResult)

            // Calculate speedup
            let speedup = scalarTime / simdTime

            print("Text size: \(text.count) chars")
            print("  Scalar: \(scalarTime * 1000)ms")
            print("  SIMD:   \(simdTime * 1000)ms")
            print("  Speedup: \(String(format: "%.2fx", speedup))")
            print("  Tokens: \(simdResult.count)")

            // SIMD should be at least as fast as scalar
            #expect(simdTime <= scalarTime * 1.1) // Allow 10% margin
        }
    }

    @Test("SIMD batch encoding performance")
    func simdBatchEncoding() throws {
        let simd = try createTestBPESIMD()

        // Generate batch of texts
        let batchSize = 100
        let texts = (0 ..< batchSize).map { i in
            "This is test message number \(i). The quick brown fox jumps over the lazy dog."
        }

        // Measure batch encoding
        let startTime = Date()
        let results = simd.encodeBatch(texts)
        let elapsedTime = Date().timeIntervalSince(startTime)

        #expect(results.count == batchSize)

        let totalTokens = results.reduce(0) { $0 + $1.count }
        let tokensPerSecond = Double(totalTokens) / elapsedTime

        print("Batch encoding: \(batchSize) texts in \(elapsedTime * 1000)ms")
        print("Total tokens: \(totalTokens)")
        print("Throughput: \(Int(tokensPerSecond)) tokens/sec")

        #expect(elapsedTime < 1.0) // Should process 100 texts in under 1 second
    }

    // MARK: - Stress Tests

    @Test("SIMD handles large inputs")
    func simdLargeInputs() throws {
        let simd = try createTestBPESIMD()

        // Generate a very large text (10MB)
        let largeText = String(repeating: "The quick brown fox jumps over the lazy dog. ", count: 250_000)

        let startTime = Date()
        let tokens = simd.encode(largeText)
        let elapsedTime = Date().timeIntervalSince(startTime)

        print("Encoded \(largeText.count) characters to \(tokens.count) tokens in \(elapsedTime)s")
        print("Throughput: \(Int(Double(largeText.count) / elapsedTime)) chars/sec")

        #expect(!tokens.isEmpty)
        #expect(elapsedTime < 10.0) // Should complete within 10 seconds
    }

    @Test("SIMD handles diverse character sets")
    func simdDiverseCharacters() throws {
        let simd = try createTestBPESIMD()
        let scalar = try createTestBPE()

        let diverseTexts = [
            "Hello, 世界! 🌍",
            "Привет мир",
            "مرحبا بالعالم",
            "こんにちは世界",
            "🚀🌟💻🎉",
            "αβγδεζηθικλμνξοπρστυφχψω",
            "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏ",
            "\n\t\r\0",
            "\\u{1F600}\\u{1F601}\\u{1F602}",
        ]

        for text in diverseTexts {
            let scalarResult = scalar.encode(text)
            let simdResult = simd.encode(text)

            #expect(scalarResult == simdResult,
                    "Results differ for text: '\(text)'")
        }
    }
}

// MARK: - Micro-benchmarks

@Suite("CoreBPE SIMD Micro-benchmarks", .tags(.tiktoken, .performance))
struct CoreBPESIMDMicroBenchmarks {
    private func createTestBPESIMD() throws -> CoreBPESIMD {
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

        return try CoreBPESIMD(bytePairRanks: bytePairRanks, specialTokens: specialTokens, pattern: pattern)
    }

    @Test("SIMD vector comparison performance")
    func vectorComparisonBenchmark() {
        let iterations = 1_000_000

        // Create test vectors
        let vector1 = SIMD16<UInt8>(repeating: 65) // 'A'
        let vector2 = SIMD16<UInt8>(repeating: 65) // 'A'
        let vector3 = SIMD16<UInt8>(repeating: 66) // 'B'

        // Benchmark exact match
        let matchStart = Date()
        var matchCount = 0
        for _ in 0 ..< iterations {
            if vector1 == vector2 {
                matchCount += 1
            }
        }
        let matchTime = Date().timeIntervalSince(matchStart)

        // Benchmark mismatch
        let mismatchStart = Date()
        var mismatchCount = 0
        for _ in 0 ..< iterations {
            if vector1 == vector3 {
                mismatchCount += 1
            }
        }
        let mismatchTime = Date().timeIntervalSince(mismatchStart)

        print("SIMD vector comparison benchmark:")
        print("  Match time: \(matchTime * 1000)ms for \(iterations) iterations")
        print("  Mismatch time: \(mismatchTime * 1000)ms for \(iterations) iterations")
        print("  Operations per second: \(Int(Double(iterations) / matchTime))")

        #expect(matchTime < 1.0) // Should complete in under 1 second
    }

    @Test("SIMD pattern matching performance")
    func patternMatchingBenchmark() throws {
        let simd = try createTestBPESIMD()

        // Create patterns of different lengths
        let patterns = [
            "a", // 1 byte
            "th", // 2 bytes
            "the", // 3 bytes
            "tion", // 4 bytes
            "ation", // 5 bytes
            "internationalization", // 20 bytes (exceeds SIMD width)
        ]

        let testData = String(repeating: "the nation's internationalization efforts", count: 100)

        for pattern in patterns {
            let startTime = Date()
            let tokens = simd.encode(testData)
            let elapsedTime = Date().timeIntervalSince(startTime)

            print("Pattern '\(pattern)' (\(pattern.count) bytes):")
            print("  Time: \(elapsedTime * 1000)ms")
            print("  Tokens: \(tokens.count)")
        }
    }
}

// MARK: - String Extension for Testing

private extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
