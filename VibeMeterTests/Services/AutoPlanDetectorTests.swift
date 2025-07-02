import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Tags

extension Tag {
    @Tag static var planDetection: Self
    @Tag static var evidence: Self
}

// MARK: - Test Suite

@Suite("AutoPlanDetector Tests", .tags(.planDetection))
@MainActor
struct AutoPlanDetectorTests {
    let sut: AutoPlanDetector
    
    init() {
        self.sut = AutoPlanDetector()
    }
    
    // MARK: - Helper Methods
    
    private func createHistoricalData(days: Int, baseUsage: Double, pattern: UsagePattern = .steady) -> [Date: Double] {
        var data: [Date: Double] = [:]
        let now = Date()
        
        for day in 0..<days {
            let date = now.addingTimeInterval(-Double(day) * 86400)
            let usage: Double
            
            switch pattern {
            case .steady:
                usage = baseUsage * (1.0 - Double(day) * 0.01) // Slight decrease over time
            case .increasing:
                usage = baseUsage * (1.0 + Double(day) * 0.02) // Increasing usage
            case .cyclic:
                usage = baseUsage * (1.0 + sin(Double(day) * 0.5) * 0.3) // Cyclic pattern
            case .reset:
                // Simulate monthly reset
                usage = day % 30 == 0 ? baseUsage * 0.1 : baseUsage * (1.0 - Double(day % 30) * 0.03)
            }
            
            data[date] = max(0, usage)
        }
        
        return data
    }
    
    private enum UsagePattern {
        case steady, increasing, cyclic, reset
    }
    
    // MARK: - Basic Detection Tests
    
    @Test("Detect plan for Claude with typical Pro usage")
    func detectClaudeProPlan() {
        // Given
        let historicalData = createHistoricalData(days: 30, baseUsage: 180_000, pattern: .steady)
        let currentUsage = 150_000.0
        
        // When
        let plan = sut.detectPlan(
            for: .claude,
            currentUsage: currentUsage,
            historicalData: historicalData,
            additionalContext: ["monthlyCost": 20.0]
        )
        
        // Then
        #expect(plan.provider == .claude)
        #expect(plan.planType == .pro || plan.planType == .unknown) // May not have enough evidence
        #expect(plan.confidence > 0)
        #expect(!plan.evidence.isEmpty)
        #expect(plan.resetPattern == .fiveHour) // Claude always uses 5-hour windows
    }
    
    @Test("Detect plan for Cursor with usage patterns")
    func detectCursorPlan() {
        // Given
        let historicalData = createHistoricalData(days: 30, baseUsage: 450, pattern: .reset)
        let currentUsage = 400.0
        
        // When
        let plan = sut.detectPlan(
            for: .cursor,
            currentUsage: currentUsage,
            historicalData: historicalData,
            additionalContext: ["monthlyCost": 20.0]
        )
        
        // Then
        #expect(plan.provider == .cursor)
        #expect(plan.confidence > 0)
        #expect(!plan.evidence.isEmpty)
    }
    
    // MARK: - Evidence Collection Tests
    
    @Test("Collect usage pattern evidence", .tags(.evidence))
    func collectUsagePatternEvidence() {
        // Given
        let steadyData = createHistoricalData(days: 14, baseUsage: 100, pattern: .steady)
        
        // When
        let plan = sut.detectPlan(
            for: .cursor,
            currentUsage: 95,
            historicalData: steadyData
        )
        
        // Then
        let patternEvidence = plan.evidence.filter { $0.type == .usagePattern }
        #expect(!patternEvidence.isEmpty)
        #expect(patternEvidence.first?.value.contains("Consistent") ?? false)
    }
    
    @Test("Detect limit evidence", .tags(.evidence))
    func detectLimitEvidence() {
        // Given
        var historicalData = createHistoricalData(days: 10, baseUsage: 180, pattern: .steady)
        // Add data points near limit
        historicalData[Date().addingTimeInterval(-86400)] = 195.0 // Near 200 limit
        
        // When
        let plan = sut.detectPlan(
            for: .cursor,
            currentUsage: 190,
            historicalData: historicalData
        )
        
        // Then
        let limitEvidence = plan.evidence.filter { $0.type == .limitDetection }
        #expect(!limitEvidence.isEmpty)
    }
    
