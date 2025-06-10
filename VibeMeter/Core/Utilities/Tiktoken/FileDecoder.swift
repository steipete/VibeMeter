import Foundation

enum FileDecoder {
    static func decode(data: Data) throws -> (bytePairRanks: [Data: Int], specialTokens: [String: Int]) {
        guard let content = String(data: data, encoding: .utf8) else {
            throw TiktokenError.invalidVocabularyFormat
        }

        var bytePairRanks: [Data: Int] = [:]
        var specialTokens: [String: Int] = [:]

        let lines = content.split(separator: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 1)
            guard parts.count == 2,
                  let rank = Int(parts[1]) else {
                continue
            }

            let tokenString = String(parts[0])

            // Check if it's a special token (enclosed in angle brackets)
            if tokenString.hasPrefix("<"), tokenString.hasSuffix(">") {
                specialTokens[tokenString] = rank
            } else {
                // Decode base64 token to bytes
                if let tokenData = Data(base64Encoded: tokenString) {
                    bytePairRanks[tokenData] = rank
                }
            }
        }

        return (bytePairRanks, specialTokens)
    }
}
