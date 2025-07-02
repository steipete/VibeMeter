import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Tags

extension Tag {
    @Tag static var burnRate: Self
    @Tag static var analytics: Self
    @Tag static var anomaly: Self
}

// MARK: - Test Suite

@Suite("EnhancedBurnRateCalculator Tests", .tags(.burnRate, .analytics))
@MainActor
struct EnhancedBurnRateCalculatorTests {
    let sut: EnhancedBurnRateCalculator
    
    init() {
        self.sut = EnhancedBurnRateCalculator()
    }
    
    // MARK: - Helper Methods
    
    private func createMockSessions(count: Int, baseValue: Double = 1000.0) -> [BurnRateCalculator.UsageSession] {
        let now = Date()
        return (0..<count).map { i in
            let startTime = now.addingTimeInterval(Double(-i) * 3600)
            let endTime = startTime.addingTimeInterval(3000) // 50 min sessions
            return BurnRateCalculator.UsageSession(
                startTime: startTime,
                endTime: endTime,
                value: baseValue + Double.random(in: -200...200),
                provider: .claude,
                metric: .tokens
            )
        }
    }
    
    // MARK: - Basic Calculation Tests
    
    @Test("Calculate enhanced burn rate with sessions")
    func calculateEnhancedBurnRate() throws {
        // Given
        let sessions = createMockSessions(count: 5)
        
        // When
        let result = sut.calculateEnhancedBurnRate(
            sessions: sessions,
            provider: .claude
        )
        
        // Then
        let burnRate = try #require(result)
        #expect(burnRate.ratePerHour > 0)
        #expect(burnRate.ratePerMinute == burnRate.ratePerHour / 60)
        #expect(burnRate.metric == .tokens)
        #expect(burnRate.confidence > 0)
        #expect(burnRate.confidence <= 100)
    }
    
    @Test("Calculate with no sessions returns nil")
    func calculateWithNoSessions() {
        // When
        let result = sut.calculateEnhancedBurnRate(
            sessions: [],
            provider: .claude
        )
        
        // Then
        #expect(result == nil)
    }
    
    // MARK: - Trend Detection Tests
    
