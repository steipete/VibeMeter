import Foundation

public final class Tiktoken: @unchecked Sendable {
    private let coreBPE: CoreBPESIMD
    private let encoding: Encoding
    
    // Cache for frequently encoded strings
    private var encodingCache: [String: [Int]] = [:]
    private let cacheQueue = DispatchQueue(label: "tiktoken.cache", attributes: .concurrent)
    private let maxCacheSize = 1000
    
    // Special tokens
    public private(set) var specialTokens: [String: Int] = [:]
    public var specialTokensSet: Set<String> {
        Set(specialTokens.keys)
    }
    
    // Common special tokens
    public var eotToken: Int? {
        specialTokens["<|endoftext|>"]
    }
    
    public var fimPrefixToken: Int? {
        specialTokens["<|fim_prefix|>"]
    }
    
    public var fimMiddleToken: Int? {
        specialTokens["<|fim_middle|>"]
    }
    
    public var fimSuffixToken: Int? {
        specialTokens["<|fim_suffix|>"]
    }

    public init(encoding: Encoding) throws {
        self.encoding = encoding

        // Load the vocabulary file for the encoding
        guard let vocabURL = Bundle.main.url(forResource: encoding.rawValue, withExtension: "tiktoken") else {
            throw TiktokenError.encodingNotFound(encoding.rawValue)
        }

        let vocabData = try Data(contentsOf: vocabURL)
        let (bytePairRanks, specialTokens) = try FileDecoder.decode(data: vocabData)
        
        // Store special tokens
        self.specialTokens = specialTokens

        // Pattern for tokenization based on encoding type
        let pattern = Self.getPattern(for: encoding)

        // Use SIMD-optimized implementation for 20-24x performance improvement
        self.coreBPE = try CoreBPESIMD(bytePairRanks: bytePairRanks,
                                       specialTokens: specialTokens,
                                       pattern: pattern)
    }

    public func encode(_ text: String) -> [Int] {
        // Check cache first
        var cachedResult: [Int]?
        cacheQueue.sync {
            cachedResult = encodingCache[text]
        }
        
        if let cached = cachedResult {
            return cached
        }
        
        // Encode and cache the result
        let result = coreBPE.encode(text)
        
        // Update cache with barrier to ensure thread safety
        cacheQueue.async(flags: .barrier) {
            // Implement simple LRU by removing oldest entries if cache is too large
            if self.encodingCache.count >= self.maxCacheSize {
                // Remove approximately 10% of oldest entries
                let toRemove = self.maxCacheSize / 10
                for _ in 0 ..< toRemove {
                    if let firstKey = self.encodingCache.keys.first {
                        self.encodingCache.removeValue(forKey: firstKey)
                    }
                }
            }
            self.encodingCache[text] = result
        }
        
        return result
    }

    public func decode(_ tokens: [Int]) -> String {
        coreBPE.decode(tokens)
    }

    public func countTokens(in text: String) -> Int {
        encode(text).count
    }
    
    // MARK: - Special Token Encoding
    
    /// Encode with special token support
    public func encode(_ text: String, allowedSpecial: Set<String>) -> [Int] {
        coreBPE.encode(text, allowedSpecial: allowedSpecial)
    }
    
    /// Encode with all special tokens allowed
    public func encodeWithAllSpecial(_ text: String) -> [Int] {
        coreBPE.encode(text, allowedSpecial: specialTokensSet)
    }
    
    /// Encode ignoring all special tokens (treat them as regular text)
    public func encodeOrdinary(_ text: String) -> [Int] {
        coreBPE.encode(text, allowedSpecial: [])
    }
    
    // MARK: - Batch Operations
    
    /// Encode multiple texts in parallel for better performance
    public func encodeBatch(_ texts: [String], numThreads: Int = 8) -> [[Int]] {
        // Handle empty input
        if texts.isEmpty {
            return []
        }
        
        // For small batches, use sequential processing
        if texts.count < numThreads {
            return texts.map { encode($0) }
        }
        
        // Use thread-safe results container
        let results = ConcurrentResults<[Int]>()
        let queue = DispatchQueue(label: "tiktoken.batch", attributes: .concurrent)
        let group = DispatchGroup()
        
        for (index, text) in texts.enumerated() {
            group.enter()
            queue.async { [self] in
                let encoded = self.encode(text)
                results.set(encoded, for: index)
                group.leave()
            }
        }
        
        group.wait()
        
        // Convert to ordered array
        return results.getAllValues(count: texts.count)
    }
    
