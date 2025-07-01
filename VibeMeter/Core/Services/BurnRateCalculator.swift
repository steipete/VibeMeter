import Foundation
import os.log

/// Calculates burn rates for various metrics (tokens, spending, requests) across all providers
/// Implements the sophisticated hourly burn rate calculation from Claude token monitor
@MainActor
public final class BurnRateCalculator: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "BurnRateCalculator")
    
    // MARK: - Types
    
    /// Represents a usage session with start and end times
    public struct UsageSession: Sendable {
        let startTime: Date
        let endTime: Date
        let value: Double // Can be tokens, dollars, or requests
        let provider: ServiceProvider
        let metric: MetricType
        
        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
    }
    
    /// Type of metric being tracked
    public enum MetricType: String, Sendable, Codable {
        case tokens
        case spending  // in cents
        case requests
    }
    
    /// Burn rate result with velocity indicator
    public struct BurnRate: Sendable, Codable {
        public let ratePerMinute: Double
        public let ratePerHour: Double
        public let metric: MetricType
        public let velocityIndicator: VelocityIndicator
        public let trend: BurnRateTrend
        
        public init(ratePerMinute: Double, ratePerHour: Double, metric: MetricType, 
                    velocityIndicator: VelocityIndicator, trend: BurnRateTrend = .steady(percentageChange: 0)) {
            self.ratePerMinute = ratePerMinute
            self.ratePerHour = ratePerHour
            self.metric = metric
            self.velocityIndicator = velocityIndicator
            self.trend = trend
        }
        
        /// Token burn rate per hour (for Claude)
        public var tokensPerHour: Double {
            metric == .tokens ? ratePerHour : 0
        }
        
        public var formattedRate: String {
            switch metric {
            case .tokens:
                return "\(Int(ratePerHour)) tokens/hour"
            case .spending:
                let dollarsPerHour = ratePerHour / 100.0
                return String(format: "$%.2f/hour", dollarsPerHour)
            case .requests:
                return "\(Int(ratePerHour)) requests/hour"
            }
        }
        
        /// Burn rate trend analysis
        public enum BurnRateTrend: Sendable, Codable {
            case accelerating(percentageChange: Double)
            case steady(percentageChange: Double)
            case decelerating(percentageChange: Double)
            case erratic(percentageChange: Double)
            
            public var percentageChange: Double {
                switch self {
                case .accelerating(let change), .steady(let change), 
                     .decelerating(let change), .erratic(let change):
                    return change
                }
            }
        }
    }
    
    /// Velocity indicator based on burn rate
    public enum VelocityIndicator: String, Sendable, Codable {
        case slow = "🐌"      // < 10% of limit per hour
        case normal = "➡️"    // 10-25% of limit per hour
        case fast = "🚀"      // 25-50% of limit per hour
        case veryFast = "⚡"  // > 50% of limit per hour
    }
    
    // MARK: - Public Methods
    
    /// Calculate burn rate for the last hour with proper session overlap handling
    /// This implements the algorithm from Claude token monitor's calculate_hourly_burn_rate
    public func calculateHourlyBurnRate(
        sessions: [UsageSession],
        currentTime: Date = Date()
    ) -> BurnRate? {
        let oneHourAgo = currentTime.addingTimeInterval(-3600)
        var totalValue: Double = 0
        
        logger.debug("Calculating burn rate for \(sessions.count) sessions")
        
        for session in sessions {
            // Skip sessions that ended before the last hour
            if session.endTime < oneHourAgo {
                continue
            }
            
            // Calculate how much of this session falls within the last hour
            let sessionStartInHour = max(session.startTime, oneHourAgo)
            let sessionEndInHour = min(session.endTime, currentTime)
            
            // Skip if no overlap
            if sessionEndInHour <= sessionStartInHour {
                continue
            }
            
            // Calculate proportional value for the overlap period
            let hourDuration = sessionEndInHour.timeIntervalSince(sessionStartInHour) / 60.0 // minutes
            let totalSessionDuration = session.duration / 60.0 // minutes
            
            if totalSessionDuration > 0 {
                // Proportionally attribute value based on time overlap
                let proportionalValue = session.value * (hourDuration / totalSessionDuration)
                totalValue += proportionalValue
                
                logger.debug("""
                    Session overlap: \(hourDuration)min of \(totalSessionDuration)min, \
                    value: \(proportionalValue) of \(session.value)
                    """)
            }
        }
        
        // Return burn rate per minute and per hour
        guard totalValue > 0 else { return nil }
        
        let ratePerMinute = totalValue / 60.0
        let ratePerHour = totalValue
        
        // Determine velocity indicator based on metric type
        let metric = sessions.first?.metric ?? .tokens
        let velocityIndicator = determineVelocityIndicator(
            ratePerHour: ratePerHour,
            metric: metric
        )
        
        return BurnRate(
            ratePerMinute: ratePerMinute,
            ratePerHour: ratePerHour,
            metric: metric,
            velocityIndicator: velocityIndicator,
            trend: .steady(percentageChange: 0)
        )
    }
    
    /// Calculate burn rate for Claude tokens from log entries
    public func calculateClaudeTokenBurnRate(
        entries: [ClaudeLogEntry],
        in window: TimeInterval = 3600,
        currentTime: Date = Date()
    ) -> BurnRate? {
        // Convert log entries to sessions
        let sessions = entries.compactMap { entry -> UsageSession? in
            // Claude log entries represent point-in-time usage
            // We'll treat each as a mini-session of 1 minute duration
            let totalTokens = Double(entry.inputTokens + entry.outputTokens)
            guard totalTokens > 0 else { return nil }
            
            return UsageSession(
                startTime: entry.timestamp,
                endTime: entry.timestamp.addingTimeInterval(60), // 1-minute session
                value: totalTokens,
                provider: .claude,
                metric: .tokens
            )
        }
        
        return calculateHourlyBurnRate(sessions: sessions, currentTime: currentTime)
    }
    
    /// Calculate spending burn rate from invoice data
    public func calculateSpendingBurnRate(
        provider: ServiceProvider,
        spendingHistory: [(date: Date, amountCents: Int)],
        currentTime: Date = Date()
    ) -> BurnRate? {
        // Create sessions from spending data points
        // Assume each spending entry represents usage over the past hour
        let sessions = spendingHistory.compactMap { entry -> UsageSession? in
            guard entry.amountCents > 0 else { return nil }
            
            return UsageSession(
                startTime: entry.date.addingTimeInterval(-3600),
                endTime: entry.date,
                value: Double(entry.amountCents),
                provider: provider,
                metric: .spending
            )
        }
        
        return calculateHourlyBurnRate(sessions: sessions, currentTime: currentTime)
    }
    
    /// Calculate request burn rate from usage data
    public func calculateRequestBurnRate(
        provider: ServiceProvider,
        requestHistory: [(date: Date, requestCount: Int)],
        currentTime: Date = Date()
    ) -> BurnRate? {
        // Similar to spending, but for request counts
        let sessions = requestHistory.compactMap { entry -> UsageSession? in
            guard entry.requestCount > 0 else { return nil }
            
            return UsageSession(
                startTime: entry.date.addingTimeInterval(-3600),
                endTime: entry.date,
                value: Double(entry.requestCount),
                provider: provider,
                metric: .requests
            )
        }
        
        return calculateHourlyBurnRate(sessions: sessions, currentTime: currentTime)
    }
    
    /// Predict when a limit will be reached based on current burn rate
    public func predictLimitDepletion(
        currentValue: Double,
        limit: Double,
        burnRate: BurnRate
    ) -> Date? {
        guard burnRate.ratePerMinute > 0 else { return nil }
        
        let remaining = limit - currentValue
        guard remaining > 0 else { return nil }
        
        let minutesToDepletion = remaining / burnRate.ratePerMinute
        return Date().addingTimeInterval(minutesToDepletion * 60)
    }
    
    // MARK: - Private Methods
    
    private func determineVelocityIndicator(
        ratePerHour: Double,
        metric: MetricType
    ) -> VelocityIndicator {
        // These thresholds can be adjusted based on typical limits
        switch metric {
        case .tokens:
            // Assume ~200k token limit per 5 hours = 40k/hour average
            switch ratePerHour {
            case ..<4000: return .slow      // < 10% of average hourly
            case 4000..<10000: return .normal  // 10-25%
            case 10000..<20000: return .fast   // 25-50%
            default: return .veryFast          // > 50%
            }
            
        case .spending:
            // Assume $20/month = ~$0.027/hour average
            let dollarsPerHour = ratePerHour / 100.0
            switch dollarsPerHour {
            case ..<0.5: return .slow
            case 0.5..<2.0: return .normal
            case 2.0..<5.0: return .fast
            default: return .veryFast
            }
            
        case .requests:
            // Assume 500 requests/day = ~21/hour average
            switch ratePerHour {
            case ..<10: return .slow
            case 10..<30: return .normal
            case 30..<60: return .fast
            default: return .veryFast
            }
        }
    }
}

