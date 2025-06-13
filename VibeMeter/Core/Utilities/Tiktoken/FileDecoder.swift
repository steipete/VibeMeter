import Foundation

/// Decodes tiktoken vocabulary files
enum FileDecoder {
    static func decode(data: Data) throws -> (bytePairRanks: [Data: Int], specialTokens: [String: Int]) {
        guard let content = String(data: data, encoding: .utf8) else {
            throw TiktokenError.invalidVocabularyFormat
        }

        var bytePairRanks: [Data: Int] = [:]
        var specialTokens: [String: Int] = [:]

        // Parse line by line
        let lines = content.split(separator: "\n")

        for line in lines {
            let parts = line.split(separator: " ", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let tokenStr = String(parts[0])
            guard let rank = Int(String(parts[1])) else { continue }

            if tokenStr.hasPrefix("<|"), tokenStr.hasSuffix("|>") {
                // Special token
                specialTokens[tokenStr] = rank
            } else {
                // Regular token - decode base64
                if let tokenData = Data(base64Encoded: tokenStr) {
                    bytePairRanks[tokenData] = rank
                }
            }
        }

        return (bytePairRanks, specialTokens)
    }
}
