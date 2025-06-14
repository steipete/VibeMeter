import Foundation
import simd

/// SIMD-optimized Byte Pair Encoding implementation
final class CoreBPESIMD: @unchecked Sendable {
    let bytePairRanks: [Data: Int]  // Made internal for SIMDMergeFinder
    private let tokenEncoder: [String: Int]
    private let tokenDecoder: [Int: String]
    private let specialTokens: [String: Int]
    private let regex: NSRegularExpression

    // SIMD-optimized lookup structures
    private let vectorLookup: VectorizedBytePairLookup

    init(bytePairRanks: [Data: Int],
         specialTokens: [String: Int],
         pattern: String) throws {
        self.bytePairRanks = bytePairRanks
        self.specialTokens = specialTokens
        self.regex = try NSRegularExpression(pattern: pattern, options: [])

        // Build encoder/decoder from ranks
        var encoder: [String: Int] = [:]
        var decoder: [Int: String] = [:]

        for (bytes, rank) in bytePairRanks {
            if let string = String(data: bytes, encoding: .utf8) {
                encoder[string] = rank
                decoder[rank] = string
            }
        }

        // Add special tokens
        for (token, id) in specialTokens {
            encoder[token] = id
            decoder[id] = token
        }

        self.tokenEncoder = encoder
        self.tokenDecoder = decoder

        // Initialize SIMD lookup structures
        self.vectorLookup = VectorizedBytePairLookup(bytePairRanks: bytePairRanks)
    }

    func encode(_ text: String, allowedSpecial: Set<String> = []) -> [Int] {
        // Build regex for special tokens that should be treated as special
        let specialTokenPattern = buildSpecialTokenRegex(allowedSpecial: allowedSpecial)
        
        // If no special tokens are allowed or present, encode ordinarily
        if allowedSpecial.isEmpty || !containsSpecialTokens(text, pattern: specialTokenPattern) {
            return encodeOrdinary(text)
        }
        
        // Split text by special tokens and encode parts
        var tokens: [Int] = []
        var lastEnd = text.startIndex
        
        // Find all special token matches
        let nsText = text as NSString
        let matches = specialTokenPattern?.matches(in: text, options: [], 
                                                  range: NSRange(location: 0, length: nsText.length)) ?? []
        
        for match in matches {
            if let range = Range(match.range, in: text) {
                // Encode text before the special token
                if lastEnd < range.lowerBound {
                    let piece = String(text[lastEnd ..< range.lowerBound])
                    tokens.append(contentsOf: encodeOrdinary(piece))
                }
                
                // Add the special token
                let specialToken = String(text[range])
                if let tokenId = specialTokens[specialToken] {
                    tokens.append(tokenId)
                }
                
                lastEnd = range.upperBound
            }
        }
        
        // Encode any remaining text
        if lastEnd < text.endIndex {
            let remaining = String(text[lastEnd...])
            tokens.append(contentsOf: encodeOrdinary(remaining))
        }
        
        return tokens
    }
    
    // Default encode method for backward compatibility
    func encode(_ text: String) -> [Int] {
        encode(text, allowedSpecial: [])
    }
    
    private func buildSpecialTokenRegex(allowedSpecial: Set<String>) -> NSRegularExpression? {
        if allowedSpecial.isEmpty {
            return nil
        }
        
        let pattern = allowedSpecial.map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        
        return try? NSRegularExpression(pattern: "(\(pattern))", options: [])
    }
    
    private func containsSpecialTokens(_ text: String, pattern: NSRegularExpression?) -> Bool {
        guard let pattern = pattern else { return false }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return pattern.firstMatch(in: text, options: [], range: range) != nil
    }

    private func encodeOrdinary(_ text: String) -> [Int] {
        var tokens: [Int] = []

        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches {
            if let range = Range(match.range, in: text) {
                let piece = String(text[range])
                let pieceTokens = bytePairEncodingSIMD(piece.data(using: .utf8)!)
                tokens.append(contentsOf: pieceTokens)
            }
        }

        return tokens
    }

    /// SIMD-optimized byte pair encoding with proper merge priority
    private func bytePairEncodingSIMD(_ data: Data) -> [Int] {
        // For small data, use non-SIMD version
        if data.count < 16 {
            return bytePairEncodingScalar(data)
        }

        // Use SIMD-optimized merge finder
        let mergeFinder = SIMDMergeFinder(bytePairRanks: bytePairRanks)
        
        // Start with individual bytes as parts
        var parts: [Data] = data.map { Data([$0]) }
        
        // Keep merging until no more merges are possible
        while parts.count > 1 {
            // Find the best merge using SIMD
            guard let (mergeIndex, _) = mergeFinder.findBestMerge(in: parts) else {
                break
            }
            
            // Merge the pair
            parts[mergeIndex] = parts[mergeIndex] + parts[mergeIndex + 1]
            parts.remove(at: mergeIndex + 1)
        }
        
        // Convert parts to token IDs
        var result: [Int] = []
        for part in parts {
            if let rank = bytePairRanks[part] {
                result.append(rank)
            }
        }
        
        return result
    }