    @Test("Detect accelerating trend")
    func detectAcceleratingTrend() throws {
        // Given - Create sessions with increasing values
        let now = Date()
        let sessions = (0..<5).map { i in
            let startTime = now.addingTimeInterval(Double(-i) * 1800)
            let value = 1000.0 * pow(1.5, Double(5 - i)) // Exponential growth
            return BurnRateCalculator.UsageSession(
                startTime: startTime,
                endTime: startTime.addingTimeInterval(1500),
                value: value,
                provider: .claude,
                metric: .tokens
            )
        }
        
        // When
        let result = try #require(sut.calculateEnhancedBurnRate(
            sessions: sessions,
            provider: .claude
        ))
        
        // Then
        #expect(result.trend == EnhancedBurnRateCalculator.EnhancedBurnRate.Trend.accelerating)
        #expect(result.acceleration > 0)
    }
    
    @Test("Detect steady trend")
    func detectSteadyTrend() throws {
        // Given - Create sessions with consistent values
        let sessions = createMockSessions(count: 5, baseValue: 1000.0).map { session in
            // Override with consistent values
            BurnRateCalculator.UsageSession(
                startTime: session.startTime,
                endTime: session.endTime,
                value: 1000.0,
                provider: session.provider,
                metric: session.metric
            )
        }
        
        // When
        let result = try #require(sut.calculateEnhancedBurnRate(
            sessions: sessions,
            provider: .claude
        ))
        
        // Then
        #expect(result.trend == EnhancedBurnRateCalculator.EnhancedBurnRate.Trend.steady)
        #expect(abs(result.acceleration) < 0.1)
    }
    
    // MARK: - Time Pattern Analysis Tests
    
    @Test("Detect peak hours")
    func detectPeakHours() throws {
        // Given - Create sessions concentrated in specific hours
        let calendar = Calendar.current
        let now = Date()
        var sessions: [BurnRateCalculator.UsageSession] = []
        
        for day in 0..<7 {
            for hour in [9, 10, 14, 15, 16] { // Work hours with afternoon peak
                var components = calendar.dateComponents([Calendar.Component.year, Calendar.Component.month, Calendar.Component.day], from: now)
                components.day! -= day
                components.hour = hour
                
                if let date = calendar.date(from: components) {
                    let value = hour >= 14 ? 2000.0 : 1000.0 // Higher in afternoon
                    sessions.append(BurnRateCalculator.UsageSession(
                        startTime: date,
                        endTime: date.addingTimeInterval(3000),
                        value: value,
                        provider: .claude,
                        metric: .tokens
                    ))
                }
            }
        }
        
        // When
        let result = try #require(sut.calculateEnhancedBurnRate(
            sessions: sessions,
            provider: .claude
        ))
        
        // Then
        #expect(!result.peakHours.isEmpty)
        #expect(result.peakHours.contains { [14, 15, 16].contains($0) })
        #expect(!result.quietHours.isEmpty)
    }
    
    // MARK: - Session Pattern Tests
    
    @Test("Calculate session metrics")
    func calculateSessionMetrics() throws {
        // Given
        let sessions = createMockSessions(count: 10)
        
        // When
        let result = try #require(sut.calculateEnhancedBurnRate(
            sessions: sessions,
            provider: .claude
        ))
        
        // Then
        #expect(result.averageSessionDuration > 0)
        #expect(result.sessionsPerHour > 0)
        #expect(result.burstiness >= 0)
        #expect(result.burstiness <= 1)
    }
    
    @Test("Detect bursty usage pattern")
    func detectBurstyPattern() throws {
        // Given - Create sessions with irregular gaps
        let now = Date()
        var sessions: [BurnRateCalculator.UsageSession] = []
        
        // Add bursts of activity
        for burst in 0..<3 {
            let burstStart = now.addingTimeInterval(Double(-burst) * 10800) // 3 hour gaps
            for i in 0..<3 {
                let start = burstStart.addingTimeInterval(Double(i) * 300) // 5 min gaps within burst
                sessions.append(BurnRateCalculator.UsageSession(
                    startTime: start,
                    endTime: start.addingTimeInterval(240),
                    value: 1000.0,
                    provider: .claude,
                    metric: .tokens
                ))
            }
        }
        
        // When
        let result = try #require(sut.calculateEnhancedBurnRate(
            sessions: sessions,
            provider: .claude
        ))
        
        // Then
        #expect(result.burstiness > 0.5) // Should detect bursty pattern
    }
    
    // MARK: - Claude Session Integration Tests
    
    @Test("Calculate from Claude sessions", .tags(.claude))
    func calculateFromClaudeSessions() throws {
        // Given
        let sessions = [
            ClaudeSessionTracker.Session(
                id: "1",
                startTime: Date().addingTimeInterval(-7200),
                actualEndTime: Date().addingTimeInterval(-3600),
                totalTokens: 10000,
                totalCost: 0.5,
                models: ["claude-3"],
                isActive: false,
                isGap: false,
                entryCount: 50
            ),
            ClaudeSessionTracker.Session(
                id: "2",
                startTime: Date().addingTimeInterval(-3600),
                actualEndTime: nil,
                totalTokens: 5000,
                totalCost: 0.25,
                models: ["claude-3"],
                isActive: true,
                isGap: false,
                entryCount: 25
            )
        ]
        
        // When
        let result = sut.calculateClaudeEnhancedBurnRate(sessions: sessions)
        
        // Then
        #expect(result != nil)
        #expect(result?.metric == .tokens)
    }
    
    // MARK: - Anomaly Detection Tests
    
    @Test("Detect unusually high rate anomaly", .tags(.anomaly))
    func detectHighRateAnomaly() {
        // Given
        let currentRate = EnhancedBurnRateCalculator.EnhancedBurnRate(
            ratePerMinute: 1000,
            ratePerHour: 60000, // Very high rate
            metric: .tokens,
            trend: .accelerating,
            acceleration: 0.5,
            volatility: 20,
            confidence: 80,
            hourlyPattern: [:],
            peakHours: [14, 15],
            quietHours: [2, 3],
            averageSessionDuration: 3600,
            sessionsPerHour: 2,
            burstiness: 0.3
        )
        
        // When
        let anomalies = sut.detectAnomalies(currentRate: currentRate, provider: .claude)
        
        // Then
        #expect(!anomalies.isEmpty)
        #expect(anomalies.contains { anomaly in
            if case .unusuallyHighRate = anomaly {
                return true
            }
            return false
        })
    }
    
    @Test("Detect unusual burst pattern anomaly", .tags(.anomaly))
    func detectBurstPatternAnomaly() {
        // Given
        let currentRate = EnhancedBurnRateCalculator.EnhancedBurnRate(
            ratePerMinute: 100,
            ratePerHour: 6000,
            metric: .tokens,
            trend: .steady,
            acceleration: 0,
            volatility: 10,
            confidence: 70,
            hourlyPattern: [:],
            peakHours: [14],
            quietHours: [3],
            averageSessionDuration: 1800,
            sessionsPerHour: 5,
            burstiness: 0.9 // Very bursty
        )
        
        // When
        let anomalies = sut.detectAnomalies(currentRate: currentRate, provider: .claude)
        
        // Then
        #expect(anomalies.contains { anomaly in
            if case .unusualBurstPattern = anomaly {
                return true
            }
            return false
        })
    }
    
    // MARK: - Forecast Tests
    
    @Test("Forecast burn rate")
    func forecastBurnRate() {
        // Given
        let currentRate = EnhancedBurnRateCalculator.EnhancedBurnRate(
            ratePerMinute: 100,
            ratePerHour: 6000,
            metric: .tokens,
            trend: .steady,
            acceleration: 0.1,
            volatility: 15,
            confidence: 75,
            hourlyPattern: [14: 8000, 15: 9000, 9: 5000],
            peakHours: [14, 15],
            quietHours: [2, 3],
            averageSessionDuration: 3600,
            sessionsPerHour: 1.5,
            burstiness: 0.4
        )
        
        // When
        let forecast = sut.forecastBurnRate(
            provider: .claude,
            currentRate: currentRate,
            hours: 6
        )
        
        // Then
        #expect(forecast.count == 6)
        #expect(forecast.keys.allSatisfy { $0 > Date() })
        #expect(forecast.values.allSatisfy { $0 >= 0 })
    }
    
    // MARK: - Formatted Output Tests
    
    @Test("Formatted analysis output")
    func formattedAnalysis() {
        // Given
        let burnRate = EnhancedBurnRateCalculator.EnhancedBurnRate(
            ratePerMinute: 100,
            ratePerHour: 6000,
            metric: .tokens,
            trend: .accelerating,
            acceleration: 0.3,
            volatility: 20,
            confidence: 85,
            hourlyPattern: [:],
            peakHours: [14, 15, 16],
            quietHours: [2, 3, 4],
            averageSessionDuration: 3600,
            sessionsPerHour: 2.5,
            burstiness: 0.8
        )
        
        // When
        let analysis = burnRate.formattedAnalysis
        
        // Then
        #expect(analysis.contains("📊"))
        #expect(analysis.contains("6K/hr")) // Formatted rate
        #expect(analysis.contains("85%")) // Confidence
        #expect(analysis.contains("14, 15, 16")) // Peak hours
        #expect(analysis.contains("Bursty")) // Pattern
    }
    
    @Test("Visual representation")
    func visualRepresentation() {
        // Given
        let burnRate = EnhancedBurnRateCalculator.EnhancedBurnRate(
            ratePerMinute: 100,
            ratePerHour: 6000,
            metric: .tokens,
            trend: .steady,
            acceleration: 0,
            volatility: 10,
            confidence: 70,
            hourlyPattern: [:],
            peakHours: [],
            quietHours: [],
            averageSessionDuration: 3600,
            sessionsPerHour: 1,
            burstiness: 0.3
        )
        
        // When
        let visual = burnRate.visualRepresentation
        
        // Then
        #expect(visual.contains("▮") || visual.contains("▯")) // Progress bars
        #expect(visual.contains(burnRate.trend.rawValue)) // Trend emoji
    }
    
    @Test("Recommended action based on trend", arguments: [
        (EnhancedBurnRateCalculator.EnhancedBurnRate.Trend.accelerating, 80, "slowing down"),
        (EnhancedBurnRateCalculator.EnhancedBurnRate.Trend.erratic, 70, "erratic"),
        (EnhancedBurnRateCalculator.EnhancedBurnRate.Trend.decelerating, 60, "decreasing"),
        (EnhancedBurnRateCalculator.EnhancedBurnRate.Trend.steady, 50, "steady")
    ])
    func recommendedAction(trend: EnhancedBurnRateCalculator.EnhancedBurnRate.Trend, confidence: Double, expectedKeyword: String) {
        // Given
        let burnRate = EnhancedBurnRateCalculator.EnhancedBurnRate(
            ratePerMinute: 100,
            ratePerHour: 6000,
            metric: .tokens,
            trend: trend,
            acceleration: 0.2,
            volatility: 15,
            confidence: confidence,
            hourlyPattern: [:],
            peakHours: [],
            quietHours: [],
            averageSessionDuration: 3600,
            sessionsPerHour: 1,
            burstiness: 0.5
        )
        
        // When
        let action = burnRate.recommendedAction
        
        // Then
        #expect(action.lowercased().contains(expectedKeyword))
    }
}

// MARK: - Anomaly Type Tests

@Suite("Anomaly Type Tests", .tags(.anomaly))
struct AnomalyTypeTests {
    
    @Test("Anomaly descriptions")
    func anomalyDescriptions() {
        // Given
        let anomalies: [EnhancedBurnRateCalculator.AnomalyType] = [
            .unusuallyHighRate(current: 10000, expected: 5000),
            .unusualBurstPattern,
            .activityAtUnusualTime(hour: 3),
            .rapidAcceleration(rate: 150)
        ]
        
        // Then
        for anomaly in anomalies {
            let description = anomaly.description
            #expect(description.contains("⚠️"))
            #expect(!description.isEmpty)
        }
    }
}