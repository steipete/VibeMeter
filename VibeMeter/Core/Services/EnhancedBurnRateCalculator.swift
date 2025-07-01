import Foundation
import os.log

/// Enhanced burn rate calculator with advanced features from ccseva
@MainActor
public final class EnhancedBurnRateCalculator: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "EnhancedBurnRate")
    
    // MARK: - Types
    
    /// Enhanced burn rate with detailed analytics
    public struct EnhancedBurnRate: Sendable, Codable {
        // Core metrics
        public let ratePerMinute: Double
        public let ratePerHour: Double
        public let metric: BurnRateCalculator.MetricType
        
        // Advanced analytics
        public let trend: Trend
        public let acceleration: Double  // Rate of change
        public let volatility: Double    // Standard deviation
        public let confidence: Double    // 0-100%
        
        // Time-based patterns
        public let hourlyPattern: [Int: Double]  // Hour -> average rate
        public let peakHours: [Int]             // Top 3 peak hours
        public let quietHours: [Int]            // Top 3 quiet hours
        
        // Session-aware metrics
        public let averageSessionDuration: TimeInterval
        public let sessionsPerHour: Double
        public let burstiness: Double  // 0-1, how bursty vs steady
        
        public enum Trend: String, Sendable, Codable {
            case accelerating = "📈"
            case steady = "➡️"
            case decelerating = "📉"
            case erratic = "🎢"
        }
        
        public var formattedAnalysis: String {
            """
            📊 Burn Rate Analysis
            Rate: \(formatRate(ratePerHour))/hr \(trend.rawValue)
            Confidence: \(Int(confidence))%
            Peak Hours: \(peakHours.map(String.init).joined(separator: ", "))
            Sessions: \(String(format: "%.1f", sessionsPerHour))/hr
            Pattern: \(burstiness > 0.7 ? "Bursty" : "Steady")
            """
        }
        
        private func formatRate(_ rate: Double) -> String {
            if rate >= 1_000_000 {
                return String(format: "%.1fM", rate / 1_000_000)
            } else if rate >= 1_000 {
                return String(format: "%.1fK", rate / 1_000)
            } else {
                return String(format: "%.0f", rate)
            }
        }
    }
    
    /// Historical data point for trend analysis
    private struct HistoricalPoint: Sendable {
        let timestamp: Date
        let rate: Double
        let sessionCount: Int
    }
    
    // MARK: - Properties
    
    private var historicalData: [ServiceProvider: [HistoricalPoint]] = [:]
    private let maxHistoryDays = 30
    
    // MARK: - Public Methods
    
    /// Calculate enhanced burn rate with full analytics
    public func calculateEnhancedBurnRate(
        sessions: [BurnRateCalculator.UsageSession],
        provider: ServiceProvider,
        currentTime: Date = Date()
    ) -> EnhancedBurnRate? {
        // Calculate basic burn rate
        let basicCalculator = BurnRateCalculator()
        guard let basicRate = basicCalculator.calculateHourlyBurnRate(
            sessions: sessions,
            currentTime: currentTime
        ) else { return nil }
        
        // Calculate advanced metrics
        let trend = calculateTrend(sessions: sessions, currentRate: basicRate.ratePerHour)
        let acceleration = calculateAcceleration(sessions: sessions)
        let volatility = calculateVolatility(sessions: sessions)
        let confidence = calculateConfidence(sessions: sessions)
        
        // Calculate time patterns
        let (hourlyPattern, peakHours, quietHours) = analyzeTimePatterns(sessions: sessions)
        
        // Calculate session metrics
        let (avgDuration, sessionsPerHour, burstiness) = analyzeSessionPatterns(sessions: sessions)
        
        // Store historical data
        updateHistoricalData(provider: provider, rate: basicRate.ratePerHour, sessionCount: sessions.count)
        
        return EnhancedBurnRate(
            ratePerMinute: basicRate.ratePerMinute,
            ratePerHour: basicRate.ratePerHour,
            metric: basicRate.metric,
            trend: trend,
            acceleration: acceleration,
            volatility: volatility,
            confidence: confidence,
            hourlyPattern: hourlyPattern,
            peakHours: peakHours,
            quietHours: quietHours,
            averageSessionDuration: avgDuration,
            sessionsPerHour: sessionsPerHour,
            burstiness: burstiness
        )
    }
    
    /// Calculate burn rate specifically for Claude sessions
    public func calculateClaudeEnhancedBurnRate(
        sessions: [ClaudeSessionTracker.Session],
        currentTime: Date = Date()
    ) -> EnhancedBurnRate? {
        // Convert Claude sessions to usage sessions
        let usageSessions = sessions.compactMap { session -> BurnRateCalculator.UsageSession? in
            guard session.totalTokens > 0 else { return nil }
            
            return BurnRateCalculator.UsageSession(
                startTime: session.startTime,
                endTime: session.effectiveEndTime,
                value: Double(session.totalTokens),
                provider: .claude,
                metric: .tokens
            )
        }
        
        return calculateEnhancedBurnRate(
            sessions: usageSessions,
            provider: .claude,
            currentTime: currentTime
        )
    }
    
    /// Get burn rate forecast for the next N hours
    public func forecastBurnRate(
        provider: ServiceProvider,
        currentRate: EnhancedBurnRate,
        hours: Int = 24
    ) -> [Date: Double] {
        var forecast: [Date: Double] = [:]
        let calendar = Calendar.current
        let now = Date()
        
        // Use historical patterns and current trend
        let historicalAverage = getHistoricalAverage(for: provider)
        let trendMultiplier = getTrendMultiplier(currentRate.trend, currentRate.acceleration)
        
        for hour in 0..<hours {
            let forecastTime = now.addingTimeInterval(Double(hour) * 3600)
            let hourOfDay = calendar.component(.hour, from: forecastTime)
            
            // Get historical pattern for this hour
            let hourlyMultiplier = currentRate.hourlyPattern[hourOfDay] ?? 1.0
            
            // Calculate forecasted rate
            let baseRate = (currentRate.ratePerHour + historicalAverage) / 2
            let forecastedRate = baseRate * hourlyMultiplier * trendMultiplier
            
            // Add some uncertainty based on volatility
            let uncertainty = forecastedRate * (currentRate.volatility / 100)
            let finalRate = forecastedRate + (Double.random(in: -uncertainty...uncertainty))
            
            forecast[forecastTime] = max(0, finalRate)
        }
        
        return forecast
    }
    
    /// Detect anomalies in burn rate
    public func detectAnomalies(
        currentRate: EnhancedBurnRate,
        provider: ServiceProvider
    ) -> [AnomalyType] {
        var anomalies: [AnomalyType] = []
        
        // Get historical baseline
        let historicalAverage = getHistoricalAverage(for: provider)
        let historicalStdDev = getHistoricalStandardDeviation(for: provider)
        
        // Check for rate anomalies
        if currentRate.ratePerHour > historicalAverage + (3 * historicalStdDev) {
            anomalies.append(.unusuallyHighRate(
                current: currentRate.ratePerHour,
                expected: historicalAverage
            ))
        }
        
        // Check for pattern anomalies
        if currentRate.burstiness > 0.8 && getHistoricalBurstiness(for: provider) < 0.5 {
            anomalies.append(.unusualBurstPattern)
        }
        
        // Check for time anomalies
        let currentHour = Calendar.current.component(.hour, from: Date())
        if currentRate.quietHours.contains(currentHour) && 
           currentRate.ratePerHour > historicalAverage * 2 {
            anomalies.append(.activityAtUnusualTime(hour: currentHour))
        }
        
        // Check for acceleration anomalies
        if abs(currentRate.acceleration) > historicalAverage * 0.5 {
            anomalies.append(.rapidAcceleration(rate: currentRate.acceleration))
        }
        
        return anomalies
    }
    
    public enum AnomalyType: Sendable {
        case unusuallyHighRate(current: Double, expected: Double)
        case unusualBurstPattern
        case activityAtUnusualTime(hour: Int)
        case rapidAcceleration(rate: Double)
        
        public var description: String {
            switch self {
            case .unusuallyHighRate(let current, let expected):
                return "⚠️ Unusually high rate: \(Int(current)) vs expected \(Int(expected))"
            case .unusualBurstPattern:
                return "⚠️ Unusual burst pattern detected"
            case .activityAtUnusualTime(let hour):
                return "⚠️ High activity at unusual time: \(hour):00"
            case .rapidAcceleration(let rate):
                return "⚠️ Rapid acceleration: \(Int(rate))%"
            }
        }
    }
    
    // MARK: - Private Analysis Methods
    
    private func calculateTrend(
        sessions: [BurnRateCalculator.UsageSession],
        currentRate: Double
    ) -> EnhancedBurnRate.Trend {
        guard sessions.count >= 3 else { return .steady }
        
        // Calculate rates for different time windows
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        let recentSessions = sessions.filter { $0.startTime >= oneHourAgo }
        let olderSessions = sessions.filter { 
            $0.startTime >= twoHoursAgo && $0.startTime < oneHourAgo 
        }
        
        guard !recentSessions.isEmpty && !olderSessions.isEmpty else { return .steady }
        
        let recentRate = calculateAverageRate(recentSessions)
        let olderRate = calculateAverageRate(olderSessions)
        
        let change = (recentRate - olderRate) / max(olderRate, 1)
        
        // Determine trend based on change percentage
        if change > 0.5 { return .accelerating }
        if change < -0.5 { return .decelerating }
        if abs(change) > 0.3 { return .erratic }
        return .steady
    }
    
    private func calculateAcceleration(sessions: [BurnRateCalculator.UsageSession]) -> Double {
        guard sessions.count >= 3 else { return 0 }
        
        // Calculate rate changes over time
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        var rateChanges: [Double] = []
        
        for i in 1..<sortedSessions.count {
            let prevRate = sortedSessions[i-1].value / max(sortedSessions[i-1].duration, 60)
            let currRate = sortedSessions[i].value / max(sortedSessions[i].duration, 60)
            let change = (currRate - prevRate) / max(prevRate, 1)
            rateChanges.append(change)
        }
        
        return rateChanges.isEmpty ? 0 : rateChanges.reduce(0, +) / Double(rateChanges.count)
    }
    
    private func calculateVolatility(sessions: [BurnRateCalculator.UsageSession]) -> Double {
        guard sessions.count >= 2 else { return 0 }
        
        let rates = sessions.map { $0.value / max($0.duration / 3600, 0.1) }
        let average = rates.reduce(0, +) / Double(rates.count)
        
        let squaredDifferences = rates.map { pow($0 - average, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(rates.count)
        let stdDev = sqrt(variance)
        
        // Return as percentage of average
        return average > 0 ? (stdDev / average) * 100 : 0
    }
    
    private func calculateConfidence(sessions: [BurnRateCalculator.UsageSession]) -> Double {
        var confidence = 50.0 // Base confidence
        
        // More sessions = higher confidence
        if sessions.count >= 10 { confidence += 20 }
        else if sessions.count >= 5 { confidence += 10 }
        
        // Recent data = higher confidence
        let recentSessions = sessions.filter { 
            $0.startTime >= Date().addingTimeInterval(-1800) // Last 30 min
        }
        if !recentSessions.isEmpty { confidence += 15 }
        
        // Consistent patterns = higher confidence
        let volatility = calculateVolatility(sessions: sessions)
        if volatility < 20 { confidence += 15 }
        else if volatility > 50 { confidence -= 10 }
        
        return min(95, max(10, confidence))
    }
    
    private func analyzeTimePatterns(
        sessions: [BurnRateCalculator.UsageSession]
    ) -> (pattern: [Int: Double], peak: [Int], quiet: [Int]) {
        let calendar = Calendar.current
        var hourlyTotals: [Int: Double] = [:]
        var hourlyCounts: [Int: Int] = [:]
        
        // Aggregate by hour
        for session in sessions {
            let hour = calendar.component(.hour, from: session.startTime)
            hourlyTotals[hour, default: 0] += session.value
            hourlyCounts[hour, default: 0] += 1
        }
        
        // Calculate averages
        var hourlyPattern: [Int: Double] = [:]
        for (hour, total) in hourlyTotals {
            if let count = hourlyCounts[hour], count > 0 {
                hourlyPattern[hour] = total / Double(count)
            }
        }
        
        // Find peak and quiet hours
        let sortedHours = hourlyPattern.sorted { $0.value > $1.value }
        let peakHours = Array(sortedHours.prefix(3).map(\.key))
        let quietHours = Array(sortedHours.suffix(3).map(\.key))
        
        return (hourlyPattern, peakHours, quietHours)
    }
    
    private func analyzeSessionPatterns(
        sessions: [BurnRateCalculator.UsageSession]
    ) -> (avgDuration: TimeInterval, sessionsPerHour: Double, burstiness: Double) {
        guard !sessions.isEmpty else { return (0, 0, 0) }
        
        // Average duration
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let avgDuration = totalDuration / Double(sessions.count)
        
        // Sessions per hour
        let timeSpan = sessions.map(\.startTime).max()!.timeIntervalSince(
            sessions.map(\.startTime).min()!
        )
        let sessionsPerHour = Double(sessions.count) / max(timeSpan / 3600, 1)
        
        // Burstiness (0-1, based on inter-session gaps)
        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        var gaps: [TimeInterval] = []
        
        for i in 1..<sortedSessions.count {
            let gap = sortedSessions[i].startTime.timeIntervalSince(sortedSessions[i-1].endTime)
            gaps.append(gap)
        }
        
        if gaps.isEmpty {
            return (avgDuration, sessionsPerHour, 0)
        }
        
        let avgGap = gaps.reduce(0, +) / Double(gaps.count)
        let gapVariance = gaps.map { pow($0 - avgGap, 2) }.reduce(0, +) / Double(gaps.count)
        let gapStdDev = sqrt(gapVariance)
        
        // High variance in gaps = bursty, low variance = steady
        let burstiness = min(1.0, gapStdDev / max(avgGap, 1))
        
        return (avgDuration, sessionsPerHour, burstiness)
    }
    
    private func calculateAverageRate(_ sessions: [BurnRateCalculator.UsageSession]) -> Double {
        let totalValue = sessions.reduce(0) { $0 + $1.value }
        let totalHours = sessions.reduce(0) { $0 + $1.duration } / 3600
        return totalHours > 0 ? totalValue / totalHours : 0
    }
    
    // MARK: - Historical Data Management
    
    private func updateHistoricalData(provider: ServiceProvider, rate: Double, sessionCount: Int) {
        let point = HistoricalPoint(
            timestamp: Date(),
            rate: rate,
            sessionCount: sessionCount
        )
        
        historicalData[provider, default: []].append(point)
        
        // Clean old data
        let cutoff = Date().addingTimeInterval(-Double(maxHistoryDays) * 86400)
        historicalData[provider]?.removeAll { $0.timestamp < cutoff }
    }
    
    private func getHistoricalAverage(for provider: ServiceProvider) -> Double {
        let points = historicalData[provider] ?? []
        guard !points.isEmpty else { return 0 }
        
        let totalRate = points.reduce(0) { $0 + $1.rate }
        return totalRate / Double(points.count)
    }
    
    private func getHistoricalStandardDeviation(for provider: ServiceProvider) -> Double {
        let points = historicalData[provider] ?? []
        guard points.count >= 2 else { return 0 }
        
        let average = getHistoricalAverage(for: provider)
        let squaredDifferences = points.map { pow($0.rate - average, 2) }
        let variance = squaredDifferences.reduce(0, +) / Double(points.count)
        
        return sqrt(variance)
    }
    
    private func getHistoricalBurstiness(for provider: ServiceProvider) -> Double {
        // Simplified: use session count variance as proxy for burstiness
        let points = historicalData[provider] ?? []
        guard points.count >= 2 else { return 0.5 }
        
        let counts = points.map { Double($0.sessionCount) }
        let avgCount = counts.reduce(0, +) / Double(counts.count)
        let variance = counts.map { pow($0 - avgCount, 2) }.reduce(0, +) / Double(counts.count)
        
        return min(1.0, sqrt(variance) / max(avgCount, 1))
    }
    
    private func getTrendMultiplier(_ trend: EnhancedBurnRate.Trend, _ acceleration: Double) -> Double {
        switch trend {
        case .accelerating:
            return 1.0 + (acceleration * 0.1)
        case .decelerating:
            return 1.0 - (abs(acceleration) * 0.1)
        case .erratic:
            return 1.0 + (Double.random(in: -0.2...0.2))
        case .steady:
            return 1.0
        }
    }
}

// MARK: - UI Integration

extension EnhancedBurnRateCalculator.EnhancedBurnRate {
    /// Get a visual representation of the burn rate for UI
    public var visualRepresentation: String {
        let bars = Int((ratePerHour / 10000) * 10) // Scale for display
        let barString = String(repeating: "▮", count: max(1, min(10, bars)))
        let emptyString = String(repeating: "▯", count: max(0, 10 - bars))
        
        return "\(barString)\(emptyString) \(trend.rawValue)"
    }
    
    /// Get recommended action based on burn rate
    public var recommendedAction: String {
        switch trend {
        case .accelerating where confidence > 70:
            return "🚨 Consider slowing down - usage accelerating rapidly"
        case .erratic:
            return "⚠️ Usage pattern is erratic - monitor closely"
        case .decelerating:
            return "✅ Usage is decreasing - good trend"
        case .steady, .accelerating:
            return "📊 Usage is \(trend == .steady ? "steady" : "increasing") - maintain awareness"
        }
    }
}