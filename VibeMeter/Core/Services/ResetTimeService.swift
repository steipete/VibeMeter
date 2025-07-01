import Foundation
import os.log

/// Service for tracking and predicting provider reset times
@MainActor
public final class ResetTimeService: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "ResetTimeService")
    
    // MARK: - Types
    
    /// Reset schedule configuration
    public struct ResetSchedule: Sendable, Codable {
        public let provider: ServiceProvider
        public let type: ResetType
        public let customTime: Date?
        public let timezone: TimeZone
        
        public enum ResetType: String, Sendable, Codable {
            case daily      // Reset at midnight
            case monthly    // Reset on 1st of month
            case fiveHour   // Claude's 5-hour windows
            case custom     // Custom reset time
        }
        
        public init(
            provider: ServiceProvider,
            type: ResetType,
            customTime: Date? = nil,
            timezone: TimeZone = .current
        ) {
            self.provider = provider
            self.type = type
            self.customTime = customTime
            self.timezone = timezone
        }
    }
    
    /// Reset timing information
    public struct ResetInfo: Sendable {
        public let provider: ServiceProvider
        public let nextReset: Date
        public let previousReset: Date
        public let hoursUntilReset: Double
        public let daysUntilReset: Double
        public let percentageElapsed: Double
        public let schedule: ResetSchedule
        
        public var resetDescription: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            formatter.dateStyle = hoursUntilReset > 24 ? .short : .none
            
            switch schedule.type {
            case .fiveHour:
                return "Resets at \(formatter.string(from: nextReset))"
            case .daily:
                return "Resets daily at midnight"
            case .monthly:
                return "Resets \(formatter.string(from: nextReset))"
            case .custom:
                return "Custom reset at \(formatter.string(from: nextReset))"
            }
        }
        
        public var timeRemainingText: String {
            if hoursUntilReset < 1 {
                let minutes = Int(hoursUntilReset * 60)
                return "\(minutes) minute\(minutes == 1 ? "" : "s")"
            } else if hoursUntilReset < 24 {
                let hours = Int(hoursUntilReset)
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                let days = Int(daysUntilReset)
                return "\(days) day\(days == 1 ? "" : "s")"
            }
        }
    }
    
    // MARK: - Properties
    
    // Default schedules for known providers
    private var schedules: [ServiceProvider: ResetSchedule] = [
        .claude: ResetSchedule(provider: .claude, type: .fiveHour),
        .cursor: ResetSchedule(provider: .cursor, type: .monthly)
    ]
    
    // Claude's reset hours (from ccseva)
    private let claudeResetHours = [4, 9, 14, 18, 23]
    
    // Cache for reset calculations
    private var resetCache: [ServiceProvider: ResetInfo] = [:]
    private var cacheExpiry: Date = .distantPast
    
    // MARK: - Public Methods
    
    /// Get reset info for a provider
    public func getResetInfo(for provider: ServiceProvider) -> ResetInfo {
        // Check cache
        if cacheExpiry > Date(), let cached = resetCache[provider] {
            return cached
        }
        
        // Get schedule
        let schedule = schedules[provider] ?? ResetSchedule(provider: provider, type: .daily)
        
        // Calculate reset times
        let (previous, next) = calculateResetTimes(for: schedule)
        
        // Calculate elapsed time
        let totalInterval = next.timeIntervalSince(previous)
        let elapsedInterval = Date().timeIntervalSince(previous)
        let percentageElapsed = min(100, (elapsedInterval / totalInterval) * 100)
        
        // Create info
        let info = ResetInfo(
            provider: provider,
            nextReset: next,
            previousReset: previous,
            hoursUntilReset: next.timeIntervalSinceNow / 3600,
            daysUntilReset: next.timeIntervalSinceNow / 86400,
            percentageElapsed: percentageElapsed,
            schedule: schedule
        )
        
        // Cache result
        resetCache[provider] = info
        cacheExpiry = Date().addingTimeInterval(60) // 1 minute cache
        
        return info
    }
    
    /// Update reset schedule for a provider
    public func updateSchedule(_ schedule: ResetSchedule) {
        schedules[schedule.provider] = schedule
        resetCache.removeValue(forKey: schedule.provider)
        logger.info("Updated reset schedule for \(schedule.provider.rawValue)")
    }
    
    /// Get all configured schedules
    public func getAllSchedules() -> [ResetSchedule] {
        Array(schedules.values)
    }
    
    /// Check if provider is approaching reset (within threshold)
    public func isApproachingReset(
        provider: ServiceProvider,
        thresholdHours: Double = 2.0
    ) -> Bool {
        let info = getResetInfo(for: provider)
        return info.hoursUntilReset <= thresholdHours
    }
    
    /// Get time until next reset for multiple providers
    public func getNextResetAcrossProviders(_ providers: [ServiceProvider]) -> (provider: ServiceProvider, resetInfo: ResetInfo)? {
        var earliestReset: (ServiceProvider, ResetInfo)?
        var earliestTime = Date.distantFuture
        
        for provider in providers {
            let info = getResetInfo(for: provider)
            if info.nextReset < earliestTime {
                earliestTime = info.nextReset
                earliestReset = (provider, info)
            }
        }
        
        return earliestReset
    }
    
    /// Calculate optimal usage rate to last until reset
    public func calculateOptimalRate(
        currentUsage: Double,
        limit: Double,
        provider: ServiceProvider
    ) -> Double {
        let info = getResetInfo(for: provider)
        let remaining = max(0, limit - currentUsage)
        
        guard info.hoursUntilReset > 0 else { return 0 }
        
        return remaining / info.hoursUntilReset
    }
    
    /// Get reset schedule summary
    public func getResetSummary(for provider: ServiceProvider) -> String {
        let info = getResetInfo(for: provider)
        
        return """
        🔄 \(provider.displayName) Reset Schedule
        \(info.resetDescription)
        Next: \(info.timeRemainingText)
        Progress: \(Int(info.percentageElapsed))% through current period
        """
    }
    
    // MARK: - Private Methods
    
    private func calculateResetTimes(for schedule: ResetSchedule) -> (previous: Date, next: Date) {
        let now = Date()
        let calendar = Calendar(identifier: .gregorian)
        
        switch schedule.type {
        case .fiveHour:
            return calculateClaudeResetTimes(now: now, calendar: calendar)
            
        case .daily:
            return calculateDailyResetTimes(now: now, calendar: calendar, timezone: schedule.timezone)
            
        case .monthly:
            return calculateMonthlyResetTimes(now: now, calendar: calendar, timezone: schedule.timezone)
            
        case .custom:
            guard let customTime = schedule.customTime else {
                return calculateDailyResetTimes(now: now, calendar: calendar, timezone: schedule.timezone)
            }
            return calculateCustomResetTimes(customTime: customTime, now: now)
        }
    }
    
    private func calculateClaudeResetTimes(now: Date, calendar: Calendar) -> (previous: Date, next: Date) {
        let currentHour = calendar.component(.hour, from: now)
        
        // Find previous and next reset hours
        var previousResetHour: Int?
        var nextResetHour: Int?
        
        for (_, hour) in claudeResetHours.enumerated() {
            if hour <= currentHour {
                previousResetHour = hour
            }
            if hour > currentHour && nextResetHour == nil {
                nextResetHour = hour
                break
            }
        }
        
        // Handle edge cases
        let isPreviousYesterday = previousResetHour == nil
        let isNextTomorrow = nextResetHour == nil
        
        if previousResetHour == nil {
            previousResetHour = claudeResetHours.last ?? 23
        }
        if nextResetHour == nil {
            nextResetHour = claudeResetHours.first ?? 4
        }
        
        // Create dates
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        
        // Previous reset
        components.hour = previousResetHour
        components.minute = 0
        components.second = 0
        if isPreviousYesterday {
            components.day! -= 1
        }
        let previous = calendar.date(from: components) ?? now
        
        // Next reset
        components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextResetHour
        components.minute = 0
        components.second = 0
        if isNextTomorrow {
            components.day! += 1
        }
        let next = calendar.date(from: components) ?? now
        
        return (previous, next)
    }
    
    private func calculateDailyResetTimes(
        now: Date,
        calendar: Calendar,
        timezone: TimeZone
    ) -> (previous: Date, next: Date) {
        var tzCalendar = calendar
        tzCalendar.timeZone = timezone
        
        let todayMidnight = tzCalendar.startOfDay(for: now)
        let tomorrowMidnight = tzCalendar.date(byAdding: .day, value: 1, to: todayMidnight) ?? now
        
        if now >= todayMidnight {
            return (todayMidnight, tomorrowMidnight)
        } else {
            let yesterdayMidnight = tzCalendar.date(byAdding: .day, value: -1, to: todayMidnight) ?? now
            return (yesterdayMidnight, todayMidnight)
        }
    }
    
    private func calculateMonthlyResetTimes(
        now: Date,
        calendar: Calendar,
        timezone: TimeZone
    ) -> (previous: Date, next: Date) {
        var tzCalendar = calendar
        tzCalendar.timeZone = timezone
        
        // Get first day of current month
        guard let currentMonthStart = tzCalendar.dateInterval(of: .month, for: now)?.start else {
            return calculateDailyResetTimes(now: now, calendar: calendar, timezone: timezone)
        }
        
        // Get first day of next month
        guard let nextMonth = tzCalendar.date(byAdding: .month, value: 1, to: currentMonthStart) else {
            return (currentMonthStart, now.addingTimeInterval(30 * 86400))
        }
        
        if now >= currentMonthStart {
            // Get first day of previous month
            _ = tzCalendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart.addingTimeInterval(-30 * 86400)
            return (currentMonthStart, nextMonth)
        } else {
            // This shouldn't happen but handle it
            let previousMonth = tzCalendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart.addingTimeInterval(-30 * 86400)
            return (previousMonth, currentMonthStart)
        }
    }
    
    private func calculateCustomResetTimes(customTime: Date, now: Date) -> (previous: Date, next: Date) {
        let interval = customTime.timeIntervalSinceNow
        
        if interval > 0 {
            // Future reset
            let previousInterval = customTime.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)
            let previous = customTime.addingTimeInterval(-previousInterval)
            return (previous, customTime)
        } else {
            // Past reset, calculate next occurrence
            let daysSince = abs(interval) / 86400
            let nextOccurrence = ceil(daysSince) * 86400
            let next = customTime.addingTimeInterval(nextOccurrence)
            return (customTime, next)
        }
    }
}