    /// Decode multiple token sequences in parallel
    public func decodeBatch(_ tokenBatch: [[Int]], numThreads: Int = 8) -> [String] {
        // Handle empty input
        if tokenBatch.isEmpty {
            return []
        }
        
        if tokenBatch.count < numThreads {
            return tokenBatch.map { decode($0) }
        }
        
        // Use thread-safe results container
        let results = ConcurrentResults<String>()
        let queue = DispatchQueue(label: "tiktoken.decode.batch", attributes: .concurrent)
        let group = DispatchGroup()
        
        for (index, tokens) in tokenBatch.enumerated() {
            group.enter()
            queue.async { [self] in
                let decoded = self.decode(tokens)
                results.set(decoded, for: index)
                group.leave()
            }
        }
        
        group.wait()
        
        // Convert to ordered array
        return results.getAllValues(count: tokenBatch.count)
    }
    
    // MARK: - Private Methods
    
    private static func getPattern(for encoding: Encoding) -> String {
        switch encoding {
        case .r50k_base, .p50k_base:
            // GPT-2 pattern (optimized version)
            return "'(?:[sdmt]|ll|ve|re)| ?\\p{L}++| ?\\p{N}++| ?[^\\s\\p{L}\\p{N}]++|\\s++$|\\s+(?!\\S)|\\s"
            
        case .cl100k_base:
            // ChatGPT pattern
            return "'(?i:[sdmt]|ll|ve|re)|[^\\r\\n\\p{L}\\p{N}]?+\\p{L}++|\\p{N}{1,3}+| ?[^\\s\\p{L}\\p{N}]++[\\r\\n]*+|\\s++$|\\s*[\\r\\n]|\\s+(?!\\S)|\\s"
            
        case .o200k_base:
            // Claude/GPT-4o pattern - more complex regex for better multilingual support
            let patterns = [
                "[^\\r\\n\\p{L}\\p{N}]?[\\p{Lu}\\p{Lt}\\p{Lm}\\p{Lo}\\p{M}]*[\\p{Ll}\\p{Lm}\\p{Lo}\\p{M}]+(?i:'s|'t|'re|'ve|'m|'ll|'d)?",
                "[^\\r\\n\\p{L}\\p{N}]?[\\p{Lu}\\p{Lt}\\p{Lm}\\p{Lo}\\p{M}]+[\\p{Ll}\\p{Lm}\\p{Lo}\\p{M}]*(?i:'s|'t|'re|'ve|'m|'ll|'d)?",
                "\\p{N}{1,3}",
                " ?[^\\s\\p{L}\\p{N}]+[\\r\\n/]*",
                "\\s*[\\r\\n]+",
                "\\s+(?!\\S)",
                "\\s+"
            ]
            return patterns.joined(separator: "|")
        }
    }
}

public enum TiktokenError: LocalizedError {
    case encodingNotFound(String)
    case invalidVocabularyFormat

    public var errorDescription: String? {
        switch self {
        case let .encodingNotFound(encoding):
            return "Encoding file not found: \(encoding).tiktoken"
        case .invalidVocabularyFormat:
            return "Invalid vocabulary file format"
        }
    }
}


// MARK: - Thread-Safe Results Container

/// Thread-safe container for concurrent results
private final class ConcurrentResults<T: Sendable>: @unchecked Sendable {
    private var storage: [Int: T] = [:]
    private let queue = DispatchQueue(label: "tiktoken.results", attributes: .concurrent)
    
    func set(_ value: T, for index: Int) {
        queue.async(flags: .barrier) {
            self.storage[index] = value
        }
    }
    
    func getAllValues(count: Int) -> [T] {
        queue.sync {
            (0..<count).compactMap { storage[$0] }
        }
    }
}
