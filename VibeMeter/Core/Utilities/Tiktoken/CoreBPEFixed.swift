import Foundation

/// Corrected Byte Pair Encoding implementation based on tiktoken
final class CoreBPEFixed {
    private let bytePairRanks: [Data: Int]
    private let tokenEncoder: [String: Int]
    private let tokenDecoder: [Int: String]
    private let specialTokens: [String: Int]
    private let regex: NSRegularExpression

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
                let pieceTokens = bytePairEncodingCorrect(piece.data(using: .utf8)!)
                tokens.append(contentsOf: pieceTokens)
            }
        }

        return tokens
    }

    /// Correct BPE implementation following tiktoken's algorithm
    private func bytePairEncodingCorrect(_ data: Data) -> [Int] {
        // Start with individual bytes
        var parts: [Data] = data.map { Data([$0]) }

        // Keep merging until no more merges are possible
        while parts.count > 1 {
            // Find the pair with the minimum rank
            var minRank: Int?
            var minIndex: Int?

            for i in 0 ..< (parts.count - 1) {
                let pair = parts[i] + parts[i + 1]
                if let rank = bytePairRanks[pair] {
                    if minRank == nil || rank < minRank! {
                        minRank = rank
                        minIndex = i
                    }
                }
            }

            // If no mergeable pair found, we're done
            guard let idx = minIndex else { break }

            // Merge the pair
            let merged = parts[idx] + parts[idx + 1]
            parts = Array(parts[0 ..< idx]) + [merged] + Array(parts[(idx + 2)...])
        }

        // Convert parts to tokens
        var result: [Int] = []
        for part in parts {
            if let rank = bytePairRanks[part] {
                result.append(rank)
            } else {
                // This shouldn't happen if vocabulary is complete
                // Fallback to individual bytes
                for byte in part {
                    if let rank = bytePairRanks[Data([byte])] {
                        result.append(rank)
                    }
                }
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

// MARK: - Performance Optimizations

extension CoreBPEFixed {
    /// Optimized version with caching for common sequences
    private struct Cache {
        static let shared = Cache()
        private var cache = NSCache<NSData, NSArray>()

        func get(_ data: Data) -> [Int]? {
            cache.object(forKey: data as NSData) as? [Int]
        }

        func set(_ data: Data, tokens: [Int]) {
            cache.setObject(tokens as NSArray, forKey: data as NSData)
        }
    }

    /// Cached version of BPE encoding
    private func bytePairEncodingCached(_ data: Data) -> [Int] {
        // Check cache first
        if let cached = Cache.shared.get(data) {
            return cached
        }

        // Compute and cache
        let result = bytePairEncodingCorrect(data)
        Cache.shared.set(data, tokens: result)
        return result
    }

    /// Batch encoding with concurrent processing
    func encodeBatch(_ texts: [String], maxConcurrency _: Int = 8) async -> [[Int]] {
        await withTaskGroup(of: (Int, [Int]).self) { group in
            for (index, text) in texts.enumerated() {
                group.addTask { [self] in
                    return (index, self.encode(text))
                }
            }

            var results = [[Int]?](repeating: nil, count: texts.count)
            for await (index, tokens) in group {
                results[index] = tokens
            }

            return results.compactMap(\.self)
        }
    }
}
