import Foundation

public final class Tiktoken {
    private let coreBPE: CoreBPE
    private let encoding: Encoding

    public init(encoding: Encoding) throws {
        self.encoding = encoding

        // Load the vocabulary file for the encoding
        guard let vocabURL = Bundle.main.url(forResource: encoding.rawValue, withExtension: "tiktoken") else {
            throw TiktokenError.encodingNotFound(encoding.rawValue)
        }

        let vocabData = try Data(contentsOf: vocabURL)
        let (bytePairRanks, specialTokens) = try FileDecoder.decode(data: vocabData)

        // Pattern for tokenization (simplified for now)
        let pattern = "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+"

        self.coreBPE = try CoreBPE(bytePairRanks: bytePairRanks,
                                   specialTokens: specialTokens,
                                   pattern: pattern)
    }

    public func encode(_ text: String) -> [Int] {
        coreBPE.encode(text)
    }

    public func decode(_ tokens: [Int]) -> String {
        coreBPE.decode(tokens)
    }

    public func countTokens(in text: String) -> Int {
        encode(text).count
    }
}

public enum TiktokenError: LocalizedError {
    case encodingNotFound(String)
    case invalidVocabularyFormat

    public var errorDescription: String? {
        switch self {
        case let .encodingNotFound(encoding):
            "Encoding file not found: \(encoding).tiktoken"
        case .invalidVocabularyFormat:
            "Invalid vocabulary file format"
        }
    }
}