    @Test("Cost analysis evidence", .tags(.evidence))
    func costAnalysisEvidence() {
        // Given
        let historicalData = createHistoricalData(days: 30, baseUsage: 100, pattern: .steady)
        
        // When
        let plan = sut.detectPlan(
            for: .cursor,
            currentUsage: 90,
            historicalData: historicalData,
            additionalContext: ["monthlyCost": 20.0] // Matches Pro plan
        )
        
        // Then
        let costEvidence = plan.evidence.filter { $0.type == .costAnalysis }
        #expect(!costEvidence.isEmpty)
        #expect(costEvidence.first?.value.contains("$20") ?? false)
    }
    
    // MARK: - Reset Pattern Detection Tests
    
    @Test("Detect monthly reset pattern")
    func detectMonthlyReset() {
        // Given - Create data with monthly resets
        var historicalData: [Date: Double] = [:]
        let now = Date()
        
        // Simulate 3 months of data with resets
        for day in 0..<90 {
            let date = now.addingTimeInterval(-Double(day) * 86400)
            let dayOfMonth = Calendar.current.component(.day, from: date)
            let usage = dayOfMonth == 1 ? 10.0 : 100.0 * (Double(dayOfMonth) / 30.0)
            historicalData[date] = usage
        }
        
        // When
        let plan = sut.detectPlan(
            for: .cursor,
            currentUsage: 50,
            historicalData: historicalData
        )
        
        // Then
        let resetEvidence = plan.evidence.filter { $0.type == .resetTiming }
        #expect(!resetEvidence.isEmpty)
        #expect(plan.resetPattern == .monthly)
    }
    
    @Test("Claude always has 5-hour reset", .tags(.claude))
    func claudeFiveHourReset() {
        // Given
        let historicalData = createHistoricalData(days: 7, baseUsage: 50_000, pattern: .cyclic)
        
        // When
        let plan = sut.detectPlan(
            for: .claude,
            currentUsage: 45_000,
            historicalData: historicalData
        )
        
        // Then
        #expect(plan.resetPattern == .fiveHour)
        let resetEvidence = plan.evidence.filter { $0.type == .resetTiming }
        #expect(resetEvidence.first?.value.contains("5-hour") ?? false)
    }
    
    // MARK: - Cached Plan Tests
    
    @Test("Get cached plan")
    func getCachedPlan() {
        // Given
        let historicalData = createHistoricalData(days: 7, baseUsage: 100, pattern: .steady)
        let detectedPlan = sut.detectPlan(
            for: .cursor,
            currentUsage: 95,
            historicalData: historicalData
        )
        
        // When
        let cachedPlan = sut.getCachedPlan(for: .cursor)
        
        // Then
        #expect(cachedPlan != nil)
        #expect(cachedPlan?.provider == detectedPlan.provider)
        #expect(cachedPlan?.planType == detectedPlan.planType)
    }
    
    // MARK: - Plan Summary Tests
    
    @Test("Plan summary format")
    func planSummaryFormat() {
        // Given
        let plan = AutoPlanDetector.DetectedPlan(
            provider: .claude,
            planType: .pro,
            confidence: 85,
            evidence: [],
            estimatedLimit: 200_000,
            estimatedCost: 20,
            resetPattern: .fiveHour,
            detectedAt: Date()
        )
        
        // When
        let summary = plan.summary
        
        // Then
        #expect(summary.contains("📋"))
        #expect(summary.contains("Pro"))
        #expect(summary.contains("85%"))
        #expect(summary.contains("$20.00"))
        #expect(summary.contains("200K")) // Token format
    }
    
    // MARK: - UI Integration Tests
    
