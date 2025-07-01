import Testing
@testable import VibeMeter

// MARK: - Test Tags

extension Tag {
    @Tag static var prediction: Self
    @Tag static var claude: Self
    @Tag static var resetTime: Self
}

// MARK: - Test Suite

@Suite("PredictionEngine Tests", .tags(.prediction))
@MainActor
struct PredictionEngineTests {
    let sut: PredictionEngine
    let velocityTracker: VelocityTracker
    
    init() {
        self.sut = PredictionEngine()
        self.velocityTracker = VelocityTracker()
    }
    
    // MARK: - Basic Prediction Tests
    
    @Test("Calculate prediction with no burn rate returns no depletion")
    func noBurnRateNoDepletion() {
        // Given
        let provider = ServiceProvider.cursor
        let currentUsage = 50.0
        let limit = 100.0
        
        // When
        let prediction = sut.calculatePrediction(
            for: provider,
            currentUsage: currentUsage,
            limit: limit,
            burnRate: nil
        )
        
        // Then
        #expect(prediction.depletionTime == nil)
        #expect(prediction.hoursRemaining == Double.infinity)
        #expect(prediction.onTrackForReset)
    }
    
    @Test("Calculate prediction with burn rate", arguments: [
        (usage: 50.0, limit: 100.0, ratePerHour: 10.0, expectedHours: 5.0),
        (usage: 80.0, limit: 100.0, ratePerHour: 20.0, expectedHours: 1.0),
        (usage: 0.0, limit: 200.0, ratePerHour: 50.0, expectedHours: 4.0)
    ])
    func predictionWithBurnRate(usage: Double, limit: Double, ratePerHour: Double, expectedHours: Double) throws {
        // Given
        let provider = ServiceProvider.cursor
        let burnRate = BurnRateCalculator.BurnRate(
            ratePerMinute: ratePerHour / 60,
            ratePerHour: ratePerHour,
            metric: .spending,
            velocityIndicator: .normal
        )
        
        // When
        let prediction = sut.calculatePrediction(
            for: provider,
            currentUsage: usage,
            limit: limit,
            burnRate: burnRate
        )
        
        // Then
        #expect(prediction.depletionTime != nil)
        #expect(abs(prediction.hoursRemaining - expectedHours) < 0.1) // Allow small rounding differences
        #expect(prediction.confidence > 0)
    }
    
    // MARK: - Claude-Specific Tests
    
    @Test("Calculate Claude prediction with sessions", .tags(.claude))
    func claudePredictionWithSessions() {
        // Given
        let sessions = [
            ClaudeSessionTracker.Session(
                id: "1",
                startTime: Date().addingTimeInterval(-3600),
                actualEndTime: nil,
                totalTokens: 50000,
                totalCost: 2.5,
                models: ["claude-3"],
                isActive: true,
                isGap: false,
                entryCount: 50
            )
        ]
        
        let sessionTracking = ClaudeSessionTracker.SessionTracking(
            activeWindow: ClaudeSessionTracker.SessionWindow(
                startTime: Date().addingTimeInterval(-3600),
                endTime: Date(),
                sessions: sessions,
                totalTokens: 50000,
                totalCost: 2.5,
                gapCount: 0,
                totalGapTime: 0
            ),
            currentSession: sessions.first,
            recentSessions: sessions,
            sessionsInWindow: 1,
            averageSessionLength: 3600,
            totalCostInWindow: 2.5
        )
        
        // When
        let prediction = sut.calculateClaudePrediction(
            sessionTracking: sessionTracking,
            burnRate: 100.0 // tokens per minute
        )
        
        // Then
        #expect(prediction.provider == .claude)
        #expect(prediction.depletionTime != nil)
        #expect(prediction.confidence > 50) // Should have decent confidence with active session
        #expect(prediction.hoursRemaining > 0)
    }
    
    // MARK: - Reset Time Tests
    
    @Test("Get reset info for different providers", arguments: ServiceProvider.allCases, .tags(.resetTime))
    func resetInfoForProviders(provider: ServiceProvider) {
        // When
        let resetInfo = sut.getResetInfo(for: provider, customTime: nil)
        
        // Then
        #expect(resetInfo.nextReset > Date())
        #expect(resetInfo.hoursUntilReset > 0)
        #expect(resetInfo.daysUntilReset >= 0)
        
        // Verify reset type based on provider
        switch provider {
        case .claude:
            #expect(resetInfo.resetType == .fiveHour)
        case .cursor:
            #expect(resetInfo.resetType == .monthly)
        default:
            #expect(resetInfo.resetType == .daily)
        }
    }
    
