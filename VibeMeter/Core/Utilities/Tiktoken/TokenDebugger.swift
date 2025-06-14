import Foundation
import os

/// Protocol for token encoding/decoding
protocol TokenEncoder {
    func encode(_ text: String) -> [Int]
    func decode(_ tokens: [Int]) -> String
    func countTokens(in text: String) -> Int
}

/// Make Tiktoken conform to TokenEncoder
extension Tiktoken: TokenEncoder {}

/// Debugging and visualization tools for BPE tokenization
final class TokenDebugger {
    private let encoder: TokenEncoder
    private let logger = Logger(subsystem: "com.steipete.VibeMeter", category: "TokenDebugger")
    
    init(encoder: TokenEncoder? = nil) {
        if let encoder = encoder {
            self.encoder = encoder
        } else {
            // Default to o200k_base encoding
            do {
                self.encoder = try Tiktoken(encoding: .o200k_base)
            } catch {
                // Fallback to a simple encoder if tiktoken fails
                self.encoder = FallbackTokenEncoder()
            }
        }
    }
    
    // MARK: - Token Visualization
    
    /// Visualize tokenization of text with colored output
    func visualizeTokens(_ text: String) -> TokenVisualization {
        let tokens = encoder.encode(text)
        var segments: [TokenSegment] = []
        var currentPosition = 0
        
        // Decode each token to find its text representation
        for (index, token) in tokens.enumerated() {
            let decoded = encoder.decode([token])
            let segment = TokenSegment(
                token: token,
                text: decoded,
                startIndex: currentPosition,
                endIndex: currentPosition + decoded.count,
                color: colorForToken(index)
            )
            segments.append(segment)
            currentPosition += decoded.count
        }
        
        return TokenVisualization(
            originalText: text,
            tokens: tokens,
            segments: segments,
            tokenCount: tokens.count,
            characterCount: text.count,
            compressionRatio: Double(text.count) / Double(tokens.count)
        )
    }
    
    /// Generate color for token visualization
    private func colorForToken(_ index: Int) -> TokenColor {
        let colors: [TokenColor] = [.red, .green, .blue, .yellow, .magenta, .cyan]
        return colors[index % colors.count]
    }
    
    // MARK: - Token Analysis
    
    /// Analyze tokenization patterns in text
    func analyzeTokenization(_ text: String) -> TokenizationAnalysis {
        let tokens = encoder.encode(text)
        let uniqueTokens = Set(tokens)
        
        // Token frequency
        var tokenFrequency: [Int: Int] = [:]
        for token in tokens {
            tokenFrequency[token, default: 0] += 1
        }
        
        // Find most/least common tokens
        let sortedByFrequency = tokenFrequency.sorted { $0.value > $1.value }
        let mostCommon = Array(sortedByFrequency.prefix(10))
        let leastCommon = Array(sortedByFrequency.suffix(10).reversed())
        
        // Token length distribution
        var lengthDistribution: [Int: Int] = [:]
        for token in tokens {
            let decoded = encoder.decode([token])
            let length = decoded.count
            lengthDistribution[length, default: 0] += 1
        }
        
        // Special token detection
        let specialTokens = tokens.filter { $0 >= 50000 } // Assuming special tokens have high IDs
        
        return TokenizationAnalysis(
            totalTokens: tokens.count,
            uniqueTokens: uniqueTokens.count,
            averageTokenLength: calculateAverageTokenLength(tokens),
            tokenFrequency: tokenFrequency,
            mostCommonTokens: mostCommon,
            leastCommonTokens: leastCommon,
            lengthDistribution: lengthDistribution,
            specialTokenCount: specialTokens.count,
            compressionRatio: Double(text.count) / Double(tokens.count)
        )
    }
    
    private func calculateAverageTokenLength(_ tokens: [Int]) -> Double {
        guard !tokens.isEmpty else { return 0 }
        
        let totalLength = tokens.reduce(0) { sum, token in
            sum + encoder.decode([token]).count
        }
        
        return Double(totalLength) / Double(tokens.count)
    }
    
