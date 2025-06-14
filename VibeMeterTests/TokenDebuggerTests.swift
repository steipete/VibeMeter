import Foundation
import Testing
@testable import VibeMeter

// MARK: - Token Debugger Tests

@Suite("TokenDebugger Tests", .tags(.tiktoken))
struct TokenDebuggerTests {
    private let debugger = TokenDebugger()
    
    // MARK: - Visualization Tests
    
    @Test("Token visualization basic")
    func tokenVisualizationBasic() throws {
        let text = "Hello, world!"
        let viz = debugger.visualizeTokens(text)
        
        #expect(viz.originalText == text)
        #expect(viz.tokenCount > 0)
        #expect(viz.characterCount == text.count)
        #expect(viz.compressionRatio > 0)
        #expect(!viz.segments.isEmpty)
        
        // Check segments cover the entire text
        var reconstructed = ""
        for segment in viz.segments {
            reconstructed += segment.text
        }
        #expect(reconstructed == text)
    }
    
    @Test("Token visualization with special characters")
    func tokenVisualizationSpecialChars() throws {
        let text = "Hello 🌍! Test\n\tNewline and tab."
        let viz = debugger.visualizeTokens(text)
        
        #expect(viz.segments.count > 0)
        
        // Verify all segments have valid colors
        for segment in viz.segments {
            #expect(segment.color != nil)
            #expect(segment.token >= 0)
        }
    }
    
    // MARK: - Analysis Tests
    
    @Test("Tokenization analysis")
    func tokenizationAnalysis() throws {
        let text = "The quick brown fox jumps over the lazy dog. The fox is quick."
        let analysis = debugger.analyzeTokenization(text)
        
        #expect(analysis.totalTokens > 0)
        #expect(analysis.uniqueTokens > 0)
        #expect(analysis.uniqueTokens <= analysis.totalTokens)
        #expect(analysis.averageTokenLength > 0)
        #expect(!analysis.tokenFrequency.isEmpty)
        #expect(!analysis.mostCommonTokens.isEmpty)
        #expect(analysis.compressionRatio > 0)
        
        // "The" and "the" should be common tokens
        let hasRepeatedTokens = analysis.tokenFrequency.values.contains { $0 > 1 }
        #expect(hasRepeatedTokens, "Should have repeated tokens")
    }
    
    @Test("Analysis of empty text")
    func analysisEmptyText() throws {
        let analysis = debugger.analyzeTokenization("")
        
        #expect(analysis.totalTokens == 0)
        #expect(analysis.uniqueTokens == 0)
        #expect(analysis.tokenFrequency.isEmpty)
    }
    
    // MARK: - Diff Tests
    
    @Test("Token diff identical texts")
    func tokenDiffIdentical() throws {
        let text = "Hello, world!"
        let diff = debugger.compareTokenization(text, text)
        
        #expect(diff.similarity == 1.0)
        #expect(diff.added == 0)
        #expect(diff.removed == 0)
        #expect(diff.unchanged == diff.tokens1.count)
    }
    
    @Test("Token diff different texts")
    func tokenDiffDifferent() throws {
        let text1 = "Hello, world!"
        let text2 = "Hello, universe!"
        let diff = debugger.compareTokenization(text1, text2)
        
        #expect(diff.similarity > 0 && diff.similarity < 1)
        #expect(diff.added > 0 || diff.removed > 0)
        #expect(diff.unchanged > 0) // "Hello, " should be common
    }
    
    @Test("Token diff completely different")
    func tokenDiffCompletelyDifferent() throws {
        let text1 = "ABCDEF"
        let text2 = "123456"
        let diff = debugger.compareTokenization(text1, text2)
        
        #expect(diff.similarity < 0.5)
        #expect(diff.unchanged == 0 || diff.unchanged < min(diff.tokens1.count, diff.tokens2.count) / 2)
    }
    
    // MARK: - Performance Tests
    
    @Test("Performance profiling")
    func performanceProfiling() throws {
        let text = String(repeating: "Test text for performance. ", count: 100)
        let profile = debugger.profilePerformance(text: text, iterations: 10)
        
        #expect(profile.textLength == text.count)
        #expect(profile.iterations == 10)
        #expect(profile.averageEncodingTime > 0)
        #expect(profile.averageDecodingTime > 0)
        #expect(profile.throughputCharsPerSecond > 0)
        #expect(profile.encodingTimes.count == 10)
        #expect(profile.decodingTimes.count == 10)
        
        // Encoding should generally be slower than decoding
        #expect(profile.averageEncodingTime >= profile.averageDecodingTime * 0.5)
    }
    
    // MARK: - HTML Export Tests
    