    @Test("Claude reset time follows 5-hour schedule", .tags(.claude, .resetTime))
    func claudeResetSchedule() {
        // Given
        let calendar = Calendar.current
        let now = Date()
        
        // When
        let resetInfo = sut.getResetInfo(for: .claude, customTime: nil)
        
        // Then
        let resetHour = calendar.component(.hour, from: resetInfo.nextReset)
        #expect([4, 9, 14, 18, 23].contains(resetHour))
        #expect(resetInfo.hoursUntilReset <= 5) // Should be within 5 hours
    }
    
    // MARK: - Confidence Calculation Tests
    
    @Test("Confidence increases with data availability")
    func confidenceWithData() {
        // Given
        let provider = ServiceProvider.cursor
        let burnRate = BurnRateCalculator.BurnRate(
            ratePerMinute: 10.0,
            ratePerHour: 600.0,
            metric: .spending,
            velocityIndicator: .normal
        )
        
        // Add velocity data
        velocityTracker.addDataPoint(value: 500, provider: provider)
        velocityTracker.addDataPoint(value: 600, provider: provider, timestamp: Date().addingTimeInterval(-3600))
        velocityTracker.addDataPoint(value: 550, provider: provider, timestamp: Date().addingTimeInterval(-7200))
        
        let velocity = velocityTracker.calculateVelocity(for: provider)
        
        // When
        let prediction1 = sut.calculatePrediction(
            for: provider,
            currentUsage: 50.0,
            limit: 100.0,
            burnRate: nil
        )
        
        let prediction2 = sut.calculatePrediction(
            for: provider,
            currentUsage: 50.0,
            limit: 100.0,
            burnRate: burnRate
        )
        
        // Then
        #expect(prediction2.confidence > prediction1.confidence) // More data = higher confidence
    }
    
    // MARK: - Recommendation Tests
    
    @Test("Recommendations based on depletion status", arguments: [
        (hoursRemaining: 0.5, onTrack: false, expectedRecommendation: "🚨 Slow down immediately!"),
        (hoursRemaining: 12.0, onTrack: false, expectedRecommendation: "⚠️ Reduce usage to avoid depletion"),
        (hoursRemaining: 48.0, onTrack: true, expectedRecommendation: "✅ On track to last until reset"),
        (hoursRemaining: 36.0, onTrack: false, expectedRecommendation: "💡 Maintain current pace or reduce slightly")
    ])
    func recommendationLogic(hoursRemaining: Double, onTrack: Bool, expectedRecommendation: String) {
        // Given
        let prediction = PredictionEngine.PredictionInfo(
            depletionTime: Date().addingTimeInterval(hoursRemaining * 3600),
            confidence: 80,
            daysRemaining: hoursRemaining / 24,
            hoursRemaining: hoursRemaining,
            recommendedDailyLimit: 1000,
            onTrackForReset: onTrack,
            resetTime: Date().addingTimeInterval(72 * 3600),
            provider: .cursor
        )
        
        // Then
        #expect(prediction.recommendation == expectedRecommendation)
    }
    
    // MARK: - Recommended Daily Limit Tests
    
    @Test("Calculate recommended daily limit")
    func recommendedDailyLimit() {
        // Given
        let provider = ServiceProvider.cursor
        let currentUsage = 20.0
        let limit = 100.0
        let burnRate = BurnRateCalculator.BurnRate(
            ratePerMinute: 0.5,
            ratePerHour: 30.0,
            metric: .spending,
            velocityIndicator: .normal
        )
        
        // When
        let prediction = sut.calculatePrediction(
            for: provider,
            currentUsage: currentUsage,
            limit: limit,
            burnRate: burnRate
        )
        
        // Then
        #expect(prediction.recommendedDailyLimit > 0)
        #expect(prediction.recommendedDailyLimit < limit) // Should be reasonable
    }
    
    // MARK: - Summary Generation Tests
    
