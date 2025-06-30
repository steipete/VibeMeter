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
        public var isActive: Bool
        public var isGap: Bool
        
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
            let totalTokens = groupEntries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
            let lastEntryTime = groupEntries.map(\.timestamp).max() ?? startTime
            let isActive = Date().timeIntervalSince(lastEntryTime) < 300 // Active if used in last 5 minutes
            
            let session = Session(
                id: UUID().uuidString,
                startTime: startTime,
                actualEndTime: isActive ? nil : lastEntryTime,
                totalTokens: totalTokens,
                isActive: isActive,
                isGap: false
            )
            
            newSessions.append(session)
        }
        
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
    /// Calculate five-hour window with session awareness
    public func calculateSessionAwareFiveHourWindow() -> FiveHourWindow {
        guard let activeSession = getActiveSession() else {
            // No active session, return empty window
            return FiveHourWindow(
                used: 0,
                total: 100,
                resetDate: getNextResetTime(),
                tokensUsed: 0,
                estimatedTokenLimit: 200_000 // Default for Claude
            )
        }
        
        // Calculate usage percentage based on typical Claude limits
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
}