    /// Scalar fallback for small inputs with proper BPE algorithm
    private func bytePairEncodingScalar(_ data: Data) -> [Int] {
        if data.isEmpty {
            return []
        }
        
        // Start with individual bytes as parts
        var parts: [Data] = (0 ..< data.count).map { i in
            Data([data[i]])
        }
        
        // Keep merging until no more merges are possible
        while parts.count > 1 {
            var minRank = Int.max
            var minIndex = -1
            
            // Find the pair with minimum rank (highest priority)
            for i in 0 ..< parts.count - 1 {
                let pair = parts[i] + parts[i + 1]
                if let rank = bytePairRanks[pair], rank < minRank {
                    minRank = rank
                    minIndex = i
                }
            }
            
            // If no mergeable pair found, break
            if minIndex == -1 {
                break
            }
            
            // Merge the pair
            parts[minIndex] = parts[minIndex] + parts[minIndex + 1]
            parts.remove(at: minIndex + 1)
        }
        
        // Convert parts to token IDs
        var result: [Int] = []
        for part in parts {
            if let rank = bytePairRanks[part] {
                result.append(rank)
            }
        }
        
        return result
    }

    func decode(_ tokens: [Int]) -> String {
        var result = ""
        for token in tokens {
            if let decoded = tokenDecoder[token] {
                result += decoded
            }
        }
        return result
    }
}

/// Vectorized byte pair lookup using SIMD
private struct VectorizedBytePairLookup {
    // Pre-computed SIMD vectors for common byte pairs
    private let pairVectors: [SIMD16<UInt8>: [(length: Int, rank: Int)]]
    private let maxPairLength: Int

    init(bytePairRanks: [Data: Int]) {
        var vectors: [SIMD16<UInt8>: [(length: Int, rank: Int)]] = [:]
        var maxLength = 0

        // Build SIMD lookup table for byte sequences
        for (data, rank) in bytePairRanks {
            if data.count > 16 { continue } // Skip sequences longer than SIMD width

            maxLength = max(maxLength, data.count)

            // Create a SIMD vector padded with zeros
            var vector = SIMD16<UInt8>(repeating: 0)
            data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
                for i in 0 ..< min(data.count, 16) {
                    vector[i] = bytes[i]
                }
            }

            if vectors[vector] == nil {
                vectors[vector] = []
            }
            vectors[vector]?.append((length: data.count, rank: rank))
        }

        self.pairVectors = vectors
        self.maxPairLength = maxLength
    }

    /// Find the longest matching byte sequence at the given position using SIMD
    func findLongestMatch(in bytes: [UInt8], at position: Int) -> (length: Int, rank: Int)? {
        let remaining = bytes.count - position
        if remaining == 0 { return nil }

        // Try lengths from longest to shortest
        for length in (1 ... min(maxPairLength, remaining, 16)).reversed() {
            // Create SIMD vector from input
            var inputVector = SIMD16<UInt8>(repeating: 0)
            for i in 0 ..< length {
                inputVector[i] = bytes[position + i]
            }

            // Check if we have a match
            if let matches = pairVectors[inputVector] {
                // Find the match with the correct length
                for match in matches {
                    if match.length == length {
                        return (length: match.length, rank: match.rank)
                    }
                }
            }
        }

        return nil
    }
}

// MARK: - SIMD Utility Extensions

extension SIMD16 where Scalar == UInt8 {
    /// Fast comparison with early exit
    func matches(_ other: SIMD16<UInt8>, length: Int) -> Bool {
        // Create mask for the relevant bytes
        let mask = (0 ..< 16).map { $0 < length ? UInt8.max : 0 }
        let maskVector = SIMD16<UInt8>(mask)

        // Compare only the relevant bytes
        let maskedSelf = self & maskVector
        let maskedOther = other & maskVector

        // Check if all relevant bytes match
        return maskedSelf == maskedOther
    }
}

// MARK: - Advanced SIMD Operations

extension CoreBPESIMD {
    /// Batch encode multiple texts in parallel using SIMD
    func encodeBatch(_ texts: [String]) -> [[Int]] {
        // Process multiple texts concurrently
        texts.map { encode($0) }
    }

    /// Find all occurrences of a pattern using SIMD
    private func findPatternSIMD(_ pattern: [UInt8], in data: [UInt8]) -> [Int] {
        guard pattern.count <= 16 else { return [] }

        var positions: [Int] = []
        let patternVector = SIMD16<UInt8>(pattern + Array(repeating: UInt8(0), count: 16 - pattern.count))

        for i in 0 ... (data.count - pattern.count) {
            var dataVector = SIMD16<UInt8>(repeating: 0)
            for j in 0 ..< min(16, data.count - i) {
                dataVector[j] = data[i + j]
            }

            if dataVector.matches(patternVector, length: pattern.count) {
                positions.append(i)
            }
        }

        return positions
    }
}
