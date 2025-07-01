import Foundation
import os.log

/// Tracks usage velocity and trends across different time periods
@MainActor
public final class VelocityTracker: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "VelocityTracker")
    
    // MARK: - Types
    
    /// Velocity information with trend analysis
    public struct VelocityInfo: Sendable, Codable {
        public let current: Double              // Current rate (tokens/hour)
        public let average24h: Double          // 24-hour average
        public let average7d: Double           // 7-day average
        public let trend: Trend
        public let trendPercent: Double        // Percentage change
        public let peakHour: Int              // Hour of day with highest usage (0-23)
        public let isAccelerating: Bool       // True if usage is rapidly increasing
        
        public enum Trend: String, Sendable, Codable {
            case increasing
            case decreasing
            case stable
            case starting
        }
        
        public var trendEmoji: String {
            switch trend {
            case .increasing: return "📈"
            case .decreasing: return "📉"
            case .stable: return "➡️"
            case .starting: return "🆕"
            }
        }
        
        /// Formatted rate for display
        public var formattedRate: String {
            TokenFormatter.formatRate(current)
        }
        
        /// Formatted trend percentage
        public var formattedTrend: String {
            if abs(trendPercent) < 1 {
                return "0%"
            }
            let sign = trend == .increasing ? "+" : ""
            return "\(sign)\(Int(trendPercent))%"
        }
        
        /// Recommendation based on velocity
        public var recommendation: String? {
            if isAccelerating {
                return "Usage rapidly increasing"
            } else if trend == .increasing && trendPercent > 30 {
                return "Consider pacing usage"
            } else if trend == .decreasing && trendPercent < -30 {
                return "Good usage reduction"
            }
            return nil
        }
        
        public var description: String {
            "\(trendEmoji) \(trend.rawValue.capitalized) (\(formattedTrend))"
        }
    }
    
    /// Historical data point for velocity calculations
    private struct DataPoint: Sendable {
        let timestamp: Date
        let value: Double
        let provider: ServiceProvider
    }
    
    // MARK: - Properties
    
    private var dataPoints: [DataPoint] = []
    private let maxDataAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let stableThreshold: Double = 15.0 // 15% change threshold for stable
    private let accelerationThreshold: Double = 50.0 // 50% increase for acceleration
    
    // MARK: - Public Methods
    
    /// Get recommendation based on velocity info
    public func getRecommendation(for velocity: VelocityInfo) -> String? {
        velocity.recommendation
    }
    
    /// Add a usage data point
    public func addDataPoint(value: Double, provider: ServiceProvider, timestamp: Date = Date()) {
        let point = DataPoint(timestamp: timestamp, value: value, provider: provider)
        dataPoints.append(point)
        
        // Clean old data
        cleanOldData()
        
        logger.debug("Added data point: \(value) for \(provider.rawValue)")
    }
    
    /// Calculate velocity info for a provider
    public func calculateVelocity(
        for provider: ServiceProvider,
        currentBurnRate: BurnRateCalculator.BurnRate? = nil
    ) -> VelocityInfo? {
        let providerPoints = dataPoints.filter { $0.provider == provider }
        guard !providerPoints.isEmpty else { return nil }
        
        let now = Date()
        
        // Current rate (use provided burn rate or calculate from recent data)
        let current = currentBurnRate?.ratePerHour ?? calculateHourlyRate(from: providerPoints, at: now)
        
        // 24-hour average
        let oneDayAgo = now.addingTimeInterval(-24 * 60 * 60)
        let last24hPoints = providerPoints.filter { $0.timestamp >= oneDayAgo }
        let average24h = calculateAverageRate(from: last24hPoints)
        
        // 7-day average
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let last7dPoints = providerPoints.filter { $0.timestamp >= oneWeekAgo }
        let average7d = calculateAverageRate(from: last7dPoints)
        
        // Calculate trend
        let (trend, trendPercent) = calculateTrend(
            current: current,
            average24h: average24h,
            average7d: average7d
        )
        
        // Find peak hour
        let peakHour = findPeakHour(from: providerPoints)
        
        // Check if accelerating
        let isAccelerating = trend == .increasing && trendPercent > accelerationThreshold
        
        return VelocityInfo(
            current: current,
            average24h: average24h,
            average7d: average7d,
            trend: trend,
            trendPercent: trendPercent,
            peakHour: peakHour,
            isAccelerating: isAccelerating
        )
    }
    
    /// Calculate velocity from Claude sessions
    public func calculateVelocityFromSessions(
        _ sessions: [ClaudeSessionTracker.Session],
        currentBurnRate: Double
    ) -> VelocityInfo {
        let now = Date()
        
        // 24-hour calculations
        let oneDayAgo = now.addingTimeInterval(-24 * 60 * 60)
        let last24hSessions = sessions.filter { session in
            session.startTime >= oneDayAgo || 
            (session.effectiveEndTime > oneDayAgo && session.startTime < now)
        }
        
        let tokens24h = last24hSessions.reduce(0) { $0 + $1.totalTokens }
        let average24h = Double(tokens24h) / 24.0
        
        // 7-day calculations
        let oneWeekAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let last7dSessions = sessions.filter { session in
            session.startTime >= oneWeekAgo ||
            (session.effectiveEndTime > oneWeekAgo && session.startTime < now)
        }
        
        let tokens7d = last7dSessions.reduce(0) { $0 + $1.totalTokens }
        let average7d = Double(tokens7d) / (7.0 * 24.0)
        
        // Calculate trend
        let (trend, trendPercent) = calculateTrend(
            current: currentBurnRate * 60, // Convert to per hour
            average24h: average24h,
            average7d: average7d
        )
        
        // Find peak hour from sessions
        let peakHour = findPeakHourFromSessions(sessions)
        
        // Check acceleration
        let isAccelerating = trend == .increasing && trendPercent > accelerationThreshold
        
        return VelocityInfo(
            current: currentBurnRate * 60,
            average24h: average24h,
            average7d: average7d,
            trend: trend,
            trendPercent: trendPercent,
            peakHour: peakHour,
            isAccelerating: isAccelerating
        )
    }
    
    /// Get velocity summary for display
    public func getVelocitySummary(for provider: ServiceProvider) -> String {
        guard let velocity = calculateVelocity(for: provider) else {
            return "No velocity data"
        }
        
        let currentStr = formatRate(velocity.current)
        let trendStr = velocity.description
        
        if velocity.isAccelerating {
            return "⚡ \(currentStr)/hr \(trendStr) - Accelerating!"
        } else {
            return "\(currentStr)/hr \(trendStr)"
        }
    }
    
    // MARK: - Private Methods
    
    private func cleanOldData() {
        let cutoffDate = Date().addingTimeInterval(-maxDataAge)
        dataPoints.removeAll { $0.timestamp < cutoffDate }
    }
    
    private func calculateHourlyRate(from points: [DataPoint], at date: Date) -> Double {
        let oneHourAgo = date.addingTimeInterval(-3600)
        let recentPoints = points.filter { $0.timestamp >= oneHourAgo }
        
        guard !recentPoints.isEmpty else { return 0 }
        
        let totalValue = recentPoints.reduce(0) { $0 + $1.value }
        return totalValue // Already represents hourly rate
    }
    
    private func calculateAverageRate(from points: [DataPoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        
        // Group by hour and calculate average
        let calendar = Calendar.current
        var hourlyTotals: [Int: Double] = [:]
        var hourlyCounts: [Int: Int] = [:]
        
        for point in points {
            let hour = calendar.component(.hour, from: point.timestamp)
            hourlyTotals[hour, default: 0] += point.value
            hourlyCounts[hour, default: 0] += 1
        }
        
        // Calculate average across all hours
        var totalRate = 0.0
        var hourCount = 0
        
        for (hour, total) in hourlyTotals {
            if let count = hourlyCounts[hour], count > 0 {
                totalRate += total / Double(count)
                hourCount += 1
            }
        }
        
        return hourCount > 0 ? totalRate / Double(hourCount) : 0
    }
    
    private func calculateTrend(
        current: Double,
        average24h: Double,
        average7d: Double
    ) -> (trend: VelocityInfo.Trend, percent: Double) {
        // Use 24h average as baseline if available, otherwise 7d
        let baseline = average24h > 0 ? average24h : average7d
        
        guard baseline > 0 else {
            return (.stable, 0)
        }
        
        let percentChange = ((current - baseline) / baseline) * 100
        
        if abs(percentChange) < stableThreshold {
            return (.stable, percentChange)
        } else if percentChange > 0 {
            return (.increasing, percentChange)
        } else {
            return (.decreasing, percentChange)
        }
    }
    
    private func findPeakHour(from points: [DataPoint]) -> Int {
        let calendar = Calendar.current
        var hourlyTotals: [Int: Double] = [:]
        
        for point in points {
            let hour = calendar.component(.hour, from: point.timestamp)
            hourlyTotals[hour, default: 0] += point.value
        }
        
        let peakHour = hourlyTotals.max(by: { $0.value < $1.value })?.key ?? 14
        return peakHour
    }
    
    private func findPeakHourFromSessions(_ sessions: [ClaudeSessionTracker.Session]) -> Int {
        let calendar = Calendar.current
        var hourlyTokens: [Int: Int] = [:]
        
        for session in sessions {
            let startHour = calendar.component(.hour, from: session.startTime)
            let endHour = calendar.component(.hour, from: session.effectiveEndTime)
            
            // Distribute tokens across hours (simplified)
            if startHour == endHour {
                hourlyTokens[startHour, default: 0] += session.totalTokens
            } else {
                // Split tokens evenly across hours
                let hours = abs(endHour - startHour) + 1
                let tokensPerHour = session.totalTokens / hours
                
                for hour in startHour...endHour {
                    let normalizedHour = hour % 24
                    hourlyTokens[normalizedHour, default: 0] += tokensPerHour
                }
            }
        }
        
        return hourlyTokens.max(by: { $0.value < $1.value })?.key ?? 14
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

// MARK: - Integration with Providers

extension VelocityTracker {
    /// Update velocity data from provider usage
    public func updateFromProviderUsage(
        _ usage: ProviderUsageData,
        provider: ServiceProvider
    ) {
        // For Claude, currentRequests contains the usage percentage
        if provider == .claude {
            let tokensUsed = Double(usage.totalRequests)
            addDataPoint(value: tokensUsed, provider: provider)
        } else {
            // For other providers, use request count
            let requests = Double(usage.currentRequests)
            addDataPoint(value: requests, provider: provider)
        }
    }
    
    /// Update velocity data from spending
    public func updateFromSpending(
        amount: Double,
        provider: ServiceProvider
    ) {
        addDataPoint(value: amount, provider: provider)
    }
}