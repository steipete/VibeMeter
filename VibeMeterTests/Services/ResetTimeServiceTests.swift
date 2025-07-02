import Testing
import Foundation
@testable import VibeMeter

// MARK: - Test Tags

extension Tag {
    @Tag static var reset: Self
    @Tag static var schedule: Self
    @Tag static var cursor: Self  // Add missing cursor tag
}

// MARK: - Test Suite

@Suite("ResetTimeService Tests", .tags(.reset))
@MainActor
struct ResetTimeServiceTests: Sendable {
    let sut: ResetTimeService
    
    init() {
        self.sut = ResetTimeService()
    }
    
    // MARK: - Basic Reset Info Tests
    
    @Test("Get reset info for all providers", arguments: ServiceProvider.allCases)
    func getResetInfo(provider: ServiceProvider) {
        // When
        let info = sut.getResetInfo(for: provider)
        
        // Then
        #expect(info.provider == provider)
        #expect(info.nextReset > Date())
        #expect(info.previousReset < Date())
        #expect(info.hoursUntilReset > 0)
        #expect(info.daysUntilReset >= 0)
        #expect(info.percentageElapsed >= 0)
        #expect(info.percentageElapsed <= 100)
    }
    
    // MARK: - Provider-Specific Schedule Tests
    
    @Test("Claude uses 5-hour reset schedule", .tags(.claude, .schedule))
    func claudeFiveHourSchedule() {
        // When
        let info = sut.getResetInfo(for: .claude)
        
        // Then
        #expect(info.schedule.type == .fiveHour)
        
        // Verify reset hour is one of Claude's reset hours
        let calendar = Calendar.current
        let resetHour = calendar.component(.hour, from: info.nextReset)
        #expect([4, 9, 14, 18, 23].contains(resetHour))
        
        // Verify it's within 5 hours
        #expect(info.hoursUntilReset <= 5)
    }
    
    @Test("Cursor uses monthly reset schedule", .tags(.cursor, .schedule))
    func cursorMonthlySchedule() {
        // When
        let info = sut.getResetInfo(for: .cursor)
        
        // Then
        #expect(info.schedule.type == .monthly)
        
        // Verify reset is on first day of month
        let calendar = Calendar.current
        let day = calendar.component(.day, from: info.nextReset)
        #expect(day == 1)
    }
    
    // MARK: - Custom Schedule Tests
    
    @Test("Update custom schedule")
    func updateCustomSchedule() {
        // Given
        let customSchedule = ResetTimeService.ResetSchedule(
            provider: .cursor,
            type: .daily,
            customTime: nil,
            timezone: .current
        )
        
        // When
        sut.updateSchedule(customSchedule)
        let info = sut.getResetInfo(for: .cursor)
        
        // Then
        #expect(info.schedule.type == .daily)
    }
    
    @Test("Get all schedules")
    func getAllSchedules() {
        // When
        let schedules = sut.getAllSchedules()
        
        // Then
        #expect(!schedules.isEmpty)
        #expect(schedules.contains { $0.provider == .claude })
        #expect(schedules.contains { $0.provider == .cursor })
    }
    
    // MARK: - Reset Approaching Tests
    
    @Test("Detect approaching reset", arguments: [
        (provider: ServiceProvider.claude, threshold: 1.0),
        (provider: ServiceProvider.cursor, threshold: 24.0)
    ])
    func isApproachingReset(provider: ServiceProvider, threshold: Double) {
        // When
        let info = sut.getResetInfo(for: provider)
        let approaching = sut.isApproachingReset(provider: provider, thresholdHours: threshold)
        
        // Then
        if info.hoursUntilReset <= threshold {
            #expect(approaching)
        } else {
            #expect(!approaching)
        }
    }
    
    // MARK: - Multiple Provider Tests
    
    @Test("Get next reset across providers")
    func nextResetAcrossProviders() {
        // Given
        let providers = ServiceProvider.allCases
        
        // When
        let result = sut.getNextResetAcrossProviders(providers)
        
        // Then
        #expect(result != nil)
        if let (provider, info) = result {
            #expect(providers.contains(provider))
            #expect(info.nextReset > Date())
        }
    }
    
    // MARK: - Optimal Rate Calculation Tests
    
    @Test("Calculate optimal usage rate", arguments: [
        (currentUsage: 50.0, limit: 100.0),
        (currentUsage: 100.0, limit: 100.0), // At limit
        (currentUsage: 0.0, limit: 200.0)
    ])
    func calculateOptimalRate(currentUsage: Double, limit: Double) {
        // Given
        let provider = ServiceProvider.claude
        
        // When
        let rate = sut.calculateOptimalRate(
            currentUsage: currentUsage,
            limit: limit,
            provider: provider
        )
        
        // Then
        #expect(rate >= 0)
        if currentUsage < limit {
            #expect(rate > 0)
        }
    }
    
    // MARK: - Reset Summary Tests
    
    @Test("Reset summary format", arguments: ServiceProvider.allCases)
    func resetSummaryFormat(provider: ServiceProvider) {
        // When
        let summary = sut.getResetSummary(for: provider)
        
        // Then
        #expect(summary.contains("🔄"))
        #expect(summary.contains(provider.displayName))
        #expect(summary.contains("Reset"))
        #expect(summary.contains("Next:"))
        #expect(summary.contains("Progress:"))
    }
    
    // MARK: - Reset Description Tests
    
