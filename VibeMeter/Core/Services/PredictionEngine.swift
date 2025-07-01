import Foundation
import os.log

/// Engine for predicting usage patterns and depletion times
@MainActor
public final class PredictionEngine: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "PredictionEngine")
    
    // MARK: - Types
    
    /// Prediction information with confidence levels
    public struct PredictionInfo: Sendable, Codable {
        public let depletionTime: Date?
        public let confidence: Int              // 0-100%
        public let daysRemaining: Double
        public let hoursRemaining: Double
        public let recommendedDailyLimit: Double
        public let onTrackForReset: Bool
        public let resetTime: Date
        public let provider: ServiceProvider
        
        public var depletionText: String {
            guard let depletion = depletionTime else { return "No depletion predicted" }
            
            let now = Date()
            let interval = depletion.timeIntervalSince(now)
            
            if interval < 0 {
                return "Already depleted"
            } else if interval < 3600 {
                return "< 1 hour"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                let days = Int(interval / 86400)
                return "\(days) day\(days == 1 ? "" : "s")"
            }
        }
        
        public var confidenceLevel: String {
            switch confidence {
            case 80...100: return "High"
            case 50..<80: return "Medium"
            default: return "Low"
            }
        }
        
        public var recommendation: String {
            if onTrackForReset {
                return "✅ On track to last until reset"
            } else if hoursRemaining < 1 {
                return "🚨 Slow down immediately!"
            } else if hoursRemaining < 24 {
                return "⚠️ Reduce usage to avoid depletion"
            } else {
                return "💡 Maintain current pace or reduce slightly"
            }
        }
    }
    
    /// Reset time information
    public struct ResetInfo: Sendable {
        public let nextReset: Date
        public let hoursUntilReset: Double
        public let daysUntilReset: Double
        public let resetType: ResetType
        
        public enum ResetType: String, Sendable {
            case daily = "Daily"
            case monthly = "Monthly"
            case fiveHour = "5-Hour Window"
            case custom = "Custom"
        }
    }
    
    // MARK: - Properties
    
    private let velocityTracker = VelocityTracker()
    private var resetSchedules: [ServiceProvider: ResetInfo] = [:]
    
    // Claude-specific reset hours (from ccseva)
    private let claudeResetHours = [4, 9, 14, 18, 23]
    
    // MARK: - Public Methods
    
    /// Calculate prediction for a provider
    public func calculatePrediction(
        for provider: ServiceProvider,
        currentUsage: Double,
        limit: Double,
        burnRate: BurnRateCalculator.BurnRate?,
        customResetTime: Date? = nil
    ) -> PredictionInfo {
        
        // Get velocity info
        let velocity = velocityTracker.calculateVelocity(for: provider, currentBurnRate: burnRate)
        
        // Get reset info
        let resetInfo = getResetInfo(for: provider, customTime: customResetTime)
        
        // Calculate remaining
        let remaining = max(0, limit - currentUsage)
        
        // Calculate confidence based on data availability
        let confidence = calculateConfidence(
            velocity: velocity,
            burnRate: burnRate,
            provider: provider
        )
        
        // Calculate depletion time
        let (depletionTime, hoursRemaining) = calculateDepletionTime(
            remaining: remaining,
            burnRate: burnRate,
            velocity: velocity
        )
        
        // Calculate recommended daily limit
        let recommendedLimit = calculateRecommendedDailyLimit(
            remaining: remaining,
            resetInfo: resetInfo,
            currentRate: burnRate?.ratePerHour ?? velocity?.current ?? 0
        )
        
        // Check if on track
        let onTrack = isOnTrackForReset(
            currentUsage: currentUsage,
            limit: limit,
            resetInfo: resetInfo,
            currentRate: burnRate?.ratePerHour ?? 0
        )
        
        return PredictionInfo(
            depletionTime: depletionTime,
            confidence: confidence,
            daysRemaining: hoursRemaining / 24,
            hoursRemaining: hoursRemaining,
            recommendedDailyLimit: recommendedLimit,
            onTrackForReset: onTrack,
            resetTime: resetInfo.nextReset,
            provider: provider
        )
    }
    
    /// Calculate prediction specifically for Claude sessions
    public func calculateClaudePrediction(
        sessionTracking: ClaudeSessionTracker.SessionTracking,
        burnRate: Double
    ) -> PredictionInfo {
        
        let currentUsage = Double(sessionTracking.activeWindow.totalTokens)
        let limit = 200_000.0 // Claude typical limit
        
        // Calculate velocity from sessions
        let velocity = velocityTracker.calculateVelocityFromSessions(
            sessionTracking.activeWindow.sessions,
            currentBurnRate: burnRate
        )
        
        // Get Claude-specific reset time
        let resetInfo = getClaudeResetInfo()
        
        // Calculate confidence
        let confidence = calculateClaudeConfidence(
            sessionCount: sessionTracking.sessionsInWindow,
            velocity: velocity
        )
        
        // Calculate depletion
        let remaining = limit - currentUsage
        let hoursRemaining = burnRate > 0 ? remaining / (burnRate * 60) : Double.infinity
        let depletionTime = hoursRemaining.isFinite ? Date().addingTimeInterval(hoursRemaining * 3600) : nil
        
        // Recommended limit to last until reset
        let recommendedLimit = calculateRecommendedDailyLimit(
            remaining: remaining,
            resetInfo: resetInfo,
            currentRate: burnRate * 60
        )
        
        // Check if on track
        let onTrack = hoursRemaining > resetInfo.hoursUntilReset
        
        return PredictionInfo(
            depletionTime: depletionTime,
            confidence: confidence,
            daysRemaining: hoursRemaining / 24,
            hoursRemaining: hoursRemaining,
            recommendedDailyLimit: recommendedLimit,
            onTrackForReset: onTrack,
            resetTime: resetInfo.nextReset,
            provider: .claude
        )
    }
    
    /// Get prediction summary text
    public func getPredictionSummary(_ prediction: PredictionInfo) -> String {
        var summary = "📊 Prediction (\(prediction.confidenceLevel) confidence): "
        
        if let _ = prediction.depletionTime {
            summary += "Depletes in \(prediction.depletionText)"
        } else {
            summary += "No depletion expected"
        }
        
        summary += "\n\(prediction.recommendation)"
        
        if prediction.recommendedDailyLimit > 0 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let limitStr = formatter.string(from: NSNumber(value: prediction.recommendedDailyLimit)) ?? "0"
            summary += "\n💡 Recommended daily limit: \(limitStr)"
        }
        
        return summary
    }
    
    // MARK: - Private Methods
    
    private func getResetInfo(for provider: ServiceProvider, customTime: Date? = nil) -> ResetInfo {
        if let custom = customTime {
            let hoursUntil = custom.timeIntervalSinceNow / 3600
            return ResetInfo(
                nextReset: custom,
                hoursUntilReset: hoursUntil,
                daysUntilReset: hoursUntil / 24,
                resetType: .custom
            )
        }
        
        switch provider {
        case .claude:
            return getClaudeResetInfo()
        case .cursor:
            return getMonthlyResetInfo()
        }
    }
    
    private func getClaudeResetInfo() -> ResetInfo {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        // Find next reset hour
        var nextResetHour: Int?
        for hour in claudeResetHours {
            if hour > currentHour {
                nextResetHour = hour
                break
            }
        }
        
        // If no reset hour found today, use first one tomorrow
        let isNextDay = nextResetHour == nil
        if nextResetHour == nil {
            nextResetHour = claudeResetHours.first ?? 4
        }
        
        // Create next reset date
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = nextResetHour
        components.minute = 0
        components.second = 0
        
        if isNextDay {
            components.day! += 1
        }
        
        let nextReset = calendar.date(from: components) ?? now
        let hoursUntil = nextReset.timeIntervalSince(now) / 3600
        
        return ResetInfo(
            nextReset: nextReset,
            hoursUntilReset: hoursUntil,
            daysUntilReset: hoursUntil / 24,
            resetType: .fiveHour
        )
    }
    
    private func getMonthlyResetInfo() -> ResetInfo {
        let calendar = Calendar.current
        let now = Date()
        
        // Get first day of next month
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now),
              let firstOfNextMonth = calendar.dateInterval(of: .month, for: nextMonth)?.start else {
            return getDailyResetInfo()
        }
        
        let hoursUntil = firstOfNextMonth.timeIntervalSince(now) / 3600
        
        return ResetInfo(
            nextReset: firstOfNextMonth,
            hoursUntilReset: hoursUntil,
            daysUntilReset: hoursUntil / 24,
            resetType: .monthly
        )
    }
    
    private func getDailyResetInfo() -> ResetInfo {
        let calendar = Calendar.current
        let now = Date()
        
        // Get midnight tomorrow
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
              let midnight = calendar.startOfDay(for: tomorrow) as Date? else {
            return ResetInfo(
                nextReset: now.addingTimeInterval(86400),
                hoursUntilReset: 24,
                daysUntilReset: 1,
                resetType: .daily
            )
        }
        
        let hoursUntil = midnight.timeIntervalSince(now) / 3600
        
        return ResetInfo(
            nextReset: midnight,
            hoursUntilReset: hoursUntil,
            daysUntilReset: hoursUntil / 24,
            resetType: .daily
        )
    }
    
    private func calculateConfidence(
        velocity: VelocityTracker.VelocityInfo?,
        burnRate: BurnRateCalculator.BurnRate?,
        provider: ServiceProvider
    ) -> Int {
        var confidence = 50 // Base confidence
        
        // Add confidence for having burn rate data
        if burnRate != nil {
            confidence += 20
        }
        
        // Add confidence for velocity data
        if let velocity = velocity {
            confidence += 15
            
            // Reduce confidence if trend is volatile
            if abs(velocity.trendPercent) > 50 {
                confidence -= 10
            }
            
            // Add confidence if we have good historical data
            if velocity.average24h > 0 && velocity.average7d > 0 {
                confidence += 15
            }
        }
        
        return min(95, max(10, confidence))
    }
    
    private func calculateClaudeConfidence(
        sessionCount: Int,
        velocity: VelocityTracker.VelocityInfo
    ) -> Int {
        var confidence = 60 // Higher base for Claude due to session tracking
        
        // More sessions = more confidence
        if sessionCount > 5 {
            confidence += 20
        } else if sessionCount > 2 {
            confidence += 10
        }
        
        // Stable velocity = more confidence
        if velocity.trend == .stable {
            confidence += 10
        } else if abs(velocity.trendPercent) > 50 {
            confidence -= 15
        }
        
        return min(95, max(20, confidence))
    }
    
    private func calculateDepletionTime(
        remaining: Double,
        burnRate: BurnRateCalculator.BurnRate?,
        velocity: VelocityTracker.VelocityInfo?
    ) -> (time: Date?, hours: Double) {
        // Use burn rate if available, otherwise velocity
        let rate = burnRate?.ratePerHour ?? velocity?.current ?? 0
        
        guard rate > 0 else {
            return (nil, Double.infinity)
        }
        
        let hoursRemaining = remaining / rate
        
        if hoursRemaining.isFinite && hoursRemaining > 0 {
            let depletionTime = Date().addingTimeInterval(hoursRemaining * 3600)
            return (depletionTime, hoursRemaining)
        } else {
            return (nil, Double.infinity)
        }
    }
    
    private func calculateRecommendedDailyLimit(
        remaining: Double,
        resetInfo: ResetInfo,
        currentRate: Double
    ) -> Double {
        guard resetInfo.daysUntilReset > 0 else { return remaining }
        
        // Simple calculation: divide remaining by days until reset
        let baseLimit = remaining / resetInfo.daysUntilReset
        
        // Adjust based on current rate
        if currentRate > 0 && currentRate < baseLimit {
            // If current rate is sustainable, recommend slightly lower for safety
            return currentRate * 0.9
        } else {
            // Otherwise use the calculated limit with safety margin
            return baseLimit * 0.85
        }
    }
    
    private func isOnTrackForReset(
        currentUsage: Double,
        limit: Double,
        resetInfo: ResetInfo,
        currentRate: Double
    ) -> Bool {
        let remaining = limit - currentUsage
        let projectedUsage = currentRate * resetInfo.hoursUntilReset
        
        return projectedUsage < remaining
    }
}

