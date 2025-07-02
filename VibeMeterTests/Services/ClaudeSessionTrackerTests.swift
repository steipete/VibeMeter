import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Tags

extension Tag {
    @Tag static var sessions: Self
    @Tag static var gaps: Self
}

// MARK: - Test Suite

@Suite("ClaudeSessionTracker Tests", .tags(.sessions, .claude))
@MainActor
struct ClaudeSessionTrackerTests {
    let sut: ClaudeSessionTracker
    
    init() {
        self.sut = ClaudeSessionTracker()
    }
    
    // MARK: - Helper Methods
    
    private func createMockLogEntries(count: Int, startTime: Date = Date()) -> [ClaudeLogEntry] {
        (0..<count).map { i in
            ClaudeLogEntry(
                timestamp: startTime.addingTimeInterval(Double(i) * 300), // 5 min intervals
                model: "claude-3",
                inputTokens: 1000 + i * 100,
                outputTokens: 500 + i * 50,
                cacheCreationTokens: 100,
                cacheReadTokens: 50
            )
        }
    }
    
    private func createMockSession(
        id: String = UUID().uuidString,
        startOffset: TimeInterval,
        duration: TimeInterval = 3600,
        tokens: Int = 10000,
        isActive: Bool = false,
        isGap: Bool = false
    ) -> ClaudeSessionTracker.Session {
        let startTime = Date().addingTimeInterval(startOffset)
        return ClaudeSessionTracker.Session(
            id: id,
            startTime: startTime,
            actualEndTime: isActive ? nil : startTime.addingTimeInterval(duration),
            totalTokens: tokens,
            totalCost: Double(tokens) * 0.00005, // Simplified cost calculation
            models: ["claude-3"],
            isActive: isActive,
            isGap: isGap,
            entryCount: isGap ? 0 : tokens / 100
        )
    }
    
    // MARK: - Basic Session Tests
    
    @Test("Get active session when exists")
    func getActiveSession() {
        // Given
        let entries = createMockLogEntries(count: 5)
        sut.updateSessions(from: entries)
        
        // When
        let activeSession = sut.getActiveSession()
        
        // Then
        #expect(activeSession != nil)
        #expect(activeSession?.isActive == true)
        #expect(!activeSession!.isExpired)
    }
    
    @Test("Session properties calculate correctly")
    func sessionProperties() {
        // Given
        let session = createMockSession(
            startOffset: -3600,
            duration: 1800,
            isActive: false
        )
        
        // Then
        #expect(session.duration == 1800)
        #expect(session.effectiveEndTime == session.actualEndTime)
        #expect(!session.isExpired)
        
        // Expected end time should be 5 hours after start
        let expectedDuration = session.expectedEndTime.timeIntervalSince(session.startTime)
        #expect(expectedDuration == 5 * 60 * 60)
    }
    
    @Test("Expired session detection")
    func expiredSessionDetection() {
        // Given - Session started more than 5 hours ago
        let session = createMockSession(
            startOffset: -6 * 3600,
            duration: 1000,
            isActive: true // Still marked active but should be expired
        )
        
        // Then
        #expect(session.isExpired)
    }
    
    // MARK: - Session Update Tests
    
