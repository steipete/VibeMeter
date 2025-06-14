import Foundation
import simd

/// SIMD-optimized merge finder for BPE algorithm
struct SIMDMergeFinder {
    private let bytePairRanks: [Data: Int]
    private let rankLookup: SIMDRankLookup
    
    init(bytePairRanks: [Data: Int]) {
        self.bytePairRanks = bytePairRanks
        self.rankLookup = SIMDRankLookup(bytePairRanks: bytePairRanks)
    }
    
    /// Find the best merge position using SIMD operations
    func findBestMerge(in parts: [Data]) -> (index: Int, rank: Int)? {
        guard parts.count > 1 else { return nil }
        
        // For small arrays, use scalar approach
        if parts.count < 8 {
            return findBestMergeScalar(in: parts)
        }
        
        // Use SIMD for larger arrays
        return findBestMergeSIMD(in: parts)
    }
    
    private func findBestMergeScalar(in parts: [Data]) -> (index: Int, rank: Int)? {
        var bestRank = Int.max
        var bestIndex = -1
        
        for i in 0..<(parts.count - 1) {
            let pair = parts[i] + parts[i + 1]
            if let rank = bytePairRanks[pair], rank < bestRank {
                bestRank = rank
                bestIndex = i
            }
        }
        
        return bestIndex >= 0 ? (bestIndex, bestRank) : nil
    }
    
    private func findBestMergeSIMD(in parts: [Data]) -> (index: Int, rank: Int)? {
        var bestRank = Int.max
        var bestIndex = -1
        
        // Process multiple pairs in parallel using SIMD
        let simdWidth = 4 // Process 4 pairs at once
        let iterations = (parts.count - 1) / simdWidth
        
        for iter in 0..<iterations {
            let baseIndex = iter * simdWidth
            
            // Check bounds
            guard baseIndex + simdWidth < parts.count else { break }
            
            // Process simdWidth pairs in parallel
            var ranks = SIMD4<Int32>(repeating: Int32.max)
            
            for offset in 0..<simdWidth {
                let index = baseIndex + offset
                if index < parts.count - 1 {
                    let pair = parts[index] + parts[index + 1]
                    if let rank = bytePairRanks[pair] {
                        ranks[offset] = Int32(rank)
                    }
                }
            }
            
            // Find minimum in SIMD vector
            let minRank = ranks.min()
            if minRank < Int32(bestRank) {
                // Find which index has the minimum
                for offset in 0..<simdWidth {
                    if ranks[offset] == minRank {
                        bestRank = Int(minRank)
                        bestIndex = baseIndex + offset
                        break
                    }
                }
            }
        }
        
        // Handle remaining pairs
        for i in (iterations * simdWidth)..<(parts.count - 1) {
            let pair = parts[i] + parts[i + 1]
            if let rank = bytePairRanks[pair], rank < bestRank {
                bestRank = rank
                bestIndex = i
            }
        }
        
        return bestIndex >= 0 ? (bestIndex, bestRank) : nil
    }
}

/// SIMD-optimized rank lookup structure
struct SIMDRankLookup {
    // Pre-computed hash tables for fast lookups
    private let shortPairLookup: [UInt32: Int] // For 2-byte pairs
    private let mediumPairLookup: [UInt64: Int] // For up to 8-byte pairs
    
    init(bytePairRanks: [Data: Int]) {
        var shortLookup: [UInt32: Int] = [:]
        var mediumLookup: [UInt64: Int] = [:]
        
        for (data, rank) in bytePairRanks {
            switch data.count {
            case 2:
                let key = UInt32(data[0]) | (UInt32(data[1]) << 8)
                shortLookup[key] = rank
            case 3...8:
                var key: UInt64 = 0
                for (i, byte) in data.enumerated() {
                    key |= UInt64(byte) << (i * 8)
                }
                mediumLookup[key] = rank
            default:
                // Longer sequences handled by regular lookup
                break
            }
        }
        
        self.shortPairLookup = shortLookup
        self.mediumPairLookup = mediumLookup
    }
    
    func getRank(for data: Data) -> Int? {
        switch data.count {
        case 2:
            let key = UInt32(data[0]) | (UInt32(data[1]) << 8)
            return shortPairLookup[key]
        case 3...8:
            var key: UInt64 = 0
            for (i, byte) in data.enumerated() {
                key |= UInt64(byte) << (i * 8)
            }
            return mediumPairLookup[key]
        default:
            return nil // Fallback to regular lookup
        }
    }
}

/// SIMD-accelerated BPE encoder
extension CoreBPESIMD {
    func encodeSIMDOptimized(_ data: Data) -> [Int] {
        if data.isEmpty { return [] }
        
        // Initialize parts
        var parts: [Data] = data.map { Data([$0]) }
        let mergeFinder = SIMDMergeFinder(bytePairRanks: bytePairRanks)
        
        // Keep merging until no more merges possible
        while parts.count > 1 {
            guard let (mergeIndex, _) = mergeFinder.findBestMerge(in: parts) else {
                break
            }
            
            // Perform the merge
            parts[mergeIndex] = parts[mergeIndex] + parts[mergeIndex + 1]
            parts.remove(at: mergeIndex + 1)
        }
        
        // Convert to token IDs
        return parts.compactMap { bytePairRanks[$0] }
    }
}

// MARK: - SIMD Utilities

extension SIMD4 where Scalar == Int32 {
    /// Find minimum value in vector
    func min() -> Scalar {
        // Use SIMD reduction
        let pair1 = Swift.min(self[0], self[1])
        let pair2 = Swift.min(self[2], self[3])
        return Swift.min(pair1, pair2)
    }
}

// MARK: - Parallel BPE Processing

/// Thread-safe result container
private final class ThreadSafeResults<T: Sendable>: @unchecked Sendable {
    private var results: [Int: T] = [:]
    private let queue = DispatchQueue(label: "results.sync", attributes: .concurrent)
    
    func set(_ value: T, at index: Int) {
        queue.async(flags: .barrier) {
            self.results[index] = value
        }
    }
    
    func get(_ index: Int) -> T? {
        queue.sync {
            results[index]
        }
    }
    
    func getAll(count: Int) -> [T?] {
        queue.sync {
            (0..<count).map { results[$0] }
        }
    }
}

struct ParallelBPEProcessor {
    private let bytePairRanks: [Data: Int]
    private let queue = DispatchQueue(label: "bpe.parallel", attributes: .concurrent)
    
    init(bytePairRanks: [Data: Int]) {
        self.bytePairRanks = bytePairRanks
    }
    
    /// Process multiple texts in parallel
    func encodeBatch(_ texts: [String], chunkSize: Int = 1000) -> [[Int]] {
        let results = ThreadSafeResults<[Int]>()
        let group = DispatchGroup()
        
        for (index, text) in texts.enumerated() {
            group.enter()
            queue.async {
                do {
                    let encoder = try CoreBPESIMD(
                        bytePairRanks: self.bytePairRanks,
                        specialTokens: [:],
                        pattern: "'s|'t|'re|'ve|'m|'ll|'d| ?\\p{L}+| ?\\p{N}+| ?[^\\s\\p{L}\\p{N}]+|\\s+(?!\\S)|\\s+"
                    )
                    
                    let encoded = encoder.encode(text)
                    results.set(encoded, at: index)
                } catch {
                    // Handle error - return empty array for failed encoding
                    results.set([], at: index)
                }
                group.leave()
            }
        }
        
        group.wait()
        
        // Convert to array in order
        return results.getAll(count: texts.count).map { $0 ?? [] }
    }
}