// MARK: - Formatted Output

extension PredictionEngine.PredictionInfo {
    /// Get a formatted multi-line summary
    public var formattedSummary: String {
        var lines: [String] = []
        
        // Status line
        if onTrackForReset {
            lines.append("✅ On Track for Reset")
        } else if let _ = depletionTime {
            lines.append("⚠️ Depletion: \(depletionText)")
        } else {
            lines.append("♾️ No Depletion Expected")
        }
        
        // Confidence
        lines.append("📊 Confidence: \(confidence)% (\(confidenceLevel))")
        
        // Time remaining
        if hoursRemaining.isFinite {
            if hoursRemaining < 24 {
                lines.append("⏱️ Time Left: \(Int(hoursRemaining))h")
            } else {
                lines.append("📅 Time Left: \(Int(daysRemaining))d")
            }
        }
        
        // Reset time
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        lines.append("🔄 Reset: \(formatter.string(from: resetTime))")
        
        // Recommendation
        if recommendedDailyLimit > 0 {
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = .decimal
            numberFormatter.maximumFractionDigits = 0
            let limitStr = numberFormatter.string(from: NSNumber(value: recommendedDailyLimit)) ?? "0"
            lines.append("💡 Daily Limit: \(limitStr)")
        }
        
        return lines.joined(separator: "\n")
    }
}