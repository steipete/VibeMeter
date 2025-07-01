import Foundation
import SwiftUI
import os.log

/// Detects user's auto-renewal plan based on usage patterns
@MainActor
public final class AutoPlanDetector: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "AutoPlanDetector")
    
    // MARK: - Types
    
    /// Detected plan information
    public struct DetectedPlan: Sendable, Codable {
        public let provider: ServiceProvider
        public let planType: PlanType
        public let confidence: Double // 0-100%
        public let evidence: [Evidence]
        public let estimatedLimit: Double
        public let estimatedCost: Double
        public let resetPattern: ResetPattern
        public let detectedAt: Date
        
        public enum PlanType: String, Sendable, Codable {
            case free = "Free"
            case basic = "Basic"
            case pro = "Pro"
            case team = "Team"
            case enterprise = "Enterprise"
            case unknown = "Unknown"
        }
        
        public struct Evidence: Sendable, Codable {
            public let type: EvidenceType
            public let value: String
            public let weight: Double // 0-1
            
            public enum EvidenceType: String, Sendable, Codable {
                case usagePattern = "Usage Pattern"
                case limitDetection = "Limit Detection"
                case costAnalysis = "Cost Analysis"
                case resetTiming = "Reset Timing"
                case featureUsage = "Feature Usage"
            }
        }
        
        public enum ResetPattern: String, Sendable, Codable {
            case daily
            case weekly
            case monthly
            case fiveHour  // Claude specific
            case custom
        }
        
        public var summary: String {
            """
            📋 Detected Plan: \(planType.rawValue)
            Provider: \(provider.displayName)
            Confidence: \(Int(confidence))%
            Limit: \(formatLimit(estimatedLimit))
            Cost: $\(String(format: "%.2f", estimatedCost))/month
            Reset: \(resetPattern.rawValue)
            """
        }
        
        private func formatLimit(_ limit: Double) -> String {
            switch provider {
            case .claude:
                return TokenFormatter.format(Int(limit))
            default:
                return "$\(String(format: "%.2f", limit))"
            }
        }
    }
    
    /// Historical usage data for pattern analysis
    private struct UsageHistory: Sendable {
        let date: Date
        let usage: Double
        let resetOccurred: Bool
    }
    
    // MARK: - Properties
    
    private var detectedPlans: [ServiceProvider: DetectedPlan] = [:]
    private var usageHistory: [ServiceProvider: [UsageHistory]] = [:]
    
    // Known plan configurations (from ccseva patterns)
    private let knownPlans: [ServiceProvider: [PlanConfiguration]] = [
        .claude: [
            PlanConfiguration(type: .free, limit: 0, cost: 0, features: []),
            PlanConfiguration(type: .pro, limit: 200_000, cost: 20, features: ["5-hour-window"]),
            PlanConfiguration(type: .team, limit: 500_000, cost: 25, features: ["5-hour-window", "team-features"])
        ],
        .cursor: [
            PlanConfiguration(type: .free, limit: 0, cost: 0, features: ["limited-requests"]),
            PlanConfiguration(type: .pro, limit: 500, cost: 20, features: ["fast-requests"]),
            PlanConfiguration(type: .team, limit: 2000, cost: 40, features: ["fast-requests", "team-features"])
        ]
    ]
    
    private struct PlanConfiguration {
        let type: DetectedPlan.PlanType
        let limit: Double
        let cost: Double
        let features: [String]
    }
    
    // MARK: - Public Methods
    
    /// Analyze usage patterns and detect plan
    public func detectPlan(
        for provider: ServiceProvider,
        currentUsage: Double,
        historicalData: [Date: Double],
        additionalContext: [String: Any] = [:]
    ) -> DetectedPlan {
        logger.info("Detecting plan for \(provider.rawValue)")
        
        // Update history
        updateUsageHistory(provider: provider, data: historicalData)
        
        // Gather evidence
        var evidence: [DetectedPlan.Evidence] = []
        var confidenceScore = 50.0 // Base confidence
        
        // 1. Analyze usage patterns
        let patternEvidence = analyzeUsagePatterns(provider: provider, history: usageHistory[provider] ?? [])
        evidence.append(contentsOf: patternEvidence)
        confidenceScore += patternEvidence.reduce(0) { $0 + $1.weight * 10 }
        
        // 2. Detect limits
        let limitEvidence = detectLimits(provider: provider, currentUsage: currentUsage, history: historicalData)
        evidence.append(contentsOf: limitEvidence)
        confidenceScore += limitEvidence.reduce(0) { $0 + $1.weight * 15 }
        
        // 3. Analyze costs
        if let monthlyCost = additionalContext["monthlyCost"] as? Double {
            let costEvidence = analyzeCosts(provider: provider, monthlyCost: monthlyCost)
            evidence.append(contentsOf: costEvidence)
            confidenceScore += costEvidence.reduce(0) { $0 + $1.weight * 20 }
        }
        
        // 4. Detect reset patterns
        let resetEvidence = detectResetPattern(provider: provider, history: historicalData)
        evidence.append(contentsOf: resetEvidence.evidence)
        
        // Match to known plans
        let (matchedPlan, matchConfidence) = matchToKnownPlan(
            provider: provider,
            evidence: evidence,
            resetPattern: resetEvidence.pattern
        )
        
        // Adjust confidence
        confidenceScore = min(95, confidenceScore * matchConfidence)
        
        let detectedPlan = DetectedPlan(
            provider: provider,
            planType: matchedPlan.type,
            confidence: confidenceScore,
            evidence: evidence,
            estimatedLimit: matchedPlan.limit,
            estimatedCost: matchedPlan.cost,
            resetPattern: resetEvidence.pattern,
            detectedAt: Date()
        )
        
        // Cache result
        detectedPlans[provider] = detectedPlan
        
        return detectedPlan
    }
    
    /// Get cached plan detection if available
    public func getCachedPlan(for provider: ServiceProvider) -> DetectedPlan? {
        detectedPlans[provider]
    }
    
    /// Detect plans for all providers
    public func detectAllPlans(orchestrator: MultiProviderDataOrchestrator) async -> [ServiceProvider: DetectedPlan] {
        var results: [ServiceProvider: DetectedPlan] = [:]
        
        for provider in ServiceProvider.allCases {
            // Get current data
            let providerData = orchestrator.spendingData.providerSpending[provider]
            let currentUsage = providerData?.currentSpendingUSD ?? 0
            
            // Get historical data (simplified - would need actual historical storage)
            let historicalData = generateMockHistoricalData(for: provider)
            
            let plan = detectPlan(
                for: provider,
                currentUsage: currentUsage,
                historicalData: historicalData,
                additionalContext: ["monthlyCost": providerData?.currentSpendingUSD ?? 0]
            )
            
            results[provider] = plan
        }
        
        return results
    }
    
    // MARK: - Private Analysis Methods
    
    private func analyzeUsagePatterns(
        provider: ServiceProvider,
        history: [UsageHistory]
    ) -> [DetectedPlan.Evidence] {
        var evidence: [DetectedPlan.Evidence] = []
        
        // Check for consistent usage
        if history.count > 7 {
            let usageValues = history.map(\.usage)
            let avgUsage = usageValues.reduce(0, +) / Double(usageValues.count)
            let variance = usageValues.map { pow($0 - avgUsage, 2) }.reduce(0, +) / Double(usageValues.count)
            let stdDev = sqrt(variance)
            
            if stdDev / avgUsage < 0.3 {
                evidence.append(DetectedPlan.Evidence(
                    type: .usagePattern,
                    value: "Consistent usage pattern",
                    weight: 0.7
                ))
            }
        }
        
        // Check for usage spikes
        if let maxUsage = history.map(\.usage).max(), maxUsage > 0 {
            let spikes = history.filter { $0.usage > maxUsage * 0.8 }
            if spikes.count > 2 {
                evidence.append(DetectedPlan.Evidence(
                    type: .usagePattern,
                    value: "Regular usage spikes detected",
                    weight: 0.5
                ))
            }
        }
        
        return evidence
    }
    
    private func detectLimits(
        provider: ServiceProvider,
        currentUsage: Double,
        history: [Date: Double]
    ) -> [DetectedPlan.Evidence] {
        var evidence: [DetectedPlan.Evidence] = []
        
        // Find maximum usage
        let maxUsage = history.values.max() ?? currentUsage
        
        // Check if usage plateaus near certain values
        let commonLimits: [Double] = switch provider {
        case .claude: [50_000, 100_000, 200_000, 500_000]
        default: [10, 20, 50, 100, 200, 500]
        }
        
        for limit in commonLimits {
            if maxUsage > limit * 0.8 && maxUsage < limit * 1.1 {
                evidence.append(DetectedPlan.Evidence(
                    type: .limitDetection,
                    value: "Usage near \(Int(limit)) limit",
                    weight: 0.8
                ))
                break
            }
        }
        
        return evidence
    }
    
    private func analyzeCosts(
        provider: ServiceProvider,
        monthlyCost: Double
    ) -> [DetectedPlan.Evidence] {
        var evidence: [DetectedPlan.Evidence] = []
        
        // Match to known price points
        let knownPrices = knownPlans[provider]?.map(\.cost) ?? []
        
        for price in knownPrices {
            if abs(monthlyCost - price) < price * 0.1 {
                evidence.append(DetectedPlan.Evidence(
                    type: .costAnalysis,
                    value: "Cost matches $\(Int(price))/month plan",
                    weight: 0.9
                ))
                break
            }
        }
        
        return evidence
    }
    
    private func detectResetPattern(
        provider: ServiceProvider,
        history: [Date: Double]
    ) -> (pattern: DetectedPlan.ResetPattern, evidence: [DetectedPlan.Evidence]) {
        var evidence: [DetectedPlan.Evidence] = []
        
        // Sort history by date
        let sortedHistory = history.sorted { $0.key < $1.key }
        
        // Look for reset patterns
        var resetDates: [Date] = []
        if sortedHistory.count > 1 {
            for i in 1..<sortedHistory.count {
                let prevUsage = sortedHistory[i-1].value
                let currUsage = sortedHistory[i].value
                
                // Significant drop indicates reset
                if currUsage < prevUsage * 0.2 {
                    resetDates.append(sortedHistory[i].key)
                }
            }
        }
        
        // Analyze reset intervals
        let pattern: DetectedPlan.ResetPattern
        if provider == .claude {
            pattern = .fiveHour
            evidence.append(DetectedPlan.Evidence(
                type: .resetTiming,
                value: "5-hour window resets",
                weight: 0.95
            ))
        } else if resetDates.count >= 2 {
            let intervals = zip(resetDates.dropLast(), resetDates.dropFirst()).map {
                $1.timeIntervalSince($0)
            }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
            
            if avgInterval < 1.5 * 86400 {
                pattern = .daily
                evidence.append(DetectedPlan.Evidence(
                    type: .resetTiming,
                    value: "Daily resets detected",
                    weight: 0.8
                ))
            } else if avgInterval < 10 * 86400 {
                pattern = .weekly
                evidence.append(DetectedPlan.Evidence(
                    type: .resetTiming,
                    value: "Weekly resets detected",
                    weight: 0.8
                ))
            } else {
                pattern = .monthly
                evidence.append(DetectedPlan.Evidence(
                    type: .resetTiming,
                    value: "Monthly resets detected",
                    weight: 0.8
                ))
            }
        } else {
            pattern = .monthly // Default assumption
        }
        
        return (pattern, evidence)
    }
    
    private func matchToKnownPlan(
        provider: ServiceProvider,
        evidence: [DetectedPlan.Evidence],
        resetPattern: DetectedPlan.ResetPattern
    ) -> (plan: PlanConfiguration, confidence: Double) {
        guard let knownConfigs = knownPlans[provider] else {
            return (PlanConfiguration(type: .unknown, limit: 0, cost: 0, features: []), 0.5)
        }
        
        var bestMatch: (config: PlanConfiguration, score: Double)?
        
        for config in knownConfigs {
            var score = 0.0
            
            // Match based on evidence
            for e in evidence {
                switch e.type {
                case .costAnalysis:
                    if e.value.contains("$\(Int(config.cost))") {
                        score += e.weight
                    }
                case .limitDetection:
                    if e.value.contains("\(Int(config.limit))") {
                        score += e.weight
                    }
                default:
                    score += e.weight * 0.5
                }
            }
            
            if bestMatch == nil || score > bestMatch!.score {
                bestMatch = (config, score)
            }
        }
        
        let confidence = min(1.0, (bestMatch?.score ?? 0) / Double(evidence.count))
        return (bestMatch?.config ?? knownConfigs.first!, confidence)
    }
    
    private func updateUsageHistory(provider: ServiceProvider, data: [Date: Double]) {
        var history = usageHistory[provider] ?? []
        
        for (date, usage) in data {
            let resetOccurred = history.last.map { usage < $0.usage * 0.2 } ?? false
            history.append(UsageHistory(
                date: date,
                usage: usage,
                resetOccurred: resetOccurred
            ))
        }
        
        // Keep only recent history
        let cutoff = Date().addingTimeInterval(-30 * 86400) // 30 days
        history.removeAll { $0.date < cutoff }
        
        usageHistory[provider] = history
    }
    
    private func generateMockHistoricalData(for provider: ServiceProvider) -> [Date: Double] {
        var data: [Date: Double] = [:]
        let now = Date()
        
        // Generate 30 days of mock data
        for day in 0..<30 {
            let date = now.addingTimeInterval(-Double(day) * 86400)
            let baseUsage = provider == .claude ? 50_000.0 : 10.0
            let variation = Double.random(in: 0.5...1.5)
            data[date] = baseUsage * variation * (30 - Double(day)) / 30
        }
        
        return data
    }
}

// MARK: - UI Integration

extension AutoPlanDetector.DetectedPlan {
    /// Get visual confidence indicator
    public var confidenceIndicator: String {
        switch confidence {
        case 80...100: return "🟢"
        case 60..<80: return "🟡"
        default: return "🔴"
        }
    }
    
    /// Get plan badge color
    public var planColor: Color {
        switch planType {
        case .free: return .gray
        case .basic: return .blue
        case .pro: return .purple
        case .team: return .orange
        case .enterprise: return .red
        case .unknown: return .secondary
        }
    }
    
    /// Get feature list for plan
    public var features: [String] {
        switch planType {
        case .free:
            return ["Limited usage", "Basic features"]
        case .basic:
            return ["Standard limits", "Priority support"]
        case .pro:
            return ["Higher limits", "Advanced features", "Priority support"]
        case .team:
            return ["Team collaboration", "Shared limits", "Admin controls"]
        case .enterprise:
            return ["Custom limits", "Dedicated support", "SLA"]
        case .unknown:
            return ["Unable to determine features"]
        }
    }
}