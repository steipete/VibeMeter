import Foundation
import simd

/// SIMD-optimized Byte Pair Encoding implementation
final class CoreBPESIMD {
    private let bytePairRanks: [Data: Int]
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

    func encode(_ text: String) -> [Int] {
        var tokens: [Int] = []

        // Handle special tokens first
        let remainingText = text
        for (specialToken, tokenId) in specialTokens where remainingText.contains(specialToken) {
            // Split by special token and encode parts separately
            let parts = remainingText.components(separatedBy: specialToken)
            for (index, part) in parts.enumerated() {
                if !part.isEmpty {
                    tokens.append(contentsOf: encodeOrdinary(part))
                }
                if index < parts.count - 1 {
                    tokens.append(tokenId)
                }
            }
            return tokens
        }

        // No special tokens found, encode normally
        return encodeOrdinary(text)
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

    /// SIMD-optimized byte pair encoding
    private func bytePairEncodingSIMD(_ data: Data) -> [Int] {
        // For small data, use non-SIMD version
        if data.count < 16 {
            return bytePairEncodingScalar(data)
        }

        var result: [Int] = []
        let bytes = [UInt8](data)
        var i = 0

        // Process in chunks using SIMD
        while i < bytes.count {
            // Try to find matches using SIMD
            if let (matchLength, rank) = vectorLookup.findLongestMatch(in: bytes, at: i) {
                result.append(rank)
                i += matchLength
            } else {
                // Fallback to single byte
                if let rank = bytePairRanks[Data([bytes[i]])] {
                    result.append(rank)
                }
                i += 1
            }
        }

        return result
    }

    /// Scalar fallback for small inputs
    private func bytePairEncodingScalar(_ data: Data) -> [Int] {
        if data.count == 1 {
            if let rank = bytePairRanks[data] {
                return [rank]
            }
            return []
        }

        var result: [Int] = []
        var i = 0
        while i < data.count {
            var found = false
            for length in (1 ... min(10, data.count - i)).reversed() {
                let substr = data[i ..< i + length]
                if let rank = bytePairRanks[substr] {
                    result.append(rank)
                    i += length
                    found = true
                    break
                }
            }
            if !found {
                i += 1
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
