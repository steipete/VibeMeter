import Foundation
import Testing
@testable import VibeMeter

// Minimal test to verify tokenizer works
@Suite("Tiktoken Minimal Tests", .tags(.tiktoken))
struct TiktokenMinimalTest {
    @Test("Basic tokenizer functionality")
    func testBasicTokenizer() throws {
        // Check if vocabulary file exists in bundle
        // In unit tests, resources are typically in the main bundle
        guard let vocabURL = Bundle.main.url(forResource: "o200k_base", withExtension: "tiktoken") else {
            // If not found, try looking in all bundles
            for bundle in Bundle.allBundles {
                if let url = bundle.url(forResource: "o200k_base", withExtension: "tiktoken") {
                    print("Found vocabulary in bundle: \(bundle.bundleIdentifier ?? "unknown") at \(url)")
                    break
                }
            }
            Issue.record("Vocabulary file not found in any bundle. Make sure o200k_base.tiktoken is included in the test target's resources.")
            return
        }
        print("Found vocabulary at: \(vocabURL)")
        
        // Try to initialize tokenizer
        do {
            let tiktoken = try Tiktoken(encoding: .o200k_base)
            
            // Test basic encoding
            let text = "Hello world"
            let tokens = tiktoken.encode(text)
            print("Encoded '\(text)' into \(tokens.count) tokens: \(tokens)")
            
            #expect(tokens.count > 0)
            #expect(tokens.count <= text.count) // Tokens should be fewer than characters
            
            // Test decoding
            let decoded = tiktoken.decode(tokens)
            print("Decoded back to: '\(decoded)'")
            
            #expect(decoded == text)
            
            // Test empty string
            let emptyTokens = tiktoken.encode("")
            #expect(emptyTokens.isEmpty)
            
            // Test special characters
            let special = "Hello\nWorld"
            let specialTokens = tiktoken.encode(special)
            let specialDecoded = tiktoken.decode(specialTokens)
            #expect(specialDecoded == special)
            
            print("✓ All basic tests passed")
            
        } catch {
            Issue.record("Failed to initialize tokenizer: \(error)")
        }
    }
}