    @Test("Prediction summary format")
    func predictionSummary() {
        // Given
        let prediction = PredictionEngine.PredictionInfo(
            depletionTime: Date().addingTimeInterval(24 * 3600),
            confidence: 75,
            daysRemaining: 1.0,
            hoursRemaining: 24.0,
            recommendedDailyLimit: 500.0,
            onTrackForReset: true,
            resetTime: Date().addingTimeInterval(48 * 3600),
            provider: .cursor
        )
        
        // When
        let summary = sut.getPredictionSummary(prediction)
        
        // Then
        #expect(summary.contains("📊 Prediction"))
        #expect(summary.contains("confidence"))
        #expect(summary.contains("Recommended daily limit"))
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle zero limit gracefully")
    func zeroLimit() {
        // Given
        let provider = ServiceProvider.cursor
        let burnRate = BurnRateCalculator.BurnRate(
            ratePerMinute: 1.0,
            ratePerHour: 60.0,
            metric: .spending,
            velocityIndicator: .normal
        )
        
        // When
        let prediction = sut.calculatePrediction(
            for: provider,
            currentUsage: 50.0,
            limit: 0.0,
            burnRate: burnRate
        )
        
        // Then
        #expect(prediction.depletionTime == nil)
        #expect(prediction.daysRemaining == 0)
    }
    
    @Test("Handle usage exceeding limit")
    func usageExceedsLimit() {
        // Given
        let provider = ServiceProvider.cursor
        
        // When
        let prediction = sut.calculatePrediction(
            for: provider,
            currentUsage: 150.0,
            limit: 100.0,
            burnRate: nil
        )
        
        // Then
        #expect(prediction.depletionTime == nil)
        #expect(prediction.hoursRemaining == Double.infinity)
        #expect(prediction.depletionText == "Already depleted")
    }
}

// MARK: - Formatted Output Tests

@Suite("PredictionInfo Formatting Tests")
struct PredictionInfoFormattingTests {
    
    @Test("Depletion text formatting", arguments: [
        (hours: -1.0, expected: "Already depleted"),
        (hours: 0.5, expected: "< 1 hour"),
        (hours: 3.0, expected: "3 hours"),
        (hours: 24.0, expected: "1 day"),
        (hours: 72.0, expected: "3 days")
    ])
    func depletionTextFormatting(hours: Double, expected: String) {
        // Given
        let depletionTime = hours < 0 ? Date().addingTimeInterval(hours * 3600) : Date().addingTimeInterval(hours * 3600)
        let prediction = PredictionEngine.PredictionInfo(
            depletionTime: depletionTime,
            confidence: 80,
            daysRemaining: hours / 24,
            hoursRemaining: hours,
            recommendedDailyLimit: 0,
            onTrackForReset: false,
            resetTime: Date(),
            provider: .cursor
        )
        
        // Then
        #expect(prediction.depletionText == expected)
    }
    
    @Test("Confidence level descriptions", arguments: [
        (85, "High"),
        (65, "Medium"),
        (30, "Low")
    ])
    func confidenceLevelDescriptions(confidence: Int, expectedLevel: String) {
        // Given
        let prediction = PredictionEngine.PredictionInfo(
            depletionTime: nil,
            confidence: confidence,
            daysRemaining: 1,
            hoursRemaining: 24,
            recommendedDailyLimit: 0,
            onTrackForReset: true,
            resetTime: Date(),
            provider: .cursor
        )
        
        // Then
        #expect(prediction.confidenceLevel == expectedLevel)
    }
    
    @Test("Formatted summary includes all components")
    func formattedSummary() {
        // Given
        let prediction = PredictionEngine.PredictionInfo(
            depletionTime: Date().addingTimeInterval(12 * 3600),
            confidence: 85,
            daysRemaining: 0.5,
            hoursRemaining: 12,
            recommendedDailyLimit: 1000,
            onTrackForReset: false,
            resetTime: Date().addingTimeInterval(24 * 3600),
            provider: .claude
        )
        
        // When
        let summary = prediction.formattedSummary
        
        // Then
        #expect(summary.contains("⚠️")) // Warning emoji for depletion
        #expect(summary.contains("85%")) // Confidence
        #expect(summary.contains("12h")) // Time left
        #expect(summary.contains("🔄 Reset:")) // Reset time
        #expect(summary.contains("💡 Daily Limit: 1000")) // Recommended limit
    }
}