    @Test("HTML export")
    func htmlExport() throws {
        let text = "Hello, world!"
        let viz = debugger.visualizeTokens(text)
        let html = debugger.exportVisualizationHTML(viz)
        
        #expect(html.contains("<html>"))
        #expect(html.contains("</html>"))
        #expect(html.contains("Token Visualization"))
        #expect(html.contains("Total Tokens:"))
        #expect(html.contains("class=\"token"))
        
        // Check for escaped HTML
        let textWithHTML = "Test <tag> & \"quotes\""
        let vizHTML = debugger.visualizeTokens(textWithHTML)
        let exportedHTML = debugger.exportVisualizationHTML(vizHTML)
        
        #expect(exportedHTML.contains("&lt;tag&gt;"))
        #expect(exportedHTML.contains("&amp;"))
    }
}

// MARK: - Vocabulary Validator Tests

@Suite("VocabularyValidator Tests", .tags(.tiktoken))
struct VocabularyValidatorTests {
    private let validator = VocabularyValidator()
    
    @Test("Validate missing file")
    func validateMissingFile() async throws {
        let url = URL(fileURLWithPath: "/nonexistent/vocab.tiktoken")
        let result = await validator.validate(vocabularyURL: url)
        
        #expect(!result.isValid)
        #expect(result.errors.count > 0)
        #expect(result.errors.contains { error in
            if case .fileNotFound = error { return true }
            return false
        })
    }
    
    @Test("Checksum computation")
    func checksumComputation() async throws {
        // Create a temporary file with known content
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_vocab.tiktoken")
        let testData = "test content".data(using: .utf8)!
        
        try testData.write(to: testFile)
        defer { try? FileManager.default.removeItem(at: testFile) }
        
        let result = await validator.validate(vocabularyURL: testFile)
        
        #expect(!result.checksum.isEmpty)
        #expect(result.checksum.count == 64) // SHA256 hex string length
    }
    
    @Test("Generate statistics")
    func generateStatistics() async throws {
        // This would require a real vocabulary file
        // For now, test that it handles missing files gracefully
        let url = URL(fileURLWithPath: "/nonexistent/vocab.tiktoken")
        let stats = await validator.generateStatistics(vocabularyURL: url)
        
        #expect(stats == nil)
    }
}

// MARK: - SIMD Merge Finder Tests

@Suite("SIMDMergeFinder Tests", .tags(.tiktoken, .performance))
struct SIMDMergeFinderTests {
    private func createTestRanks() -> [Data: Int] {
        var ranks: [Data: Int] = [:]
        
        // Single bytes
        for i in 0..<256 {
            ranks[Data([UInt8(i)])] = i
        }
        
        // Common pairs
        ranks["th".data(using: .utf8)!] = 256
        ranks["he".data(using: .utf8)!] = 257
        ranks["the".data(using: .utf8)!] = 258
        
        return ranks
    }
    
    @Test("Find best merge basic")
    func findBestMergeBasic() throws {
        let ranks = createTestRanks()
        let finder = SIMDMergeFinder(bytePairRanks: ranks)
        
        // Test with "the" split into parts
        let parts = [
            "t".data(using: .utf8)!,
            "h".data(using: .utf8)!,
            "e".data(using: .utf8)!
        ]
        
        if let (index, rank) = finder.findBestMerge(in: parts) {
            #expect(index == 0) // Should merge "t" + "h"
            #expect(rank == 256) // Rank of "th"
        } else {
            Issue.record("Expected to find a merge")
        }
    }
    
    @Test("Find best merge with priority")
    func findBestMergePriority() throws {
        let ranks = createTestRanks()
        let finder = SIMDMergeFinder(bytePairRanks: ranks)
        
        // "the" has lower rank (258) than "th" (256) + "e" (101)
        // But we have "th" and "he" as options
        let parts = [
            "t".data(using: .utf8)!,
            "h".data(using: .utf8)!,
            "e".data(using: .utf8)!,
            "r".data(using: .utf8)!
        ]
        
        if let (index, rank) = finder.findBestMerge(in: parts) {
            // Should prefer "th" (256) over "he" (257)
            #expect(index == 0)
            #expect(rank == 256)
        } else {
            Issue.record("Expected to find a merge")
        }
    }
    
    @Test("SIMD vs scalar performance")
    func simdVsScalarPerformance() throws {
        let ranks = createTestRanks()
        let finder = SIMDMergeFinder(bytePairRanks: ranks)
        
        // Create a large array of parts
        var parts: [Data] = []
        for _ in 0..<1000 {
            parts.append("a".data(using: .utf8)!)
            parts.append("b".data(using: .utf8)!)
        }
        
        // Time SIMD version
        let simdStart = Date()
        for _ in 0..<100 {
            _ = finder.findBestMerge(in: parts)
        }
        let simdTime = Date().timeIntervalSince(simdStart)
        
        print("SIMD merge finding: \(simdTime * 1000)ms for 100 iterations")
        #expect(simdTime < 1.0) // Should complete in under 1 second
    }
}