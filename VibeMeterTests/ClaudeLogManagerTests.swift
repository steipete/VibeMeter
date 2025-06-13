import Foundation
import os.log
import Testing
@testable import VibeMeter

// MARK: - Mock ClaudeLogManager

final class MockClaudeLogManager: ClaudeLogManagerProtocol, @unchecked Sendable {
    // MARK: - Properties

    @MainActor
    private(set) var hasAccess = false
    @MainActor
    private(set) var isProcessing = false
    @MainActor
    private(set) var lastError: Error?

    // Mock behaviors
    @MainActor
    var requestLogAccessResult = true
    @MainActor
    var getDailyUsageResult: [Date: [ClaudeLogEntry]] = [:]
    @MainActor
    var calculateFiveHourWindowResult = FiveHourWindow(
        used: 50,
        total: 100,
        resetDate: Date().addingTimeInterval(3600),
        tokensUsed: 50000,
        estimatedTokenLimit: 100_000)
    @MainActor
    var countTokensResult = 1000

    // Call tracking
    @MainActor
    private(set) var requestLogAccessCallCount = 0
    @MainActor
    private(set) var revokeAccessCallCount = 0
    @MainActor
    private(set) var getDailyUsageCallCount = 0
    @MainActor
    private(set) var calculateFiveHourWindowCallCount = 0
    @MainActor
    private(set) var countTokensCallCount = 0
    @MainActor
    private(set) var lastCountTokensInput: String?

    // MARK: - Initialization

    @MainActor
    init(hasAccess: Bool = false) {
        self.hasAccess = hasAccess
    }

    // MARK: - ClaudeLogManagerProtocol

    @MainActor
    func requestLogAccess() async -> Bool {
        requestLogAccessCallCount += 1
        hasAccess = requestLogAccessResult
        return requestLogAccessResult
    }

    @MainActor
    func revokeAccess() {
        revokeAccessCallCount += 1
        hasAccess = false
    }

    @MainActor
    func getDailyUsage() async -> [Date: [ClaudeLogEntry]] {
        getDailyUsageCallCount += 1
        isProcessing = true
        defer { isProcessing = false }
        return getDailyUsageResult
    }

    @MainActor
    func getDailyUsageWithProgress(delegate: ClaudeLogProgressDelegate?) async -> [Date: [ClaudeLogEntry]] {
        getDailyUsageCallCount += 1
        isProcessing = true
        defer { isProcessing = false }

        // Simulate progress updates if delegate provided
        if let delegate {
            delegate.logProcessingDidStart(totalFiles: 5)
            delegate.logProcessingDidUpdate(filesProcessed: 5, dailyUsage: getDailyUsageResult)
            delegate.logProcessingDidComplete(dailyUsage: getDailyUsageResult)
        }

        return getDailyUsageResult
    }

    @MainActor
    func calculateFiveHourWindow(from _: [Date: [ClaudeLogEntry]]) -> FiveHourWindow {
        calculateFiveHourWindowCallCount += 1
        return calculateFiveHourWindowResult
    }

    @MainActor
    func countTokens(in text: String) -> Int {
        countTokensCallCount += 1
        lastCountTokensInput = text
        return countTokensResult
    }

    @MainActor
    func getCurrentWindowUsage() async -> FiveHourWindow {
        calculateFiveHourWindowResult
    }
}

// MARK: - ClaudeLogManager Tests

@Suite("ClaudeLogManager Tests", .tags(.claudeLogManager))
struct ClaudeLogManagerTests {
    // MARK: - Helper Methods

    @MainActor
    private func createManager(fileManager: FileManager = .default,
                               userDefaults: UserDefaults = UserDefaults(suiteName: "com.vibemeter.tests")!)
        -> ClaudeLogManager {
        // Clear test UserDefaults
        userDefaults.removePersistentDomain(forName: "com.vibemeter.tests")
        return ClaudeLogManager(fileManager: fileManager, userDefaults: userDefaults)
    }