    // MARK: - Token Diff
    
    /// Compare tokenization between two texts
    func compareTokenization(_ text1: String, _ text2: String) -> TokenizationDiff {
        let tokens1 = encoder.encode(text1)
        let tokens2 = encoder.encode(text2)
        
        // Find common subsequences
        let lcs = longestCommonSubsequence(tokens1, tokens2)
        
        // Calculate differences
        let added = tokens2.count - lcs.count
        let removed = tokens1.count - lcs.count
        let unchanged = lcs.count
        
        // Token-level diff
        var diffs: [TokenDiffEntry] = []
        var i = 0, j = 0
        
        while i < tokens1.count || j < tokens2.count {
            if i < tokens1.count && j < tokens2.count && tokens1[i] == tokens2[j] {
                diffs.append(TokenDiffEntry(
                    type: .unchanged,
                    token: tokens1[i],
                    text: encoder.decode([tokens1[i]]),
                    position: i
                ))
                i += 1
                j += 1
            } else if j >= tokens2.count || (i < tokens1.count && !tokens2.contains(tokens1[i])) {
                diffs.append(TokenDiffEntry(
                    type: .removed,
                    token: tokens1[i],
                    text: encoder.decode([tokens1[i]]),
                    position: i
                ))
                i += 1
            } else {
                diffs.append(TokenDiffEntry(
                    type: .added,
                    token: tokens2[j],
                    text: encoder.decode([tokens2[j]]),
                    position: j
                ))
                j += 1
            }
        }
        
        return TokenizationDiff(
            text1: text1,
            text2: text2,
            tokens1: tokens1,
            tokens2: tokens2,
            added: added,
            removed: removed,
            unchanged: unchanged,
            similarity: Double(unchanged) / Double(max(tokens1.count, tokens2.count)),
            diffs: diffs
        )
    }
    
    private func longestCommonSubsequence(_ arr1: [Int], _ arr2: [Int]) -> [Int] {
        let m = arr1.count
        let n = arr2.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 1...m {
            for j in 1...n {
                if arr1[i-1] == arr2[j-1] {
                    dp[i][j] = dp[i-1][j-1] + 1
                } else {
                    dp[i][j] = max(dp[i-1][j], dp[i][j-1])
                }
            }
        }
        
        // Reconstruct LCS
        var lcs: [Int] = []
        var i = m, j = n
        while i > 0 && j > 0 {
            if arr1[i-1] == arr2[j-1] {
                lcs.append(arr1[i-1])
                i -= 1
                j -= 1
            } else if dp[i-1][j] > dp[i][j-1] {
                i -= 1
            } else {
                j -= 1
            }
        }
        
        return lcs.reversed()
    }
    
    // MARK: - Performance Profiling
    
    /// Profile tokenization performance
    func profilePerformance(text: String, iterations: Int = 100) -> PerformanceProfile {
        var encodingTimes: [TimeInterval] = []
        var decodingTimes: [TimeInterval] = []
        var memorySamples: [Int] = []
        
        // Warm up
        _ = encoder.encode(text)
        
        // Encoding performance
        for _ in 0..<iterations {
            let startMemory = getCurrentMemoryUsage()
            
            let encodeStart = Date()
            let tokens = encoder.encode(text)
            let encodeTime = Date().timeIntervalSince(encodeStart)
            encodingTimes.append(encodeTime)
            
            let decodeStart = Date()
            _ = encoder.decode(tokens)
            let decodeTime = Date().timeIntervalSince(decodeStart)
            decodingTimes.append(decodeTime)
            
            let endMemory = getCurrentMemoryUsage()
            memorySamples.append(endMemory - startMemory)
        }
        
        // Calculate statistics
        let avgEncoding = encodingTimes.reduce(0, +) / Double(iterations)
        let avgDecoding = decodingTimes.reduce(0, +) / Double(iterations)
        let avgMemory = memorySamples.reduce(0, +) / iterations
        
        let throughput = Double(text.count) / avgEncoding // chars per second
        
        return PerformanceProfile(
            textLength: text.count,
            iterations: iterations,
            averageEncodingTime: avgEncoding,
            averageDecodingTime: avgDecoding,
            minEncodingTime: encodingTimes.min() ?? 0,
            maxEncodingTime: encodingTimes.max() ?? 0,
            throughputCharsPerSecond: throughput,
            averageMemoryUsage: avgMemory,
            encodingTimes: encodingTimes,
            decodingTimes: decodingTimes
        )
    }
    
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
    