// MARK: - Integration Extensions

extension BurnRateCalculator {
    /// Create burn rate info for display in UI
    public struct BurnRateInfo: Sendable, Codable {
        public let provider: ServiceProvider
        public let burnRate: BurnRate?
        public let depletionTime: Date?
        public let warningLevel: WarningLevel
        public let sessionInfo: SessionInfo?
        
        public enum WarningLevel: String, Sendable, Codable {
            case none
            case moderate  // Will deplete in 1-3 hours
            case high      // Will deplete in < 1 hour
        }
        
        /// Session-specific information for providers that track usage sessions
        public struct SessionInfo: Sendable, Codable {
            public let sessionStartTime: Date
            public let sessionEndTime: Date
            public let isActive: Bool
            public let isSessionBased: Bool  // true if using exact session times, false if approximate
            
            public var timeRemaining: TimeInterval {
                sessionEndTime.timeIntervalSinceNow
            }
            
            public var sessionProgress: Double {
                let totalDuration = sessionEndTime.timeIntervalSince(sessionStartTime)
                let elapsed = Date().timeIntervalSince(sessionStartTime)
                return min(1.0, max(0.0, elapsed / totalDuration))
            }
        }
    }
    
    /// Calculate comprehensive burn rate info for a provider
    public func calculateBurnRateInfo(
        for provider: ServiceProvider,
        currentUsage: Double,
        limit: Double,
        burnRate: BurnRate?,
        sessionInfo: BurnRateInfo.SessionInfo? = nil
    ) -> BurnRateInfo {
        guard let burnRate = burnRate else {
            return BurnRateInfo(
                provider: provider,
                burnRate: nil,
                depletionTime: nil,
                warningLevel: .none,
                sessionInfo: sessionInfo
            )
        }
        
        let depletionTime = predictLimitDepletion(
            currentValue: currentUsage,
            limit: limit,
            burnRate: burnRate
        )
        
        // Determine warning level
        let warningLevel: BurnRateInfo.WarningLevel
        if let depletionTime = depletionTime {
            let hoursToDepletion = depletionTime.timeIntervalSinceNow / 3600
            switch hoursToDepletion {
            case ..<1: warningLevel = .high
            case 1..<3: warningLevel = .moderate
            default: warningLevel = .none
            }
        } else {
            warningLevel = .none
        }
        
        return BurnRateInfo(
            provider: provider,
            burnRate: burnRate,
            depletionTime: depletionTime,
            warningLevel: warningLevel,
            sessionInfo: sessionInfo
        )
    }
}