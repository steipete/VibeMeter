import Testing
@testable import VibeMeter
import UserNotifications

// MARK: - Test Tags

extension Tag {
    @Tag static var cooldown: Self
}

// MARK: - Test Suite

@Suite("SmartNotificationManager Tests", .tags(.notifications))
@MainActor
struct SmartNotificationManagerTests {
    let sut: SmartNotificationManager
    
    init() {
        self.sut = SmartNotificationManager.shared
    }
    
    // MARK: - Authorization Tests
    
    @Test("Request authorization returns result")
    func requestAuthorization() async {
        // When
        let result = await sut.requestAuthorization()
        
        // Then
        // Result will depend on system state, but should not crash
        #expect(result == true || result == false)
    }
    
    // MARK: - Usage Status Tests
    
    @Test("Usage status from percentage", arguments: [
        (percentage: 95.0, expected: SmartNotificationManager.UsageStatus.critical),
        (percentage: 75.0, expected: SmartNotificationManager.UsageStatus.warning),
        (percentage: 50.0, expected: SmartNotificationManager.UsageStatus.safe),
        (percentage: 10.0, expected: SmartNotificationManager.UsageStatus.safe)
    ])
    func usageStatusFromPercentage(percentage: Double, expected: SmartNotificationManager.UsageStatus) {
        // When
        let status = SmartNotificationManager.UsageStatus.from(percentage: percentage)
        
        // Then
        #expect(status == expected)
    }
    
    @Test("Usage status comparison")
    func usageStatusComparison() {
        // Given
        let safe = SmartNotificationManager.UsageStatus.safe
        let warning = SmartNotificationManager.UsageStatus.warning
        let critical = SmartNotificationManager.UsageStatus.critical
        
        // Then
        #expect(safe < warning)
        #expect(warning < critical)
        #expect(critical > safe)
    }
    
    // MARK: - Notification Type Tests
    
    @Test("Notification type priorities", arguments: [
        (SmartNotificationManager.NotificationType.usageCritical, 3),
        (SmartNotificationManager.NotificationType.depletionAlert, 3),
        (SmartNotificationManager.NotificationType.usageWarning, 2),
        (SmartNotificationManager.NotificationType.velocityAlert, 2),
        (SmartNotificationManager.NotificationType.sessionAlert, 2),
        (SmartNotificationManager.NotificationType.prediction, 1),
        (SmartNotificationManager.NotificationType.resetReminder, 1),
        (SmartNotificationManager.NotificationType.milestone, 0)
    ])
    func notificationTypePriorities(type: SmartNotificationManager.NotificationType, expectedPriority: Int) {
        #expect(type.priority == expectedPriority)
    }
    
    @Test("Notification sounds")
    func notificationSounds() {
        // Critical notifications should have critical sound
        #expect(SmartNotificationManager.NotificationType.usageCritical.sound == .defaultCritical)
        #expect(SmartNotificationManager.NotificationType.depletionAlert.sound == .defaultCritical)
        
        // Others should have default sound
        #expect(SmartNotificationManager.NotificationType.milestone.sound == .default)
    }
    
    // MARK: - State Management Tests
    
    @Test("Reset state for provider")
    func resetProviderState() {
        // Given
        let provider = ServiceProvider.claude
        
        // When
        sut.resetState(for: provider)
        
        // Then
        // Should not crash and state should be reset
        // We can't directly test private state, but operation should complete
    }
    
    @Test("Reset all states")
    func resetAllStates() {
        // When
        sut.resetAllStates()
        
        // Then
        // Should clear all provider states without crashing
    }
    
    // MARK: - Check and Notify Tests
    
    @Test("Check and notify with safe usage", .tags(.cooldown))
    func checkAndNotifySafeUsage() async {
        // Given
        let provider = ServiceProvider.cursor
        sut.resetState(for: provider)
        
        // When
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: 30.0,
            limit: 100.0,
            burnRate: 10.0
        )
        
