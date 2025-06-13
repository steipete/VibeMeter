import Foundation
import os

/// Benchmarking utilities for tokenization performance
final class TokenizationBenchmark {
    private let logger = Logger(subsystem: "com.steipete.VibeMeter", category: "TokenizationBenchmark")

    struct BenchmarkResult {
        let textSize: Int
        let tokenCount: Int
        let duration: TimeInterval
        let tokensPerSecond: Double
        let bytesPerSecond: Double
    }

    /// Benchmark tokenization performance
    func benchmark(tokenizer: CoreBPE, texts: [String]) -> [BenchmarkResult] {
        var results: [BenchmarkResult] = []

        for text in texts {
            let startTime = CFAbsoluteTimeGetCurrent()
            let tokens = tokenizer.encode(text)
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            let bytesPerSecond = Double(text.utf8.count) / duration
            let tokensPerSecond = Double(tokens.count) / duration

            let result = BenchmarkResult(
                textSize: text.utf8.count,
                tokenCount: tokens.count,
                duration: duration,
                tokensPerSecond: tokensPerSecond,
                bytesPerSecond: bytesPerSecond)

            results.append(result)

            logger.info("""
            Tokenized \(text.utf8.count) bytes -> \(tokens.count) tokens in \(duration * 1000)ms
            (\(Int(bytesPerSecond)) bytes/s, \(Int(tokensPerSecond)) tokens/s)
            """)
        }

        return results
    }

    /// Compare different tokenizer implementations
    func compare(tokenizers: [(name: String, tokenizer: CoreBPE)], text: String) {
        logger.info("Comparing tokenizers with \(text.utf8.count) bytes of text")

        for (name, tokenizer) in tokenizers {
            let startTime = CFAbsoluteTimeGetCurrent()
            let tokens = tokenizer.encode(text)
            let duration = CFAbsoluteTimeGetCurrent() - startTime

            logger.info("\(name): \(tokens.count) tokens in \(duration * 1000)ms")
        }
    }

    /// Generate test texts of various sizes
    static func generateTestTexts() -> [String] {
        let baseText = """
        The quick brown fox jumps over the lazy dog. This is a test of the tokenization system.
        It includes various types of text: numbers like 123456, punctuation (!@#$%^&*), and
        special characters. We also have some longer words like 'internationalization' and
        'pneumonoultramicroscopicsilicovolcanoconiosis'.
        """

        return [
            baseText, // ~300 bytes
            String(repeating: baseText, count: 10), // ~3KB
            String(repeating: baseText, count: 100), // ~30KB
            String(repeating: baseText, count: 1000), // ~300KB
            String(repeating: baseText, count: 10000), // ~3MB
        ]
    }
}

// MARK: - Memory Profiling

extension TokenizationBenchmark {
    /// Profile memory usage during tokenization
    func profileMemory(tokenizer: CoreBPE, text: String) {
        _ = mach_task_basic_info()
        _ = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let startMemory = getMemoryUsage()
        _ = tokenizer.encode(text)
        let endMemory = getMemoryUsage()

        let memoryDelta = endMemory - startMemory
        logger.info("Memory usage: +\(memoryDelta / 1024 / 1024)MB for \(text.utf8.count / 1024 / 1024)MB text")
    }

    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                          task_flavor_t(MACH_TASK_BASIC_INFO),
                          $0,
                          &count)
            }
        }

        return result == KERN_SUCCESS ? Int64(info.resident_size) : 0
    }
}
