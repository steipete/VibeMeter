import Foundation
import CryptoKit
import os

/// Validates tiktoken vocabulary files for integrity and correctness
final class VocabularyValidator {
    private let logger = Logger(subsystem: "com.steipete.VibeMeter", category: "VocabularyValidator")
    
    struct ValidationResult {
        let isValid: Bool
        let checksum: String
        let tokenCount: Int
        let errors: [ValidationError]
        let warnings: [ValidationWarning]
        
        var summary: String {
            if isValid {
                return "✅ Vocabulary valid: \(tokenCount) tokens, checksum: \(checksum.prefix(8))..."
            } else {
                return "❌ Vocabulary invalid: \(errors.count) errors, \(warnings.count) warnings"
            }
        }
    }
    
    enum ValidationError: Error {
        case fileNotFound(String)
        case invalidFormat(String)
        case duplicateToken(token: String, ids: [Int])
        case duplicateRank(rank: Int, tokens: [String])
        case missingRequiredTokens([String])
        case checksumMismatch(expected: String, actual: String)
        case corruptedData(String)
        
        var description: String {
            switch self {
            case .fileNotFound(let path):
                return "File not found: \(path)"
            case .invalidFormat(let message):
                return "Invalid format: \(message)"
            case .duplicateToken(let token, let ids):
                return "Duplicate token '\(token)' with IDs: \(ids)"
            case .duplicateRank(let rank, let tokens):
                return "Duplicate rank \(rank) for tokens: \(tokens)"
            case .missingRequiredTokens(let tokens):
                return "Missing required tokens: \(tokens.joined(separator: ", "))"
            case .checksumMismatch(let expected, let actual):
                return "Checksum mismatch - expected: \(expected), actual: \(actual)"
            case .corruptedData(let message):
                return "Corrupted data: \(message)"
            }
        }
    }
    
    enum ValidationWarning {
        case unusualTokenLength(token: String, length: Int)
        case gapInRanks(start: Int, end: Int)
        case unusualSpecialToken(token: String)
        case performanceImpact(String)
        
        var description: String {
            switch self {
            case .unusualTokenLength(let token, let length):
                return "Unusual token length (\(length) bytes): '\(token)'"
            case .gapInRanks(let start, let end):
                return "Gap in ranks from \(start) to \(end)"
            case .unusualSpecialToken(let token):
                return "Unusual special token: '\(token)'"
            case .performanceImpact(let message):
                return "Performance impact: \(message)"
            }
        }
    }
    
    /// Validate a vocabulary file
    func validate(vocabularyURL: URL, expectedChecksum: String? = nil) async -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Check file exists
        guard FileManager.default.fileExists(atPath: vocabularyURL.path) else {
            errors.append(.fileNotFound(vocabularyURL.path))
            return ValidationResult(
                isValid: false,
                checksum: "",
                tokenCount: 0,
                errors: errors,
                warnings: warnings
            )
        }
        
        do {
            // Load and decode vocabulary
            let data = try Data(contentsOf: vocabularyURL)
            let checksum = computeChecksum(data)
            
            // Verify checksum if provided
            if let expected = expectedChecksum, checksum != expected {
                errors.append(.checksumMismatch(expected: expected, actual: checksum))
            }
            
            // Decode vocabulary
            let (bytePairRanks, specialTokens) = try FileDecoder.decode(data: data)
            
            // Validate structure
            validateStructure(
                bytePairRanks: bytePairRanks,
                specialTokens: specialTokens,
                errors: &errors,
                warnings: &warnings
            )
            
            // Check for required tokens
            validateRequiredTokens(
                bytePairRanks: bytePairRanks,
                errors: &errors
            )
            
            // Check for performance issues
            validatePerformance(
                bytePairRanks: bytePairRanks,
                warnings: &warnings
            )
            
            let tokenCount = bytePairRanks.count + specialTokens.count
            
            return ValidationResult(
                isValid: errors.isEmpty,
                checksum: checksum,
                tokenCount: tokenCount,
                errors: errors,
                warnings: warnings
            )
            
        } catch {
            errors.append(.corruptedData(error.localizedDescription))
            return ValidationResult(
                isValid: false,
                checksum: "",
                tokenCount: 0,
                errors: errors,
                warnings: warnings
            )
        }
    }
    
    /// Compute SHA256 checksum of vocabulary data
    private func computeChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Validate vocabulary structure
    private func validateStructure(
        bytePairRanks: [Data: Int],
        specialTokens: [String: Int],
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        // Check for duplicate ranks
        var rankToTokens: [Int: [String]] = [:]
        for (data, rank) in bytePairRanks {
            let token = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
            rankToTokens[rank, default: []].append(token)
        }
        
        for (rank, tokens) in rankToTokens where tokens.count > 1 {
            errors.append(.duplicateRank(rank: rank, tokens: tokens))
        }
        
        // Check for gaps in ranks
        let sortedRanks = bytePairRanks.values.sorted()
        for i in 1..<sortedRanks.count {
            if sortedRanks[i] - sortedRanks[i-1] > 1000 {
                warnings.append(.gapInRanks(start: sortedRanks[i-1], end: sortedRanks[i]))
            }
        }
        
        // Check token lengths
        for (data, _) in bytePairRanks {
            if data.count > 50 {
                let token = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
                warnings.append(.unusualTokenLength(token: token, length: data.count))
            }
        }
        
        // Check special tokens
        for token in specialTokens.keys {
            if !token.hasPrefix("<|") || !token.hasSuffix("|>") {
                warnings.append(.unusualSpecialToken(token: token))
            }
        }
    }
    
    /// Validate required tokens are present
    private func validateRequiredTokens(
        bytePairRanks: [Data: Int],
        errors: inout [ValidationError]
    ) {
        // All single bytes should be present
        var missingBytes: [String] = []
        for byte in 0..<256 {
            let data = Data([UInt8(byte)])
            if bytePairRanks[data] == nil {
                missingBytes.append("0x\(String(format: "%02X", byte))")
            }
        }
        
        if !missingBytes.isEmpty {
            errors.append(.missingRequiredTokens(missingBytes))
        }
    }
    
    /// Check for performance issues
    private func validatePerformance(
        bytePairRanks: [Data: Int],
        warnings: inout [ValidationWarning]
    ) {
        // Large vocabulary warning
        if bytePairRanks.count > 500_000 {
            warnings.append(.performanceImpact("Large vocabulary (\(bytePairRanks.count) tokens) may impact performance"))
        }
        
        // Many long tokens warning
        let longTokens = bytePairRanks.filter { $0.key.count > 20 }
        if longTokens.count > 10_000 {
            warnings.append(.performanceImpact("\(longTokens.count) tokens longer than 20 bytes may slow encoding"))
        }
    }
    
    /// Generate vocabulary statistics
    func generateStatistics(vocabularyURL: URL) async -> VocabularyStatistics? {
        do {
            let data = try Data(contentsOf: vocabularyURL)
            let (bytePairRanks, specialTokens) = try FileDecoder.decode(data: data)
            
            return VocabularyStatistics(
                bytePairRanks: bytePairRanks,
                specialTokens: specialTokens
            )
        } catch {
            logger.error("Failed to generate statistics: \(error)")
            return nil
        }
    }
}

