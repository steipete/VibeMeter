import XCTest
@testable import VibeMeter

final class ClaudeLogParsingPerformanceTests: XCTestCase {
    
    // MARK: - Properties
    
    private var logProcessor: ClaudeLogProcessor!
    private var tempDirectory: URL!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        logProcessor = ClaudeLogProcessor()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VibeMeterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() async throws {
        // Clean up temporary files
        try? FileManager.default.removeItem(at: tempDirectory)
        
        try await super.tearDown()
    }
    
    // MARK: - Log File Generation
    
    private func createTestLogFile(with entries: Int, at url: URL) throws {
        var logContent = ""
        let models = ["claude-3-5-sonnet-latest", "claude-3-haiku", "claude-3-opus"]
        
        for i in 0..<entries {
            let timestamp = Date().addingTimeInterval(Double(-i * 60)) // Each entry 1 minute apart
            let model = models[i % models.count]
            let inputTokens = Int.random(in: 100...10_000)
            let outputTokens = Int.random(in: 50...5_000)
            
            let entry: [String: Any] = [
                "timestamp": ISO8601DateFormatter().string(from: timestamp),
                "model": model,
                "usage": [
                    "input_tokens": inputTokens,
                    "output_tokens": outputTokens
                ]
            ]
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: entry),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                logContent += jsonString + "\n"
            }
        }
        
        try logContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Performance Tests
    
    func testParseSmallLogFile() async throws {
        // Test with 100 entries (typical daily usage)
        let logFile = tempDirectory.appendingPathComponent("small.jsonl")
        try createTestLogFile(with: 100, at: logFile)
        
        // Test once to ensure it works
        let (dailyUsage, _) = await logProcessor.processLogFiles([logFile], usingCache: [:])
        XCTAssertFalse(dailyUsage.isEmpty)
        
        // Measure performance separately
        measure {
            let expectation = self.expectation(description: "Parse small log")
            let processor = logProcessor!
            
            Task { @Sendable in
                let (dailyUsage, _) = await processor.processLogFiles([logFile], usingCache: [:])
                if dailyUsage.isEmpty {
                    XCTFail("Daily usage should not be empty")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testParseMediumLogFile() async throws {
        // Test with 1,000 entries (heavy daily usage)
        let logFile = tempDirectory.appendingPathComponent("medium.jsonl")
        try createTestLogFile(with: 1_000, at: logFile)
        
        measure {
            let expectation = self.expectation(description: "Parse medium log")
            let processor = logProcessor!
            
            Task { @Sendable in
                let (dailyUsage, _) = await processor.processLogFiles([logFile], usingCache: [:])
                if dailyUsage.isEmpty {
                    XCTFail("Daily usage should not be empty")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testParseLargeLogFile() async throws {
        // Test with 10,000 entries (very heavy usage over time)
        let logFile = tempDirectory.appendingPathComponent("large.jsonl")
        try createTestLogFile(with: 10_000, at: logFile)
        
        measure {
            let expectation = self.expectation(description: "Parse large log")
            let processor = logProcessor!
            
            Task { @Sendable in
                let (dailyUsage, _) = await processor.processLogFiles([logFile], usingCache: [:])
                if dailyUsage.isEmpty {
                    XCTFail("Daily usage should not be empty")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testParseMultipleLogFiles() async throws {
        // Test with multiple files (simulating multiple days)
        var logFiles: [URL] = []
        
        for i in 0..<10 {
            let logFile = tempDirectory.appendingPathComponent("day-\(i).jsonl")
            try createTestLogFile(with: 500, at: logFile)
            logFiles.append(logFile)
        }
        
        measure {
            let expectation = self.expectation(description: "Parse multiple logs")
            let files = logFiles // Create local copy for Sendable closure
            let processor = logProcessor!
            
            Task { @Sendable in
                let (dailyUsage, _) = await processor.processLogFiles(files, usingCache: [:])
                if dailyUsage.isEmpty {
                    XCTFail("Daily usage should not be empty")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 20.0)
        }
    }
    
    // MARK: - Cache Performance Tests
    
    func testParseWithCache() async throws {
        // Create test files
        let logFile1 = tempDirectory.appendingPathComponent("cached1.jsonl")
        let logFile2 = tempDirectory.appendingPathComponent("cached2.jsonl")
        try createTestLogFile(with: 1_000, at: logFile1)
        try createTestLogFile(with: 1_000, at: logFile2)
        
        // First parse without cache
        let (_, hashCache) = await logProcessor.processLogFiles([logFile1, logFile2], usingCache: [:])
        
        // Measure second parse with cache
        measure {
            let expectation = self.expectation(description: "Parse with cache")
            let processor = logProcessor!
            let cache = hashCache
            
            Task { @Sendable in
                let (dailyUsage, _) = await processor.processLogFiles([logFile1, logFile2], usingCache: cache)
                if dailyUsage.isEmpty {
                    XCTFail("Daily usage should not be empty")
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    // MARK: - Real-time Update Performance
    
    func testRealTimeWindowCalculation() async throws {
        // Create entries for the last 5 hours
        var entries: [ClaudeLogEntry] = []
        let now = Date()
        
        for i in 0..<300 { // 300 entries over 5 hours
            let timestamp = now.addingTimeInterval(Double(-i * 60)) // 1 minute intervals
            let entry = ClaudeLogEntry(
                timestamp: timestamp,
                model: "claude-3-5-sonnet-latest",
                inputTokens: Int.random(in: 100...1000),
                outputTokens: Int.random(in: 50...500)
            )
            entries.append(entry)
        }
        
        let dailyUsage = [Calendar.current.startOfDay(for: now): entries]
        
        measure {
            Task { @MainActor @Sendable in
                let calculator = ClaudeFiveHourWindowCalculator()
                _ = calculator.calculateFiveHourWindow(from: dailyUsage)
            }
        }
    }
    
    // MARK: - Memory Performance Tests
    
    func testMemoryUsageWithLargeDataset() async throws {
        // Create a very large dataset
        let logFile = tempDirectory.appendingPathComponent("memory-test.jsonl")
        try createTestLogFile(with: 50_000, at: logFile)
        
        // Monitor memory usage
        let startMemory = getMemoryUsage()
        
        let (dailyUsage, _) = await logProcessor.processLogFiles([logFile], usingCache: [:])
        
        let endMemory = getMemoryUsage()
        let memoryIncrease = endMemory - startMemory
        
        // Verify memory usage is reasonable (less than 100MB for 50k entries)
        XCTAssertLessThan(memoryIncrease, 100 * 1024 * 1024, "Memory usage too high: \(memoryIncrease / 1024 / 1024)MB")
        XCTAssertFalse(dailyUsage.isEmpty)
    }
    
    // MARK: - Parallel Processing Performance
    
    func testParallelFileProcessing() async throws {
        // Create multiple files that should be processed in parallel
        var logFiles: [URL] = []
        
        for i in 0..<20 {
            let logFile = tempDirectory.appendingPathComponent("parallel-\(i).jsonl")
            try createTestLogFile(with: 200, at: logFile)
            logFiles.append(logFile)
        }
        
        let startTime = Date()
        let (dailyUsage, _) = await logProcessor.processLogFiles(logFiles, usingCache: [:])
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Parallel processing should be significantly faster than sequential
        // With 20 files, parallel should take less than 2 seconds
        XCTAssertLessThan(elapsed, 2.0, "Parallel processing too slow: \(elapsed)s")
        XCTAssertFalse(dailyUsage.isEmpty)
    }
    
    // MARK: - Helper Methods
    
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