    @Test("Confidence indicator", arguments: [
        (85.0, "🟢"),
        (70.0, "🟡"),
        (50.0, "🔴")
    ])
    func confidenceIndicator(confidence: Double, expectedIndicator: String) {
        // Given
        let plan = AutoPlanDetector.DetectedPlan(
            provider: .cursor,
            planType: .pro,
            confidence: confidence,
            evidence: [],
            estimatedLimit: 500,
            estimatedCost: 20,
            resetPattern: .monthly,
            detectedAt: Date()
        )
        
        // Then
        #expect(plan.confidenceIndicator == expectedIndicator)
    }
    
    @Test("Plan colors", arguments: [AutoPlanDetector.DetectedPlan.PlanType.free, .basic, .pro, .team, .enterprise, .unknown])
    func planColors(planType: AutoPlanDetector.DetectedPlan.PlanType) {
        // Given
        let plan = AutoPlanDetector.DetectedPlan(
            provider: .cursor,
            planType: planType,
            confidence: 80,
            evidence: [],
            estimatedLimit: 100,
            estimatedCost: 0,
            resetPattern: .daily,
            detectedAt: Date()
        )
        
        // When
        let color = plan.planColor
        
        // Then
        #expect(color != .clear) // Should have a defined color
    }
    
    @Test("Plan features")
    func planFeatures() {
        // Given
        let planTypes: [AutoPlanDetector.DetectedPlan.PlanType] = [.free, .basic, .pro, .team, .enterprise]
        
        for planType in planTypes {
            let plan = AutoPlanDetector.DetectedPlan(
                provider: .cursor,
                planType: planType,
                confidence: 80,
                evidence: [],
                estimatedLimit: 100,
                estimatedCost: 20,
                resetPattern: .monthly,
                detectedAt: Date()
            )
            
            // When
            let features = plan.features
            
            // Then
            #expect(!features.isEmpty)
            
            // Verify plan-specific features
            switch planType {
            case .free:
                #expect(features.contains { $0.contains("Limited") })
            case .team:
                #expect(features.contains { $0.contains("Team") || $0.contains("collaboration") })
            case .enterprise:
                #expect(features.contains { $0.contains("Custom") || $0.contains("SLA") })
            default:
                break
            }
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle empty historical data")
    func handleEmptyHistoricalData() {
        // When
        let plan = sut.detectPlan(
            for: .cursor,
            currentUsage: 50,
            historicalData: [:]
        )
        
        // Then
        #expect(plan.confidence < 60) // Low confidence without history
        #expect(plan.evidence.count > 0) // Should still have some evidence
    }
    
    @Test("Handle zero usage")
    func handleZeroUsage() {
        // Given
        let historicalData = createHistoricalData(days: 7, baseUsage: 0, pattern: .steady)
        
        // When
        let plan = sut.detectPlan(
            for: .cursor,
            currentUsage: 0,
            historicalData: historicalData
        )
        
        // Then
        #expect(plan.planType == .free || plan.planType == .unknown)
    }
}

// MARK: - Integration Tests

@Suite("AutoPlanDetector Integration Tests")
@MainActor
struct AutoPlanDetectorIntegrationTests {
    
    @Test("Detect all plans with orchestrator")
    func detectAllPlans() async {
        // Given
        let detector = AutoPlanDetector()
        // Create test dependencies
        let settingsManager = MockSettingsManager()
        let exchangeRateManager = ExchangeRateManagerMock()
        let notificationManager = NotificationManagerMock()
        let providerFactory = ProviderFactory(settingsManager: settingsManager)
        let loginManager = MultiProviderLoginManager(providerFactory: providerFactory)
        let spendingData = MultiProviderSpendingData()
        let userSessionData = MultiProviderUserSessionData()
        let currencyData = CurrencyData()
        
        let orchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: settingsManager,
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            loginManager: loginManager,
            spendingData: spendingData,
            userSessionData: userSessionData,
            currencyData: currencyData
        )
        
        // When
        let plans = await detector.detectAllPlans(orchestrator: orchestrator)
        
        // Then
        #expect(!plans.isEmpty)
        for provider in ServiceProvider.allCases {
            #expect(plans[provider] != nil)
        }
    }
}