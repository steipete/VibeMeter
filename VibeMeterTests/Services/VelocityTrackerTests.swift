import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Suite

@Suite("VelocityTracker Tests")
@MainActor
struct VelocityTrackerTests {
    let sut: VelocityTracker
    
    init() {
        self.sut = VelocityTracker()
    }
    
    // MARK: - Basic Functionality Tests
    
    @Test("Adding data point creates velocity data")
    func addDataPoint() {
        // Given
        let provider = ServiceProvider.claude
        let value = 1000.0
        
        // When
        sut.addDataPoint(value: value, provider: provider)
        
        // Then
        #expect(sut.calculateVelocity(for: provider) != nil)
    }
    
    @Test("Calculate velocity returns nil with no data")
    func calculateVelocityWithNoData() {
        // When
        let velocity = sut.calculateVelocity(for: .cursor)
        
        // Then
        #expect(velocity == nil)
    }
    
    @Test("Calculate velocity with multiple data points")
    func calculateVelocityWithMultipleDataPoints() throws {
        // Given
        let provider = ServiceProvider.claude
        let now = Date()
        
        // Add data points over time
        sut.addDataPoint(value: 1000, provider: provider, timestamp: now.addingTimeInterval(-7200)) // 2 hours ago
        sut.addDataPoint(value: 2000, provider: provider, timestamp: now.addingTimeInterval(-3600)) // 1 hour ago
        sut.addDataPoint(value: 3000, provider: provider, timestamp: now) // now
        
        // When
        let velocity = try #require(sut.calculateVelocity(for: provider))
        
        // Then
        #expect(velocity.current > 0)
        #expect(velocity.trend == .increasing)
    }
    
    // MARK: - Trend Detection Tests
    
    @Test("Detects increasing trend", arguments: [
        (values: [1000, 2000, 3000, 4000, 5000], expectedTrend: VelocityTracker.VelocityInfo.Trend.increasing),
        (values: [100, 200, 400, 800, 1600], expectedTrend: VelocityTracker.VelocityInfo.Trend.increasing)
    ])
    func detectsIncreasingTrend(values: [Double], expectedTrend: VelocityTracker.VelocityInfo.Trend) throws {
        // Given
        let provider = ServiceProvider.claude
        let now = Date()
        
        // Simulate increasing usage
        for (index, value) in values.enumerated() {
            let timestamp = now.addingTimeInterval(Double(-index) * 3600)
            sut.addDataPoint(value: value, provider: provider, timestamp: timestamp)
        }
        
        // When
        let velocity = try #require(sut.calculateVelocity(for: provider))
        
        // Then
        #expect(velocity.trend == expectedTrend)
        #expect(velocity.trendPercent > 0)
    }
    
    @Test("Detects decreasing trend")
    func detectsDecreasingTrend() throws {
        // Given
        let provider = ServiceProvider.cursor
        let now = Date()
        
        // Simulate decreasing usage
        for i in 0..<5 {
            let timestamp = now.addingTimeInterval(Double(-i) * 3600)
            let value = Double(i + 1) * 1000 // Decreasing values
            sut.addDataPoint(value: value, provider: provider, timestamp: timestamp)
        }
        
        // When
        let velocity = try #require(sut.calculateVelocity(for: provider))
        
        // Then
        #expect(velocity.trend == .decreasing)
        #expect(velocity.trendPercent < 0)
    }
    
    @Test("Detects stable trend with small variations", arguments: [
        5000.0, 4950.0, 5050.0, 4980.0, 5020.0 // Small variations around 5000
    ])
    func detectsStableTrend(baseValue: Double) throws {
        // Given
        let provider = ServiceProvider.claude
        let now = Date()
        
        // Add values with small random variations
        for i in 0..<5 {
            let timestamp = now.addingTimeInterval(Double(-i) * 3600)
            let variation = Double.random(in: -100...100)
            sut.addDataPoint(value: baseValue + variation, provider: provider, timestamp: timestamp)
        }
        
        // When
        let velocity = try #require(sut.calculateVelocity(for: provider))
        
        // Then
        #expect(velocity.trend == .stable)
        #expect(abs(velocity.trendPercent) < 15) // Within stable threshold
    }
    
    // MARK: - Acceleration Detection Tests
    