/// Vocabulary statistics for analysis
struct VocabularyStatistics {
    let totalTokens: Int
    let specialTokenCount: Int
    let bytePairCount: Int
    let averageTokenLength: Double
    let maxTokenLength: Int
    let minTokenLength: Int
    let sizeDistribution: [Int: Int] // length -> count
    let rankDistribution: [Int: Int] // rank range -> count
    
    init(bytePairRanks: [Data: Int], specialTokens: [String: Int]) {
        self.totalTokens = bytePairRanks.count + specialTokens.count
        self.specialTokenCount = specialTokens.count
        self.bytePairCount = bytePairRanks.count
        
        // Calculate token length statistics
        let lengths = bytePairRanks.keys.map { $0.count }
        self.averageTokenLength = lengths.isEmpty ? 0 : Double(lengths.reduce(0, +)) / Double(lengths.count)
        self.maxTokenLength = lengths.max() ?? 0
        self.minTokenLength = lengths.min() ?? 0
        
        // Size distribution
        var sizeDist: [Int: Int] = [:]
        for length in lengths {
            sizeDist[length, default: 0] += 1
        }
        self.sizeDistribution = sizeDist
        
        // Rank distribution (in buckets of 10k)
        var rankDist: [Int: Int] = [:]
        for rank in bytePairRanks.values {
            let bucket = rank / 10_000
            rankDist[bucket, default: 0] += 1
        }
        self.rankDistribution = rankDist
    }
    
    var summary: String {
        """
        Vocabulary Statistics:
        - Total tokens: \(totalTokens)
        - Special tokens: \(specialTokenCount)
        - Byte pair tokens: \(bytePairCount)
        - Average token length: \(String(format: "%.2f", averageTokenLength)) bytes
        - Token length range: \(minTokenLength)-\(maxTokenLength) bytes
        - Most common lengths: \(topLengths(3))
        """
    }
    
    private func topLengths(_ count: Int) -> String {
        let sorted = sizeDistribution.sorted { $0.value > $1.value }
        let top = sorted.prefix(count)
        return top.map { "\($0.key) bytes: \($0.value) tokens" }.joined(separator: ", ")
    }
}

// MARK: - Vocabulary Repair

extension VocabularyValidator {
    /// Attempt to repair common vocabulary issues
    func repair(vocabularyURL: URL, outputURL: URL) async -> (success: Bool, changes: [String]) {
        var changes: [String] = []
        
        do {
            let data = try Data(contentsOf: vocabularyURL)
            var (bytePairRanks, _) = try FileDecoder.decode(data: data)
            
            // Add missing single bytes
            for byte in 0..<256 {
                let data = Data([UInt8(byte)])
                if bytePairRanks[data] == nil {
                    bytePairRanks[data] = byte
                    changes.append("Added missing byte: 0x\(String(format: "%02X", byte))")
                }
            }
            
            // Remove duplicates (keep lowest rank)
            var seenRanks: Set<Int> = []
            var toRemove: [Data] = []
            for (data, rank) in bytePairRanks.sorted(by: { $0.value < $1.value }) {
                if seenRanks.contains(rank) {
                    toRemove.append(data)
                    changes.append("Removed duplicate rank \(rank)")
                } else {
                    seenRanks.insert(rank)
                }
            }
            
            for data in toRemove {
                bytePairRanks.removeValue(forKey: data)
            }
            
            // TODO: Encode repaired vocabulary back to file
            // This would require implementing an encoder for the tiktoken format
            
            return (true, changes)
            
        } catch {
            logger.error("Failed to repair vocabulary: \(error)")
            return (false, ["Failed: \(error.localizedDescription)"])
        }
    }
}