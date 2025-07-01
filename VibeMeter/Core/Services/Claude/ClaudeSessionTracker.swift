import Foundation
import os.log

/// Tracks Claude sessions with exact start times and active states
/// This mimics the behavior of ccusage blocks for more accurate window tracking
@MainActor
public final class ClaudeSessionTracker: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "ClaudeSessionTracker")
    
    // MARK: - Types
    
    /// Represents a Claude usage session (5-hour window)
    public struct Session: Sendable, Codable {
        public let id: String
        public let startTime: Date
        public var actualEndTime: Date?
        public var totalTokens: Int
        public var totalCost: Double
        public var models: [String]
        public var isActive: Bool
        public var isGap: Bool
        public var entryCount: Int
        
        /// Calculate the expected end time (5 hours after start)
        public var expectedEndTime: Date {
            startTime.addingTimeInterval(5 * 60 * 60)
        }
        
        /// Check if session is expired
        public var isExpired: Bool {
            Date() > expectedEndTime
        }
        
        /// Get the effective end time for calculations
        public var effectiveEndTime: Date {
            if isActive {
                return min(Date(), expectedEndTime)
            } else if let actualEnd = actualEndTime {
                return min(actualEnd, expectedEndTime)
            } else {
                return expectedEndTime
            }
        }
        
        /// Duration of the session
        public var duration: TimeInterval {
            effectiveEndTime.timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Properties
    
    private var sessions: [Session] = []
    private let sessionCacheKey = "ClaudeSessionTracker.sessions"
    
    // Fixed reset schedule (like Claude token monitor)
    private let defaultResetHours = [4, 9, 14, 18, 23]
    
    // MARK: - Public Methods
    
    /// Get all sessions, loading from cache if needed
    public func getSessions() -> [Session] {
        if sessions.isEmpty {
            loadSessionsFromCache()
        }
        return sessions
    }
    
    /// Get the currently active session
    public func getActiveSession() -> Session? {
        getSessions().first { $0.isActive && !$0.isExpired }
    }
    
    /// Update sessions based on log entries
    public func updateSessions(from entries: [ClaudeLogEntry]) {
        logger.info("Updating sessions from \(entries.count) log entries")
        
        // Group entries by approximate session windows
        let sessionGroups = groupEntriesIntoSessions(entries)
        
        // Convert to sessions
        var newSessions: [Session] = []
        
        for (startTime, groupEntries) in sessionGroups.sorted(by: { $0.key < $1.key }) {
            let totalTokens = groupEntries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens + 
                                                      ($1.cacheCreationTokens ?? 0) + ($1.cacheReadTokens ?? 0) }
            let totalCost = groupEntries.reduce(0.0) { $0 + $1.calculateCost() }
            let models = Array(Set(groupEntries.compactMap { $0.model }))
            let lastEntryTime = groupEntries.map(\.timestamp).max() ?? startTime
            let isActive = Date().timeIntervalSince(lastEntryTime) < 300 // Active if used in last 5 minutes
            
            let session = Session(
                id: UUID().uuidString,
                startTime: startTime,
                actualEndTime: isActive ? nil : lastEntryTime,
                totalTokens: totalTokens,
                totalCost: totalCost,
                models: models,
                isActive: isActive,
                isGap: false,
                entryCount: groupEntries.count
            )
            
            newSessions.append(session)
        }
        
        // Detect and add gap sessions
        newSessions = detectAndAddGapSessions(newSessions)
        
        // Mark expired sessions as inactive
        for i in 0..<newSessions.count {
            if newSessions[i].isExpired {
                newSessions[i].isActive = false
                if newSessions[i].actualEndTime == nil {
                    newSessions[i].actualEndTime = newSessions[i].expectedEndTime
                }
            }
        }
        
        // Keep only recent sessions (last 24 hours)
        let cutoffDate = Date().addingTimeInterval(-24 * 60 * 60)
        sessions = newSessions.filter { $0.startTime > cutoffDate }
        
        // Save to cache
        saveSessionsToCache()
        
        logger.info("Updated to \(self.sessions.count) sessions, active: \(self.sessions.filter(\.isActive).count)")
    }
    
    /// Get the next reset time based on fixed schedule
    public func getNextResetTime(customHour: Int? = nil, timezone: TimeZone = .current) -> Date {
        let calendar = Calendar.current
        let now = Date()
        
        // Use custom hour or default schedule
        let resetHours = customHour != nil ? [customHour!] : defaultResetHours
        
        // Convert to target timezone
        var targetCalendar = calendar
        targetCalendar.timeZone = timezone
        
        let currentHour = targetCalendar.component(.hour, from: now)
        let currentMinute = targetCalendar.component(.minute, from: now)
        
        // Find next reset hour
        var nextResetHour: Int?
        for hour in resetHours {
            if currentHour < hour || (currentHour == hour && currentMinute == 0) {
                nextResetHour = hour
                break
            }
        }
        
        // If no reset hour found today, use first one tomorrow
        let isNextDay = nextResetHour == nil
        if nextResetHour == nil {
            nextResetHour = resetHours.first ?? 0
        }
        
        // Create next reset date
        var components = targetCalendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextResetHour
        components.minute = 0
        components.second = 0
        
        if isNextDay {
            components.day! += 1
        }
        
        return targetCalendar.date(from: components) ?? now
    }
    
    /// Calculate burn rate using session-aware data
    public func calculateSessionAwareBurnRate() -> BurnRateCalculator.BurnRate? {
        let calculator = BurnRateCalculator()
        let activeSessions = getSessions()
        
        // Convert sessions to BurnRateCalculator sessions
        let burnRateSessions = activeSessions.compactMap { session -> BurnRateCalculator.UsageSession? in
            guard session.totalTokens > 0 else { return nil }
            
            return BurnRateCalculator.UsageSession(
                startTime: session.startTime,
                endTime: session.effectiveEndTime,
                value: Double(session.totalTokens),
                provider: .claude,
                metric: .tokens
            )
        }
        
        guard !burnRateSessions.isEmpty else { return nil }
        
        return calculator.calculateHourlyBurnRate(
            sessions: burnRateSessions,
            currentTime: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func groupEntriesIntoSessions(_ entries: [ClaudeLogEntry]) -> [Date: [ClaudeLogEntry]] {
        var sessionGroups: [Date: [ClaudeLogEntry]] = [:]
        
        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            // Find or create session for this entry
            var foundSession = false
            
            for (sessionStart, _) in sessionGroups {
                let sessionEnd = sessionStart.addingTimeInterval(5 * 60 * 60)
                if entry.timestamp >= sessionStart && entry.timestamp < sessionEnd {
                    sessionGroups[sessionStart]?.append(entry)
                    foundSession = true
                    break
                }
            }
            
            if !foundSession {
                // Create new session starting at this entry's time
                sessionGroups[entry.timestamp] = [entry]
            }
        }
        
        return sessionGroups
    }
    
    /// Detect gaps between sessions and add gap sessions
    private func detectAndAddGapSessions(_ sessions: [Session]) -> [Session] {
        guard sessions.count > 1 else { return sessions }
        
        var result = [Session]()
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        
        // Configuration
        let minGapDuration: TimeInterval = 1800  // 30 minutes minimum gap
        
        for i in 0..<sortedSessions.count {
            let currentSession = sortedSessions[i]
            result.append(currentSession)
            
            // Check for gap after this session
            if i < sortedSessions.count - 1 {
                let nextSession = sortedSessions[i + 1]
                let currentEnd = currentSession.effectiveEndTime
                let gap = nextSession.startTime.timeIntervalSince(currentEnd)
                
                // Detect significant gaps
                if gap > minGapDuration {
                    // Create a gap session
                    let gapSession = Session(
                        id: "gap-\(UUID().uuidString)",
                        startTime: currentEnd,
                        actualEndTime: nextSession.startTime,
                        totalTokens: 0,
                        totalCost: 0,
                        models: [],
                        isActive: false,
                        isGap: true,
                        entryCount: 0
                    )
                    result.append(gapSession)
                    logger.debug("Detected gap of \(Int(gap/60)) minutes between sessions")
                }
            }
        }
        
        return result
    }
    
    /// Analyze session patterns for anomalies
    public func analyzeSessionPatterns() -> SessionPatternAnalysis {
        let allSessions = getSessions()
        let realSessions = allSessions.filter { !$0.isGap }
        let gapSessions = allSessions.filter { $0.isGap }
        
        // Calculate metrics
        let totalActiveTime = realSessions.reduce(0.0) { $0 + $1.duration }
        let totalGapTime = gapSessions.reduce(0.0) { $0 + $1.duration }
        let totalTime = totalActiveTime + totalGapTime
        
        let utilizationRate = totalTime > 0 ? (totalActiveTime / totalTime) * 100 : 0
        
        // Find longest session and gap
        let longestSession = realSessions.max { $0.duration < $1.duration }
        let longestGap = gapSessions.max { $0.duration < $1.duration }
        
        // Calculate session frequency
        let timeSpan = realSessions.compactMap(\.startTime).max()?.timeIntervalSince(
            realSessions.compactMap(\.startTime).min() ?? Date()
        ) ?? 0
        let sessionsPerHour = timeSpan > 0 ? Double(realSessions.count) / (timeSpan / 3600) : 0
        
        // Detect unusual patterns
        var anomalies: [String] = []
        
        // Check for marathon sessions
        if let longest = longestSession, longest.duration > 14400 { // > 4 hours
            anomalies.append("Marathon session detected: \(Int(longest.duration/3600))h")
        }
        
        // Check for rapid session switching
        if sessionsPerHour > 2 {
            anomalies.append("High session frequency: \(String(format: "%.1f", sessionsPerHour))/hr")
        }
        
        // Check for low utilization
        if utilizationRate < 50 && realSessions.count > 3 {
            anomalies.append("Low utilization: \(Int(utilizationRate))%")
        }
        
        return SessionPatternAnalysis(
            totalSessions: realSessions.count,
            totalGaps: gapSessions.count,
            averageSessionLength: totalActiveTime / max(Double(realSessions.count), 1),
            averageGapLength: totalGapTime / max(Double(gapSessions.count), 1),
            utilizationRate: utilizationRate,
            sessionsPerHour: sessionsPerHour,
            longestSession: longestSession,
            longestGap: longestGap,
            anomalies: anomalies
        )
    }
    
    /// Session pattern analysis results
    public struct SessionPatternAnalysis: Sendable {
        public let totalSessions: Int
        public let totalGaps: Int
        public let averageSessionLength: TimeInterval
        public let averageGapLength: TimeInterval
        public let utilizationRate: Double
        public let sessionsPerHour: Double
        public let longestSession: Session?
        public let longestGap: Session?
        public let anomalies: [String]
        
        public var summary: String {
            """
            📊 Session Pattern Analysis
            Sessions: \(totalSessions) (\(String(format: "%.1f", sessionsPerHour))/hr)
            Gaps: \(totalGaps)
            Utilization: \(Int(utilizationRate))%
            Avg Session: \(formatDuration(averageSessionLength))
            Avg Gap: \(formatDuration(averageGapLength))
            \(anomalies.isEmpty ? "✅ No anomalies detected" : "⚠️ Anomalies: \(anomalies.joined(separator: ", "))")
            """
        }
        
        private func formatDuration(_ duration: TimeInterval) -> String {
            if duration < 3600 {
                return "\(Int(duration/60))m"
            } else {
                return String(format: "%.1fh", duration/3600)
            }
        }
    }
    
    private func loadSessionsFromCache() {
        guard let data = UserDefaults.standard.data(forKey: sessionCacheKey),
              let cached = try? JSONDecoder().decode([Session].self, from: data) else {
            logger.info("No cached sessions found")
            return
        }
        
        sessions = cached
        logger.info("Loaded \(self.sessions.count) sessions from cache")
    }
    
    private func saveSessionsToCache() {
        guard let data = try? JSONEncoder().encode(sessions) else {
            logger.error("Failed to encode sessions for cache")
            return
        }
        
        UserDefaults.standard.set(data, forKey: sessionCacheKey)
        logger.info("Saved \(self.sessions.count) sessions to cache")
    }
}

// MARK: - Extensions for Five Hour Window Calculation

extension ClaudeSessionTracker {
    /// Session tracking info similar to ccseva
    public struct SessionTracking: Sendable {
        public let activeWindow: SessionWindow
        public let currentSession: Session?
        public let recentSessions: [Session]
        public let sessionsInWindow: Int
        public let averageSessionLength: TimeInterval
        public let totalCostInWindow: Double
    }
    
    /// Represents a 5-hour window
    public struct SessionWindow: Sendable {
        public let startTime: Date
        public let endTime: Date
        public let sessions: [Session]
        public let totalTokens: Int
        public let totalCost: Double
        public let gapCount: Int
        public let totalGapTime: TimeInterval
        
        public var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
        
        public var utilizationRate: Double {
            let activeTime = duration - totalGapTime
            return duration > 0 ? (activeTime / duration) * 100 : 0
        }
        
        public var hasGaps: Bool {
            gapCount > 0
        }
    }
    
    /// Get session tracking info for current 5-hour window
    public func getSessionTracking() -> SessionTracking {
        let now = Date()
        let windowStart = now.addingTimeInterval(-5 * 60 * 60)
        
        // Get all sessions and filter for window
        let allSessions = getSessions()
        let sessionsInWindow = allSessions.filter { session in
            session.startTime >= windowStart || 
            (session.effectiveEndTime > windowStart && session.startTime < now)
        }
        
        // Separate real sessions from gaps
        let realSessions = sessionsInWindow.filter { !$0.isGap }
        let gapSessions = sessionsInWindow.filter { $0.isGap }
        
        // Calculate window totals (only real sessions contribute to tokens/cost)
        let totalTokens = realSessions.reduce(0) { $0 + $1.totalTokens }
        let totalCost = realSessions.reduce(0.0) { $0 + $1.totalCost }
        
        // Calculate average session length
        let completedSessions = realSessions.filter { !$0.isActive }
        let averageLength: TimeInterval
        if !completedSessions.isEmpty {
            let totalDuration = completedSessions.reduce(0.0) { $0 + $1.duration }
            averageLength = totalDuration / Double(completedSessions.count)
        } else {
            averageLength = 0
        }
        
        let window = SessionWindow(
            startTime: windowStart,
            endTime: now,
            sessions: sessionsInWindow,
            totalTokens: totalTokens,
            totalCost: totalCost,
            gapCount: gapSessions.count,
            totalGapTime: gapSessions.reduce(0.0) { $0 + $1.duration }
        )
        
        return SessionTracking(
            activeWindow: window,
            currentSession: getActiveSession(),
            recentSessions: Array(realSessions.prefix(10)),
            sessionsInWindow: realSessions.count,
            averageSessionLength: averageLength,
            totalCostInWindow: totalCost
        )
    }
    
    /// Get session progress metrics
    public func getSessionProgress() -> (windowProgress: Double, sessionProgress: Double, efficiency: Double) {
        let tracking = getSessionTracking()
        let now = Date()
        
        // Window progress (0-100%)
        let windowElapsed = now.timeIntervalSince(tracking.activeWindow.startTime)
        let windowProgress = min(100, (windowElapsed / (5 * 60 * 60)) * 100)
        
        // Current session progress (assume typical 1 hour session)
        let sessionProgress: Double
        if let current = tracking.currentSession {
            let sessionElapsed = now.timeIntervalSince(current.startTime)
            sessionProgress = min(100, (sessionElapsed / 3600) * 100)
        } else {
            sessionProgress = 0
        }
        
        // Efficiency (tokens per minute in window)
        let totalMinutes = tracking.activeWindow.sessions.reduce(0.0) { total, session in
            total + (session.duration / 60)
        }
        let efficiency = totalMinutes > 0 ? Double(tracking.activeWindow.totalTokens) / totalMinutes : 0
        
        return (windowProgress, sessionProgress, efficiency)
    }
    
    /// Calculate five-hour window with session awareness
    public func calculateSessionAwareFiveHourWindow() -> FiveHourWindow {
        let tracking = getSessionTracking()
        
        // If we have an active session, use its data
        if let activeSession = tracking.currentSession {
            let estimatedLimit = 200_000 // Typical Claude session limit
            let usagePercentage = min(100, (Double(activeSession.totalTokens) / Double(estimatedLimit)) * 100)
            
            return FiveHourWindow(
                used: usagePercentage,
                total: 100,
                resetDate: activeSession.expectedEndTime,
                tokensUsed: activeSession.totalTokens,
                estimatedTokenLimit: estimatedLimit
            )
        }
        
        // No active session, use window data
        return FiveHourWindow(
            used: 0,
            total: 100,
            resetDate: getNextResetTime(),
            tokensUsed: 0,
            estimatedTokenLimit: 200_000
        )
    }
    
    /// Get detailed gap analysis
    public func getGapAnalysis() -> GapAnalysis {
        let sessions = getSessions()
        _ = sessions.filter { !$0.isGap }
        let gaps = sessions.filter { $0.isGap }
        
        // Calculate gap statistics
        let totalGapTime = gaps.reduce(0.0) { $0 + $1.duration }
        let averageGapDuration = gaps.isEmpty ? 0 : totalGapTime / Double(gaps.count)
        let longestGap = gaps.max { $0.duration < $1.duration }
        
        // Find patterns in gaps
        let calendar = Calendar.current
        var gapsByHour: [Int: Int] = [:]
        for gap in gaps {
            let hour = calendar.component(.hour, from: gap.startTime)
            gapsByHour[hour, default: 0] += 1
        }
        
        let frequentGapHours = gapsByHour
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map(\.key)
        
        return GapAnalysis(
            totalGaps: gaps.count,
            totalGapTime: totalGapTime,
            averageGapDuration: averageGapDuration,
            longestGap: longestGap,
            frequentGapHours: Array(frequentGapHours),
            recentGaps: Array(gaps.suffix(5))
        )
    }
    
    /// Gap analysis results
    public struct GapAnalysis: Sendable {
        public let totalGaps: Int
        public let totalGapTime: TimeInterval
        public let averageGapDuration: TimeInterval
        public let longestGap: Session?
        public let frequentGapHours: [Int]
        public let recentGaps: [Session]
        
        public var summary: String {
            let formatter = DateComponentsFormatter()
            formatter.allowedUnits = [.hour, .minute]
            formatter.unitsStyle = .abbreviated
            
            let totalTimeStr = formatter.string(from: totalGapTime) ?? "0m"
            let avgTimeStr = formatter.string(from: averageGapDuration) ?? "0m"
            
            return """
            🕳️ Gap Analysis
            Total Gaps: \(totalGaps)
            Total Gap Time: \(totalTimeStr)
            Average Gap: \(avgTimeStr)
            Frequent Gap Hours: \(frequentGapHours.map { "\($0):00" }.joined(separator: ", "))
            """
        }
    }
}