    // MARK: - Export Functions
    
    /// Export visualization as HTML
    func exportVisualizationHTML(_ visualization: TokenVisualization) -> String {
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Token Visualization</title>
            <style>
                body { font-family: monospace; padding: 20px; }
                .token { padding: 2px 4px; margin: 1px; border-radius: 3px; display: inline-block; }
                .token-red { background-color: #ffcccc; }
                .token-green { background-color: #ccffcc; }
                .token-blue { background-color: #ccccff; }
                .token-yellow { background-color: #ffffcc; }
                .token-magenta { background-color: #ffccff; }
                .token-cyan { background-color: #ccffff; }
                .stats { margin-top: 20px; padding: 10px; background-color: #f0f0f0; }
                .legend { margin: 20px 0; }
                .legend-item { display: inline-block; margin-right: 20px; }
            </style>
        </head>
        <body>
            <h1>Token Visualization</h1>
            <div class="stats">
                <p>Total Tokens: \(visualization.tokenCount)</p>
                <p>Characters: \(visualization.characterCount)</p>
                <p>Compression Ratio: \(String(format: "%.2f", visualization.compressionRatio))</p>
            </div>
            <h2>Tokenized Text</h2>
            <div class="tokenized">
        """
        
        for segment in visualization.segments {
            let colorClass = "token-\(segment.color)"
            let escapedText = segment.text
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: " ", with: "&nbsp;")
                .replacingOccurrences(of: "\n", with: "<br>")
            
            html += """
            <span class="token \(colorClass)" title="Token: \(segment.token)">\(escapedText)</span>
            """
        }
        
        html += """
            </div>
            <div class="legend">
                <h3>Legend</h3>
        """
        
        for (index, segment) in visualization.segments.enumerated() {
            if index < 10 { // Show first 10 tokens in legend
                html += """
                <div class="legend-item">
                    <span class="token token-\(segment.color)">\(segment.token)</span>
                    = "\(segment.text.replacingOccurrences(of: "\n", with: "\\n"))"
                </div>
                """
            }
        }
        
        html += """
            </div>
        </body>
        </html>
        """
        
        return html
    }
}

// MARK: - Data Models

struct TokenVisualization {
    let originalText: String
    let tokens: [Int]
    let segments: [TokenSegment]
    let tokenCount: Int
    let characterCount: Int
    let compressionRatio: Double
}

struct TokenSegment {
    let token: Int
    let text: String
    let startIndex: Int
    let endIndex: Int
    let color: TokenColor
}

enum TokenColor: String {
    case red, green, blue, yellow, magenta, cyan
}

struct TokenizationAnalysis {
    let totalTokens: Int
    let uniqueTokens: Int
    let averageTokenLength: Double
    let tokenFrequency: [Int: Int]
    let mostCommonTokens: [(Int, Int)]
    let leastCommonTokens: [(Int, Int)]
    let lengthDistribution: [Int: Int]
    let specialTokenCount: Int
    let compressionRatio: Double
    
    var summary: String {
        """
        Tokenization Analysis:
        - Total tokens: \(totalTokens)
        - Unique tokens: \(uniqueTokens)
        - Average token length: \(String(format: "%.2f", averageTokenLength)) characters
        - Special tokens: \(specialTokenCount)
        - Compression ratio: \(String(format: "%.2f", compressionRatio))
        - Most common token: \(mostCommonTokens.first.map { "ID \($0.0) (\($0.1) times)" } ?? "None")
        """
    }
}

struct TokenizationDiff {
    let text1: String
    let text2: String
    let tokens1: [Int]
    let tokens2: [Int]
    let added: Int
    let removed: Int
    let unchanged: Int
    let similarity: Double
    let diffs: [TokenDiffEntry]
}

struct TokenDiffEntry {
    enum DiffType {
        case added, removed, unchanged
    }
    
    let type: DiffType
    let token: Int
    let text: String
    let position: Int
}

struct PerformanceProfile {
    let textLength: Int
    let iterations: Int
    let averageEncodingTime: TimeInterval
    let averageDecodingTime: TimeInterval
    let minEncodingTime: TimeInterval
    let maxEncodingTime: TimeInterval
    let throughputCharsPerSecond: Double
    let averageMemoryUsage: Int
    let encodingTimes: [TimeInterval]
    let decodingTimes: [TimeInterval]
    
    var summary: String {
        """
        Performance Profile:
        - Text length: \(textLength) characters
        - Iterations: \(iterations)
        - Average encoding: \(String(format: "%.3f", averageEncodingTime * 1000))ms
        - Average decoding: \(String(format: "%.3f", averageDecodingTime * 1000))ms
        - Throughput: \(String(format: "%.0f", throughputCharsPerSecond)) chars/sec
        - Memory overhead: \(ByteCountFormatter.string(fromByteCount: Int64(averageMemoryUsage), countStyle: .memory))
        """
    }
}

// MARK: - Debug Console Commands

extension TokenDebugger {
    /// Interactive debug console for testing tokenization
    func startDebugConsole() {
        print("Token Debugger Console")
        print("Commands: 'tokenize <text>', 'analyze <text>', 'compare <text1> | <text2>', 'profile <text>', 'quit'")
        
        while true {
            print("> ", terminator: "")
            guard let input = readLine() else { break }
            
            let parts = input.split(separator: " ", maxSplits: 1)
            guard !parts.isEmpty else { continue }
            
            let command = String(parts[0])
            let argument = parts.count > 1 ? String(parts[1]) : ""
            
            switch command {
            case "tokenize":
                let viz = visualizeTokens(argument)
                print("Tokens: \(viz.tokens)")
                print("Count: \(viz.tokenCount)")
                print("Compression: \(String(format: "%.2fx", viz.compressionRatio))")
                
            case "analyze":
                let analysis = analyzeTokenization(argument)
                print(analysis.summary)
                
            case "compare":
                let texts = argument.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
                if texts.count == 2 {
                    let diff = compareTokenization(String(texts[0]), String(texts[1]))
                    print("Similarity: \(String(format: "%.1f%%", diff.similarity * 100))")
                    print("Added: \(diff.added), Removed: \(diff.removed), Unchanged: \(diff.unchanged)")
                } else {
                    print("Usage: compare <text1> | <text2>")
                }
                
            case "profile":
                let profile = profilePerformance(text: argument, iterations: 10)
                print(profile.summary)
                
            case "quit", "exit":
                return
                
            default:
                print("Unknown command: \(command)")
            }
        }
    }
}

// MARK: - Fallback Token Encoder

/// Simple fallback encoder when Tiktoken is not available
struct FallbackTokenEncoder: TokenEncoder {
    func encode(_ text: String) -> [Int] {
        // Simple character-based encoding
        return Array(text.utf8).map { Int($0) }
    }
    
    func decode(_ tokens: [Int]) -> String {
        let bytes = tokens.compactMap { UInt8(exactly: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
    
    func countTokens(in text: String) -> Int {
        // Estimate ~4 characters per token
        return max(1, text.count / 4)
    }
}