    @Test("Reset info description format")
    func resetInfoDescription() {
        // Given
        let info = sut.getResetInfo(for: .claude)
        
        // When
        let description = info.resetDescription
        
        // Then
        #expect(!description.isEmpty)
        #expect(description.contains("Resets"))
    }
    
    @Test("Time remaining text format", arguments: [
        0.5,  // 30 minutes
        1.5,  // 90 minutes
        12.0, // 12 hours
        36.0  // 1.5 days
    ])
    func timeRemainingText(hoursUntilReset: Double) {
        // Given
        let info = ResetTimeService.ResetInfo(
            provider: .cursor,
            nextReset: Date().addingTimeInterval(hoursUntilReset * 3600),
            previousReset: Date().addingTimeInterval(-3600),
            hoursUntilReset: hoursUntilReset,
            daysUntilReset: hoursUntilReset / 24,
            percentageElapsed: 50,
            schedule: ResetTimeService.ResetSchedule(provider: .cursor, type: .daily)
        )
        
        // When
        let text = info.timeRemainingText
        
        // Then
        #expect(!text.isEmpty)
        if hoursUntilReset < 1 {
            #expect(text.contains("minute"))
        } else if hoursUntilReset < 24 {
            #expect(text.contains("hour"))
        } else {
            #expect(text.contains("day"))
        }
    }
    
    // MARK: - Time Zone Tests
    
    @Test("Reset times respect timezone", .tags(.schedule))
    func resetTimesRespectTimezone() {
        // Given
        let easternTime = TimeZone(identifier: "America/New_York")!
        let pacificTime = TimeZone(identifier: "America/Los_Angeles")!
        
        let easternSchedule = ResetTimeService.ResetSchedule(
            provider: .cursor,
            type: .daily,
            timezone: easternTime
        )
        
        let pacificSchedule = ResetTimeService.ResetSchedule(
            provider: .cursor,
            type: .daily,
            timezone: pacificTime
        )
        
        // When
        sut.updateSchedule(easternSchedule)
        let easternInfo = sut.getResetInfo(for: .cursor)
        
        sut.updateSchedule(pacificSchedule)
        let pacificInfo = sut.getResetInfo(for: .cursor)
        
        // Then
        // Reset times should differ by timezone offset
        let timeDifference = abs(easternInfo.nextReset.timeIntervalSince(pacificInfo.nextReset))
        #expect(timeDifference > 0) // Times should be different
    }
    
    // MARK: - Notification Schedule Tests
    
    @Test("Create notification schedule")
    func createNotificationSchedule() {
        // Given
        let provider = ServiceProvider.claude
        let thresholds = [0.5, 1.0, 2.0]
        
        // When
        let schedule = sut.createNotificationSchedule(
            for: provider,
            thresholds: thresholds
        )
        
        // Then
        #expect(!schedule.isEmpty)
        #expect(schedule.allSatisfy { $0 > Date() })
        #expect(schedule == schedule.sorted()) // Should be in chronological order
    }
    
    // MARK: - Usage Recommendation Tests
    
    @Test("Usage recommendations - high usage")
    func usageRecommendationsHighUsage() {
        // Given
        let provider = ServiceProvider.claude
        let usage = 95.0
        let limit = 100.0
        
        // When
        let recommendation = sut.getUsageRecommendation(
            currentUsage: usage,
            limit: limit,
            provider: provider
        )
        
        // Then
        #expect(recommendation.contains("🚨"))
    }
    
    @Test("Usage recommendations - low usage")
    func usageRecommendationsLowUsage() {
        // Given
        let provider = ServiceProvider.claude
        let usage = 10.0
        let limit = 100.0
        
        // When
        let recommendation = sut.getUsageRecommendation(
            currentUsage: usage,
            limit: limit,
            provider: provider
        )
        
        // Then
        #expect(recommendation.contains("📊"))
    }
    
    @Test("Usage recommendations - medium usage")
    func usageRecommendationsMediumUsage() {
        // Given
        let provider = ServiceProvider.claude
        let usage = 50.0
        let limit = 100.0
        
        // When
        let recommendation = sut.getUsageRecommendation(
            currentUsage: usage,
            limit: limit,
            provider: provider
        )
        
        // Then
        #expect(recommendation.contains("📊") || recommendation.contains("✅"))
    }
}

// MARK: - Persistence Tests

@Suite("ResetSchedule Persistence Tests")
struct ResetSchedulePersistenceTests: Sendable {
    
    @Test("Save and load schedules")
    func saveAndLoadSchedules() {
        // Given
        let schedules: [ServiceProvider: ResetTimeService.ResetSchedule] = [
            .claude: ResetTimeService.ResetSchedule(provider: .claude, type: .fiveHour),
            .cursor: ResetTimeService.ResetSchedule(provider: .cursor, type: .monthly)
        ]
        
        // When
        ResetTimeService.ResetSchedule.saveSchedules(schedules)
        let loaded = ResetTimeService.ResetSchedule.loadSchedules()
        
        // Then
        #expect(loaded.count == schedules.count)
        #expect(loaded[.claude]?.type == .fiveHour)
        #expect(loaded[.cursor]?.type == .monthly)
    }
    
    @Test("Load empty schedules returns empty dictionary")
    func loadEmptySchedules() {
        // Given
        UserDefaults.standard.removeObject(forKey: "VibeMeter.ResetSchedules")
        
        // When
        let loaded = ResetTimeService.ResetSchedule.loadSchedules()
        
        // Then
        #expect(loaded.isEmpty)
    }
}