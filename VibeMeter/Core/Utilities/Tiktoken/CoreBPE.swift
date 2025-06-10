import Foundation

/// Core Byte Pair Encoding implementation
final class CoreBPE {
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
                let pieceTokens = bytePairEncoding(piece.data(using: .utf8)!)
                tokens.append(contentsOf: pieceTokens)
            }
        }

        return tokens
    }

    private func bytePairEncoding(_ data: Data) -> [Int] {
        // Simple BPE implementation
        if data.count == 1 {
            if let rank = bytePairRanks[data] {
                return [rank]
            }
            return []
        }

        // For simplicity, we'll use a basic implementation
        // In production, this would be optimized
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