// MARK: - Integration Extensions

extension ResetTimeService {
    /// Create optimal notification schedule based on reset times
    public func createNotificationSchedule(
        for provider: ServiceProvider,
        thresholds: [Double] = [0.5, 1.0, 2.0, 6.0, 24.0]
    ) -> [Date] {
        let info = getResetInfo(for: provider)
        var notificationTimes: [Date] = []
        
        for threshold in thresholds {
            if info.hoursUntilReset > threshold {
                let notificationTime = info.nextReset.addingTimeInterval(-threshold * 3600)
                if notificationTime > Date() {
                    notificationTimes.append(notificationTime)
                }
            }
        }
        
        return notificationTimes.sorted()
    }
    
    /// Get reset-aware usage recommendation
    public func getUsageRecommendation(
        currentUsage: Double,
        limit: Double,
        provider: ServiceProvider
    ) -> String {
        let info = getResetInfo(for: provider)
        let optimalRate = calculateOptimalRate(
            currentUsage: currentUsage,
            limit: limit,
            provider: provider
        )
        
        let remaining = limit - currentUsage
        let percentUsed = (currentUsage / limit) * 100
        
        if percentUsed > 90 {
            return "🚨 Slow down! Only \(Int(remaining)) left until \(info.resetDescription)"
        } else if info.hoursUntilReset < 2 && percentUsed < 50 {
            return "💡 Use it or lose it! Reset in \(info.timeRemainingText)"
        } else if optimalRate > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let rateStr = formatter.string(from: NSNumber(value: optimalRate)) ?? "0"
            return "📊 Optimal rate: \(rateStr)/hour to last until reset"
        } else {
            return "✅ On track to last until \(info.resetDescription)"
        }
    }
}

// MARK: - Persistence Support

extension ResetTimeService.ResetSchedule {
    /// Save schedules to UserDefaults
    public static func saveSchedules(_ schedules: [ServiceProvider: ResetTimeService.ResetSchedule]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(Array(schedules.values))
            UserDefaults.standard.set(data, forKey: "VibeMeter.ResetSchedules")
        } catch {
            Logger.vibeMeter(category: "ResetTimeService").error("Failed to save schedules: \(error)")
        }
    }
    
    /// Load schedules from UserDefaults
    public static func loadSchedules() -> [ServiceProvider: ResetTimeService.ResetSchedule] {
        guard let data = UserDefaults.standard.data(forKey: "VibeMeter.ResetSchedules") else {
            return [:]
        }
        
        do {
            let decoder = JSONDecoder()
            let schedules = try decoder.decode([ResetTimeService.ResetSchedule].self, from: data)
            return Dictionary(uniqueKeysWithValues: schedules.map { ($0.provider, $0) })
        } catch {
            Logger.vibeMeter(category: "ResetTimeService").error("Failed to load schedules: \(error)")
            return [:]
        }
    }
}