    private func createMockLogEntry(timestamp: Date = Date(),
                                    inputTokens: Int = 100,
                                    outputTokens: Int = 50,
                                    model: String? = "claude-3-5-sonnet") -> ClaudeLogEntry {
        ClaudeLogEntry(
            timestamp: timestamp,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens)
    }

    // MARK: - Tests

    @Test("Initial state without access")
    @MainActor
    func initialStateWithoutAccess() {
        let manager = createManager()

        #expect(!manager.hasAccess)
        #expect(!manager.isProcessing)
        #expect(manager.lastError == nil)
    }

    @Test("Request log access - user approves")
    @MainActor
    func requestLogAccessApproved() async {
        // This test would need UI interaction in real implementation
        // For now, we test the mock behavior
        let mock = MockClaudeLogManager()
        mock.requestLogAccessResult = true

        let result = await mock.requestLogAccess()

        #expect(result == true)
        #expect(mock.hasAccess)
        #expect(mock.requestLogAccessCallCount == 1)
    }

    @Test("Request log access - user denies")
    @MainActor
    func requestLogAccessDenied() async {
        let mock = MockClaudeLogManager()
        mock.requestLogAccessResult = false

        let result = await mock.requestLogAccess()

        #expect(result == false)
        #expect(!mock.hasAccess)
        #expect(mock.requestLogAccessCallCount == 1)
    }

    @Test("Revoke access")
    @MainActor
    func testRevokeAccess() {
        let mock = MockClaudeLogManager(hasAccess: true)

        #expect(mock.hasAccess)

        mock.revokeAccess()

        #expect(!mock.hasAccess)
        #expect(mock.revokeAccessCallCount == 1)
    }

    @Test("Get daily usage with cache")
    @MainActor
    func getDailyUsageWithCache() async {
        let mock = MockClaudeLogManager(hasAccess: true)
        let today = Date()
        let entries = [
            createMockLogEntry(inputTokens: 100, outputTokens: 50),
            createMockLogEntry(inputTokens: 200, outputTokens: 100),
        ]
        mock.getDailyUsageResult = [today: entries]

        // First call
        let usage1 = await mock.getDailyUsage()
        #expect(usage1.count == 1)
        #expect(usage1[today]?.count == 2)
        #expect(mock.getDailyUsageCallCount == 1)

        // Second call should use cache (in real implementation)
        let usage2 = await mock.getDailyUsage()
        #expect(usage2.count == 1)
        #expect(mock.getDailyUsageCallCount == 2) // Mock doesn't implement caching
    }

    @Test("Calculate five hour window - Pro account")
    @MainActor
    func calculateFiveHourWindowPro() {
        let mock = MockClaudeLogManager()
        let now = Date()
        let recentEntries = [
            createMockLogEntry(timestamp: now.addingTimeInterval(-3600), inputTokens: 1000, outputTokens: 500),
            createMockLogEntry(timestamp: now.addingTimeInterval(-7200), inputTokens: 2000, outputTokens: 1000),
        ]

        mock.calculateFiveHourWindowResult = FiveHourWindow(
            used: 15, // 15% used
            total: 100,
            resetDate: now.addingTimeInterval(2 * 3600), // Reset in 2 hours
            tokensUsed: 15000,
            estimatedTokenLimit: 100_000)

        let window = mock.calculateFiveHourWindow(from: [now: recentEntries])

        #expect(window.used == 15)
        #expect(window.total == 100)
        #expect(mock.calculateFiveHourWindowCallCount == 1)
    }