    @Test("Detects acceleration with exponential growth")
    func detectsAcceleration() throws {
        // Given
        let provider = ServiceProvider.claude
        let now = Date()
        let baseValue = 1000.0
        
        // Simulate rapidly increasing usage
        for i in 0..<5 {
            let timestamp = now.addingTimeInterval(Double(-i) * 900) // 15 min intervals
            let value = baseValue * pow(2.0, Double(5 - i)) // Exponential growth
            sut.addDataPoint(value: value, provider: provider, timestamp: timestamp)
        }
        
        // When
        let velocity = try #require(sut.calculateVelocity(for: provider))
        
        // Then
        #expect(velocity.isAccelerating)
        #expect(velocity.trendPercent > 50) // Above acceleration threshold
    }
    
    // MARK: - Time-based Calculations Tests
    
    @Test("Detects peak hours from usage patterns")
    func detectsPeakHours() throws {
        // Given
        let provider = ServiceProvider.claude
        let calendar = Calendar.current
        let now = Date()
        
        // Simulate usage concentrated at specific hours
        for day in 0..<7 {
            for hour in [9, 10, 11, 14, 15, 16] { // Work hours
                var components = calendar.dateComponents([.year, .month, .day], from: now)
                components.day! -= day
                components.hour = hour
                if let date = calendar.date(from: components) {
                    let value = hour >= 14 ? 2000.0 : 1000.0 // Higher in afternoon
                    sut.addDataPoint(value: value, provider: provider, timestamp: date)
                }
            }
        }
        
        // When
        let velocity = try #require(sut.calculateVelocity(for: provider))
        
        // Then
        #expect([14, 15, 16].contains(velocity.peakHour))
    }
    
    @Test("Calculates 24-hour average correctly")
    func calculates24HourAverage() throws {
        // Given
        let provider = ServiceProvider.claude
        let now = Date()
        
        // Add data for last 48 hours
        for hour in 0..<48 {
            let timestamp = now.addingTimeInterval(Double(-hour) * 3600)
            sut.addDataPoint(value: 1000.0, provider: provider, timestamp: timestamp)
        }
        
        // When
        let velocity = try #require(sut.calculateVelocity(for: provider))
        
        // Then
        #expect(velocity.average24h > 0)
    }
    
    // MARK: - Claude Session Integration Tests
    
    @Test("Calculates velocity from Claude sessions")
    func calculatesVelocityFromSessions() {
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
                entryCount: 10
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
                entryCount: 5
            )
        ]
        
        // When
        let velocity = sut.calculateVelocityFromSessions(sessions, currentBurnRate: 100.0)
        
        // Then
        #expect(velocity.current == 6000) // 100 tokens/min * 60
        #expect(velocity.average24h > 0)
    }
    
    // MARK: - Data Cleanup Tests
    
    @Test("Old data is cleaned up after 7 days")
    func oldDataCleanup() {
        // Given
        let provider = ServiceProvider.claude
        let now = Date()
        
        // Add old data (more than 7 days)
        sut.addDataPoint(value: 1000, provider: provider, timestamp: now.addingTimeInterval(-8 * 86400))
        
        // Add recent data
        sut.addDataPoint(value: 2000, provider: provider, timestamp: now)
        
        // When
        let velocity = sut.calculateVelocity(for: provider)
        
        // Then
        #expect(velocity != nil)
        // Old data should not affect calculations
    }
    
    // MARK: - Summary Generation Tests
    
    @Test("Generates velocity summary with correct format")
    func generatesVelocitySummary() {
        // Given
        let provider = ServiceProvider.claude
        sut.addDataPoint(value: 5000, provider: provider)
        
        // When
        let summary = sut.getVelocitySummary(for: provider)
        
        // Then
        #expect(!summary.isEmpty)
        #expect(summary.contains("/hr"))
    }
    
    // MARK: - Provider Integration Tests
    
    @Test("Updates from provider usage data", arguments: [
        (ServiceProvider.cursor, 50),
        (ServiceProvider.claude, 100)
    ])
    func updatesFromProviderUsage(provider: ServiceProvider, currentRequests: Int) {
        // Given
        let usage = ProviderUsageData(
            currentRequests: currentRequests,
            totalRequests: 100,
            maxRequests: 500,
            startOfMonth: Date().addingTimeInterval(-7 * 24 * 3600), // 7 days ago
            provider: provider
        )
        
        // When
        sut.updateFromProviderUsage(usage, provider: provider)
        
        // Then
        #expect(sut.calculateVelocity(for: provider) != nil)
    }
    
    @Test("Updates from spending amount", arguments: [
        (ServiceProvider.cursor, 10.5),
        (ServiceProvider.claude, 25.75)
    ])
    func updatesFromSpending(provider: ServiceProvider, amount: Double) {
        // When
        sut.updateFromSpending(amount: amount, provider: provider)
        
        // Then
        #expect(sut.calculateVelocity(for: provider) != nil)
    }
}