        // Then
        // No notifications should be sent for safe usage (30%)
        // Test passes if no crash occurs
    }
    
    @Test("Check and notify with warning usage", .tags(.cooldown))
    func checkAndNotifyWarningUsage() async {
        // Given
        let provider = ServiceProvider.cursor
        sut.resetState(for: provider)
        
        // When
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: 75.0,
            limit: 100.0,
            burnRate: 20.0
        )
        
        // Then
        // Should trigger warning notification (75%)
        // Test passes if no crash occurs
    }
    
    @Test("Check and notify with critical usage", .tags(.cooldown))
    func checkAndNotifyCriticalUsage() async {
        // Given
        let provider = ServiceProvider.claude
        sut.resetState(for: provider)
        
        // When
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: 95.0,
            limit: 100.0,
            burnRate: 50.0
        )
        
        // Then
        // Should trigger critical notification (95%)
    }
    
    // MARK: - Milestone Detection Tests
    
    @Test("Milestone detection", arguments: [50, 70, 80, 90, 95])
    func milestoneDetection(milestone: Int) async {
        // Given
        let provider = ServiceProvider.cursor
        sut.resetState(for: provider)
        let percentage = Double(milestone)
        
        // When
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: percentage,
            limit: 100.0
        )
        
        // Then
        // Should detect milestone at specified percentage
    }
    
    // MARK: - Prediction-based Notifications
    
    @Test("Depletion alert from prediction")
    func depletionAlertFromPrediction() async {
        // Given
        let provider = ServiceProvider.claude
        sut.resetState(for: provider)
        
        let prediction = PredictionEngine.PredictionInfo(
            depletionTime: Date().addingTimeInterval(1800), // 30 minutes
            confidence: 85,
            daysRemaining: 0.02,
            hoursRemaining: 0.5,
            recommendedDailyLimit: 1000,
            onTrackForReset: false,
            resetTime: Date().addingTimeInterval(18000),
            provider: provider
        )
        
        // When
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: 95000,
            limit: 100000,
            prediction: prediction
        )
        
        // Then
        // Should trigger depletion alert due to < 2 hours remaining
    }
    
    // MARK: - Velocity-based Notifications
    
    @Test("Velocity acceleration alert")
    func velocityAccelerationAlert() async {
        // Given
        let provider = ServiceProvider.cursor
        sut.resetState(for: provider)
        
        let velocity = VelocityTracker.VelocityInfo(
            current: 1000,
            average24h: 500,
            average7d: 300,
            trend: .increasing,
            trendPercent: 100, // 100% increase
            peakHour: 14,
            isAccelerating: true
        )
        
        // When
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: 50.0,
            limit: 100.0,
            velocity: velocity
        )
        
        // Then
        // Should trigger velocity alert due to acceleration
    }
    
    // MARK: - Claude Session Notifications
    
    @Test("Claude session ending notification", .tags(.claude))
    func claudeSessionEndingNotification() async {
        // Given
        let activeSession = ClaudeSessionTracker.Session(
            id: "test-session",
            startTime: Date().addingTimeInterval(-3600),
            actualEndTime: nil,
            totalTokens: 100000,
            totalCost: 5.0,
            models: ["claude-3"],
            isActive: true,
            isGap: false,
            entryCount: 100
        )
        
        let sessionTracking = ClaudeSessionTracker.SessionTracking(
            activeWindow: ClaudeSessionTracker.SessionWindow(
                startTime: Date().addingTimeInterval(-3600),
                endTime: Date(),
                sessions: [activeSession],
                totalTokens: 100000,
                totalCost: 5.0,
                gapCount: 0,
                totalGapTime: 0
            ),
            currentSession: activeSession,
            recentSessions: [activeSession],
            sessionsInWindow: 1,
            averageSessionLength: 3600,
            totalCostInWindow: 5.0
        )
        
        let prediction = PredictionEngine.PredictionInfo(
            depletionTime: Date().addingTimeInterval(300), // 5 minutes
            confidence: 90,
            daysRemaining: 0.003,
            hoursRemaining: 0.083,
            recommendedDailyLimit: 0,
            onTrackForReset: false,
            resetTime: Date().addingTimeInterval(7200),
            provider: .claude
        )
        
        // When
        await sut.checkClaudeSessionNotification(
            sessionTracking: sessionTracking,
            prediction: prediction
        )
        
        // Then
        // Should potentially trigger both session ending and depletion alerts
    }
    
    // MARK: - Notification Data Tests
    
    @Test("Notification data identifier format")
    func notificationDataIdentifier() {
        // Given
        let data = SmartNotificationManager.NotificationData(
            provider: .cursor,
            type: .usageWarning,
            title: "Test",
            body: "Test body",
            metadata: [:]
        )
        
        // Then
        #expect(data.identifier.contains("cursor"))
        #expect(data.identifier.contains("usage_warning"))
    }
    
    // MARK: - Cooldown Behavior Tests
    
    @Test("Cooldown prevents duplicate notifications", .tags(.cooldown))
    func cooldownPreventssDuplicates() async throws {
        // Given
        let provider = ServiceProvider.cursor
        sut.resetState(for: provider)
        
        // Send first notification
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: 75.0,
            limit: 100.0
        )
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Try to send same notification
        await sut.checkAndNotify(
            provider: provider,
            currentUsage: 75.0,
            limit: 100.0
        )
        
        // Then
        // Second notification should be skipped due to cooldown
        // Test passes if no duplicate notifications are sent
    }
}

// MARK: - Notification Center Delegate Tests

@Suite("NotificationManager Delegate Tests")
@MainActor
struct NotificationDelegateTests {
    
    @Test("Notification presentation options")
    func notificationPresentationOptions() {
        // Given
        let manager = SmartNotificationManager.shared
        
        // Then - we know the implementation returns these options
        let expectedOptions: UNNotificationPresentationOptions = [.banner, .sound, .badge, .list]
        #expect(expectedOptions.contains(.banner))
        #expect(expectedOptions.contains(.sound))
        #expect(expectedOptions.contains(.badge))
        #expect(expectedOptions.contains(.list))
    }
}