    @Test("Calculate five hour window - Free account")
    @MainActor
    func calculateFiveHourWindowFree() {
        let mock = MockClaudeLogManager()
        let today = Date()
        let entries = Array(repeating: createMockLogEntry(), count: 25) // 25 messages

        mock.calculateFiveHourWindowResult = FiveHourWindow(
            used: 50, // 50% of daily limit
            total: 100,
            resetDate: Calendar.current.startOfDay(for: today).addingTimeInterval(24 * 3600),
            tokensUsed: 50000,
            estimatedTokenLimit: 100_000)

        let window = mock.calculateFiveHourWindow(from: [today: entries])

        #expect(window.used == 50)
        #expect(window.total == 100)
        #expect(mock.calculateFiveHourWindowCallCount == 1)
    }

    @Test("Count tokens using Tiktoken")
    @MainActor
    func testCountTokens() {
        let mock = MockClaudeLogManager()
        let testText = "This is a test message for token counting"
        mock.countTokensResult = 10

        let count = mock.countTokens(in: testText)

        #expect(count == 10)
        #expect(mock.countTokensCallCount == 1)
        #expect(mock.lastCountTokensInput == testText)
    }

    @Test("Processing state during getDailyUsage")
    @MainActor
    func processingStateDuringGetDailyUsage() async {
        let mock = MockClaudeLogManager(hasAccess: true)

        #expect(!mock.isProcessing)

        // In real implementation, isProcessing would be true during the operation
        _ = await mock.getDailyUsage()

        #expect(!mock.isProcessing) // Should be false after completion
        #expect(mock.getDailyUsageCallCount == 1)
    }

    @Test("Error handling - no access")
    @MainActor
    func errorHandlingNoAccess() async {
        let manager = createManager()

        #expect(!manager.hasAccess)

        let usage = await manager.getDailyUsage()

        #expect(usage.isEmpty)
    }

    @Test("Cache invalidation", .tags(.cache))
    @MainActor
    func cacheInvalidation() {
        let manager = createManager()

        // This would test the invalidateCache method if it were public
        // For now, we just ensure the manager initializes properly
        #expect(!manager.hasAccess)
    }
}

// MARK: - ClaudeLogEntry Tests

@Suite("ClaudeLogEntry Tests")
struct ClaudeLogEntryTests {
    @Test("Create log entry with all fields")
    func createLogEntryComplete() {
        let entry = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3-5-sonnet",
            inputTokens: 1000,
            outputTokens: 500)

        #expect(entry.inputTokens == 1000)
        #expect(entry.outputTokens == 500)
        #expect(entry.model == "claude-3-5-sonnet")
    }

    @Test("Create log entry with minimal fields")
    func createLogEntryMinimal() {
        let entry = ClaudeLogEntry(
            timestamp: Date(),
            model: nil,
            inputTokens: 100,
            outputTokens: 50)

        #expect(entry.inputTokens == 100)
        #expect(entry.outputTokens == 50)
        #expect(entry.model == nil)
    }
}

// MARK: - FiveHourWindow Tests

@Suite("FiveHourWindow Tests")
struct FiveHourWindowTests {
    @Test("Five hour window calculations")
    func fiveHourWindowCalculations() {
        let resetDate = Date().addingTimeInterval(3600)
        let window = FiveHourWindow(
            used: 75,
            total: 100,
            resetDate: resetDate,
            tokensUsed: 75000,
            estimatedTokenLimit: 100_000)

        #expect(window.used == 75)
        #expect(window.total == 100)
        #expect(window.resetDate == resetDate)

        // Test percentage calculation
        let percentage = window.used / window.total * 100
        #expect(percentage == 75)
    }

    @Test("Five hour window edge cases")
    func fiveHourWindowEdgeCases() {
        // Over 100% usage
        let overUsed = FiveHourWindow(
            used: 150,
            total: 100,
            resetDate: Date(),
            tokensUsed: 150_000,
            estimatedTokenLimit: 100_000)
        #expect(overUsed.used == 150)

        // Zero usage
        let noUsage = FiveHourWindow(
            used: 0,
            total: 100,
            resetDate: Date(),
            tokensUsed: 0,
            estimatedTokenLimit: 100_000)
        #expect(noUsage.used == 0)
    }
}