    @Test("Update sessions from log entries")
    func updateSessionsFromEntries() {
        // Given
        let now = Date()
        let entries = [
            // First session (2 hours ago)
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-7200), model: "claude-3", inputTokens: 1000, outputTokens: 500),
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-6900), model: "claude-3", inputTokens: 1500, outputTokens: 750),
            // Gap
            // Second session (30 minutes ago)
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-1800), model: "claude-3", inputTokens: 2000, outputTokens: 1000),
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-900), model: "claude-3", inputTokens: 1200, outputTokens: 600)
        ]
        
        // When
        sut.updateSessions(from: entries)
        let sessions = sut.getSessions()
        
        // Then
        #expect(sessions.count >= 2) // At least 2 sessions (may include gaps)
        
        // Verify token totals
        let realSessions = sessions.filter { !$0.isGap }
        let totalTokens = realSessions.reduce(0) { $0 + $1.totalTokens }
        #expect(totalTokens == 9550) // Sum of all input + output + cache tokens
    }
    
    // MARK: - Gap Detection Tests
    
    @Test("Detect gaps between sessions", .tags(.gaps))
    func detectGapsBetweenSessions() {
        // Given
        let now = Date()
        let entries = [
            // Session 1: 3 hours ago
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-10800), model: "claude-3", inputTokens: 1000, outputTokens: 500),
            // 2 hour gap
            // Session 2: 1 hour ago
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-3600), model: "claude-3", inputTokens: 2000, outputTokens: 1000)
        ]
        
        // When
        sut.updateSessions(from: entries)
        let sessions = sut.getSessions()
        
        // Then
        let gaps = sessions.filter { $0.isGap }
        #expect(gaps.count >= 1) // Should detect at least one gap
        
        // Verify gap properties
        if let gap = gaps.first {
            #expect(gap.totalTokens == 0)
            #expect(gap.totalCost == 0)
            #expect(gap.models.isEmpty)
            #expect(!gap.isActive)
            #expect(gap.entryCount == 0)
        }
    }
    
    @Test("No gaps for continuous sessions", .tags(.gaps))
    func noGapsForContinuousSessions() {
        // Given - Entries with small time gaps (< 30 min)
        let now = Date()
        let entries = (0..<10).map { i in
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(Double(-i) * 600), // 10 min intervals
                model: "claude-3",
                inputTokens: 1000,
                outputTokens: 500
            )
        }
        
        // When
        sut.updateSessions(from: entries)
        let sessions = sut.getSessions()
        
        // Then
        let gaps = sessions.filter { $0.isGap }
        #expect(gaps.isEmpty) // No gaps for continuous usage
    }
    
    // MARK: - Session Analysis Tests
    
    @Test("Analyze session patterns", .tags(.gaps))
    func analyzeSessionPatterns() {
        // Given - Mix of sessions and gaps
        let now = Date()
        let entries = [
            // Marathon session (4.5 hours ago, lasting 4 hours)
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-16200), model: "claude-3", inputTokens: 50000, outputTokens: 25000),
            // Multiple entries in same session
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-14400), model: "claude-3", inputTokens: 30000, outputTokens: 15000),
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-12600), model: "claude-3", inputTokens: 20000, outputTokens: 10000),
            // Gap
            // Recent short session
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-1800), model: "claude-3", inputTokens: 5000, outputTokens: 2500)
        ]
        
        // When
        sut.updateSessions(from: entries)
        let analysis = sut.analyzeSessionPatterns()
        
        // Then
        #expect(analysis.totalSessions >= 2)
        #expect(analysis.utilizationRate > 0)
        #expect(analysis.utilizationRate <= 100)
        
        // Check for marathon session detection
        #expect(analysis.anomalies.contains { $0.contains("Marathon session") })
    }
    
    @Test("Gap analysis")
    func gapAnalysis() {
        // Given - Create sessions with predictable gaps
        let now = Date()
        let entries = [
            // Morning session
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-28800), model: "claude-3", inputTokens: 1000, outputTokens: 500), // 8 hours ago
            // Lunch break gap
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-21600), model: "claude-3", inputTokens: 1000, outputTokens: 500), // 6 hours ago
            // Afternoon session
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-14400), model: "claude-3", inputTokens: 1000, outputTokens: 500), // 4 hours ago
        ]
        
        // When
        sut.updateSessions(from: entries)
        let gapAnalysis = sut.getGapAnalysis()
        
        // Then
        #expect(gapAnalysis.totalGaps >= 0)
        #expect(gapAnalysis.summary.contains("🕳️"))
        
        if gapAnalysis.totalGaps > 0 {
            #expect(gapAnalysis.totalGapTime > 0)
            #expect(gapAnalysis.averageGapDuration > 0)
        }
    }
    
    // MARK: - Reset Time Tests
    
    @Test("Get next reset time for Claude", .tags(.reset))
    func getNextResetTime() {
        // When
        let resetTime = sut.getNextResetTime()
        
        // Then
        #expect(resetTime > Date())
        
        // Verify it's one of Claude's reset hours
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: resetTime)
        #expect([4, 9, 14, 18, 23].contains(hour))
    }
    
    @Test("Custom reset hour")
    func customResetHour() {
        // When
        let customResetTime = sut.getNextResetTime(customHour: 12)
        
        // Then
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: customResetTime)
        #expect(hour == 12)
    }
    
    // MARK: - Session Tracking Tests
    
    @Test("Get session tracking for 5-hour window")
    func getSessionTracking() {
        // Given
        let entries = createMockLogEntries(count: 20)
        sut.updateSessions(from: entries)
        
        // When
        let tracking = sut.getSessionTracking()
        
        // Then
        #expect(tracking.activeWindow.startTime <= Date().addingTimeInterval(-5 * 3600))
        #expect(tracking.activeWindow.endTime >= Date())
        #expect(tracking.activeWindow.totalTokens > 0)
        #expect(tracking.activeWindow.utilizationRate >= 0)
        #expect(tracking.activeWindow.utilizationRate <= 100)
    }
    
    @Test("Session progress metrics")
    func sessionProgressMetrics() {
        // Given
        let entries = createMockLogEntries(count: 10)
        sut.updateSessions(from: entries)
        
        // When
        let (windowProgress, sessionProgress, efficiency) = sut.getSessionProgress()
        
        // Then
        #expect(windowProgress >= 0)
        #expect(windowProgress <= 100)
        #expect(sessionProgress >= 0)
        #expect(sessionProgress <= 100)
        #expect(efficiency >= 0)
    }
    
    // MARK: - Burn Rate Integration Tests
    
    @Test("Calculate session-aware burn rate", .tags(.burnRate))
    func calculateSessionAwareBurnRate() {
        // Given
        let entries = createMockLogEntries(count: 15, startTime: Date().addingTimeInterval(-3600))
        sut.updateSessions(from: entries)
        
        // When
        let burnRate = sut.calculateSessionAwareBurnRate()
        
        // Then
        #expect(burnRate != nil)
        #expect(burnRate?.metric == .tokens)
        #expect(burnRate?.ratePerHour ?? 0 > 0)
    }
    
    // MARK: - Five Hour Window Tests
    
    @Test("Calculate five-hour window with active session")
    func fiveHourWindowWithActiveSession() {
        // Given
        let entries = createMockLogEntries(count: 10)
        sut.updateSessions(from: entries)
        
        // When
        let window = sut.calculateSessionAwareFiveHourWindow()
        
        // Then
        #expect(window.used >= 0)
        #expect(window.used <= 100)
        #expect(window.total == 100)
        #expect(window.tokensUsed > 0)
        #expect(window.estimatedTokenLimit == 200_000)
    }
    
    @Test("Five-hour window without active session")
    func fiveHourWindowWithoutActiveSession() {
        // Given - No sessions
        
        // When
        let window = sut.calculateSessionAwareFiveHourWindow()
        
        // Then
        #expect(window.used == 0)
        #expect(window.tokensUsed == 0)
        #expect(window.resetDate > Date())
    }
    
    // MARK: - Session Persistence Tests
    
    @Test("Sessions persist across instances")
    func sessionPersistence() {
        // Given
        let entries = createMockLogEntries(count: 5)
        sut.updateSessions(from: entries)
        let originalSessions = sut.getSessions()
        
        // When - Create new instance
        let newTracker = ClaudeSessionTracker()
        let loadedSessions = newTracker.getSessions()
        
        // Then
        #expect(loadedSessions.count == originalSessions.count)
        if let firstOriginal = originalSessions.first,
           let firstLoaded = loadedSessions.first {
            #expect(firstLoaded.id == firstOriginal.id)
            #expect(firstLoaded.totalTokens == firstOriginal.totalTokens)
        }
    }
}

// MARK: - Session Window Tests

@Suite("SessionWindow Tests")
struct SessionWindowTests {
    
    @Test("Window utilization rate calculation")
    func windowUtilizationRate() {
        // Given
        let window = ClaudeSessionTracker.SessionWindow(
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date(),
            sessions: [],
            totalTokens: 10000,
            totalCost: 0.5,
            gapCount: 2,
            totalGapTime: 1800 // 30 minutes of gaps
        )
        
        // Then
        #expect(window.duration == 3600)
        #expect(window.utilizationRate == 50) // 50% utilization (1800/3600)
        #expect(window.hasGaps)
    }
}