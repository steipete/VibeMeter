import Foundation
import os.log
import Combine

/// Real-time monitoring service for continuous usage tracking
@MainActor
public final class RealTimeMonitor: ObservableObject {
    private let logger = Logger.vibeMeter(category: "RealTimeMonitor")
    
    // MARK: - Types
    
    /// Real-time update event
    public enum UpdateEvent: Sendable {
        case tokenUsage(provider: ServiceProvider, tokens: Int, model: String)
        case sessionStart(provider: ServiceProvider)
        case sessionEnd(provider: ServiceProvider)
        case limitWarning(provider: ServiceProvider, percentage: Double)
        case anomalyDetected(provider: ServiceProvider, anomaly: String)
        case burnRateChange(provider: ServiceProvider, rate: Double)
    }
    
    /// Monitor configuration
    public struct Configuration: Sendable {
        public let updateInterval: TimeInterval
        public let enableAnomalyDetection: Bool
        public let enablePredictiveAlerts: Bool
        public let burnRateThreshold: Double
        public let providers: [ServiceProvider]
        
        public static let `default` = Configuration(
            updateInterval: 30, // 30 seconds
            enableAnomalyDetection: true,
            enablePredictiveAlerts: true,
            burnRateThreshold: 10000, // tokens/hour
            providers: ServiceProvider.allCases
        )
    }
    
    /// Real-time statistics
    @Published public private(set) var currentStats: RealTimeStats
    @Published public private(set) var isMonitoring = false
    @Published public private(set) var lastUpdate = Date()
    
    public struct RealTimeStats: Sendable {
        public let timestamp: Date
        public let providerStats: [ServiceProvider: ProviderStats]
        public let activeAlerts: [Alert]
        public let predictions: [ServiceProvider: PredictionEngine.PredictionInfo]
        
        public struct ProviderStats: Sendable {
            public let currentUsage: Double
            public let limit: Double
            public let burnRate: Double?
            public let velocity: VelocityTracker.VelocityInfo?
            public let sessionActive: Bool
            public let anomalies: [String]
        }
        
        public struct Alert: Sendable, Identifiable {
            public let id = UUID()
            public let provider: ServiceProvider
            public let type: AlertType
            public let message: String
            public let timestamp: Date
            public let severity: Severity
            
            public enum AlertType: String, Sendable {
                case usage = "Usage"
                case burnRate = "Burn Rate"
                case prediction = "Prediction"
                case anomaly = "Anomaly"
            }
            
            public enum Severity: Int, Sendable {
                case info = 0
                case warning = 1
                case critical = 2
            }
        }
    }
    
    // MARK: - Properties
    
    private let configuration: Configuration
    private var updateTimer: Timer?
    private var eventSubject = PassthroughSubject<UpdateEvent, Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // Service dependencies
    private let orchestrator: MultiProviderDataOrchestrator
    private let velocityTracker = VelocityTracker()
    private let predictionEngine = PredictionEngine()
    private let enhancedBurnRateCalculator = EnhancedBurnRateCalculator()
    private let claudeLogManager = ClaudeLogManager.shared
    
    // Real-time data
    private var lastKnownUsage: [ServiceProvider: Double] = [:]
    private var activeAlerts: [RealTimeStats.Alert] = []
    
    // MARK: - Public API
    
    /// Event stream for real-time updates
    public var eventStream: AnyPublisher<UpdateEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    public init(
        configuration: Configuration = .default,
        orchestrator: MultiProviderDataOrchestrator
    ) {
        self.configuration = configuration
        self.orchestrator = orchestrator
        self.currentStats = RealTimeStats(
            timestamp: Date(),
            providerStats: [:],
            activeAlerts: [],
            predictions: [:]
        )
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Start real-time monitoring
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        logger.info("Starting real-time monitoring")
        isMonitoring = true
        
        // Initial update
        Task {
            await performUpdate()
        }
        
        // Schedule periodic updates
        updateTimer = Timer.scheduledTimer(withTimeInterval: configuration.updateInterval, repeats: true) { _ in
            Task { @MainActor in
                await self.performUpdate()
            }
        }
    }
    
    /// Stop real-time monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.info("Stopping real-time monitoring")
        isMonitoring = false
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    /// Force an immediate update
    public func forceUpdate() async {
        await performUpdate()
    }
    
    /// Get current alert count by severity
    public func getAlertCounts() -> (info: Int, warning: Int, critical: Int) {
        let alerts = currentStats.activeAlerts
        return (
            info: alerts.filter { $0.severity == .info }.count,
            warning: alerts.filter { $0.severity == .warning }.count,
            critical: alerts.filter { $0.severity == .critical }.count
        )
    }
    
    /// Subscribe to specific provider updates
    public func subscribeToProvider(_ provider: ServiceProvider) -> AnyPublisher<UpdateEvent, Never> {
        eventStream.filter { event in
            switch event {
            case .tokenUsage(let p, _, _),
                 .sessionStart(let p),
                 .sessionEnd(let p),
                 .limitWarning(let p, _),
                 .anomalyDetected(let p, _),
                 .burnRateChange(let p, _):
                return p == provider
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // React to orchestrator updates
        // Note: spendingData is not @Published, need to observe differently
        // For now, rely on timer-based updates
    }
    
    private func performUpdate() async {
        logger.debug("Performing real-time update")
        
        var providerStats: [ServiceProvider: RealTimeStats.ProviderStats] = [:]
        var predictions: [ServiceProvider: PredictionEngine.PredictionInfo] = [:]
        var newAlerts: [RealTimeStats.Alert] = []
        
        for provider in configuration.providers {
            // Get current data
            let usage = await getCurrentUsage(for: provider)
            let limit = await getLimit(for: provider)
            let percentage = limit > 0 ? (usage / limit) * 100 : 0
            
            // Calculate burn rate
            let burnRate = await calculateBurnRate(for: provider, currentUsage: usage)
            
            // Get velocity
            let velocity = velocityTracker.calculateVelocity(for: provider)
            
            // Get prediction
            let prediction = predictionEngine.calculatePrediction(
                for: provider,
                currentUsage: usage,
                limit: limit,
                burnRate: burnRate?.basic
            )
            predictions[provider] = prediction
            
            // Check for anomalies
            let anomalies = await detectAnomalies(for: provider, burnRate: burnRate)
            
            // Check session status
            let sessionActive = await isSessionActive(for: provider)
            
            // Create provider stats
            let stats = RealTimeStats.ProviderStats(
                currentUsage: usage,
                limit: limit,
                burnRate: burnRate?.enhanced?.ratePerHour,
                velocity: velocity,
                sessionActive: sessionActive,
                anomalies: anomalies
            )
            providerStats[provider] = stats
            
            // Detect changes and emit events
            await detectAndEmitEvents(
                provider: provider,
                currentUsage: usage,
                burnRate: burnRate,
                percentage: percentage,
                sessionActive: sessionActive,
                anomalies: anomalies
            )
            
            // Generate alerts
            let alerts = generateAlerts(
                provider: provider,
                stats: stats,
                prediction: prediction
            )
            newAlerts.append(contentsOf: alerts)
        }
        
        // Update active alerts
        updateActiveAlerts(newAlerts)
        
        // Update published stats
        currentStats = RealTimeStats(
            timestamp: Date(),
            providerStats: providerStats,
            activeAlerts: activeAlerts,
            predictions: predictions
        )
        lastUpdate = Date()
    }
    
    private func getCurrentUsage(for provider: ServiceProvider) async -> Double {
        switch provider {
        case .claude:
            // Get real-time Claude usage
            let window = await claudeLogManager.getCurrentWindowUsage()
            return Double(window.tokensUsed)
        default:
            // Get usage from orchestrator
            let spending = orchestrator.spendingData.providerSpending[provider]
            return spending?.currentSpendingUSD ?? 0
        }
    }
    
    private func getLimit(for provider: ServiceProvider) async -> Double {
        switch provider {
        case .claude:
            return 200_000 // Token limit
        default:
            // TODO: Need public access to settings
            return 1000.0 // Default limit
        }
    }
    
    private func calculateBurnRate(
        for provider: ServiceProvider,
        currentUsage: Double
    ) async -> (basic: BurnRateCalculator.BurnRate?, enhanced: EnhancedBurnRateCalculator.EnhancedBurnRate?)? {
        switch provider {
        case .claude:
            // Get Claude sessions for burn rate
            let sessionTracker = claudeLogManager.getSessionTracker()
            let basicBurnRate = sessionTracker.calculateSessionAwareBurnRate()
            
            // Calculate enhanced burn rate
            let sessions = sessionTracker.getSessions()
            let enhancedBurnRate = enhancedBurnRateCalculator.calculateClaudeEnhancedBurnRate(
                sessions: sessions
            )
            
            return (basicBurnRate, enhancedBurnRate)
        default:
            // Use spending history for burn rate
            return nil
        }
    }
    
    private func detectAnomalies(
        for provider: ServiceProvider,
        burnRate: (basic: BurnRateCalculator.BurnRate?, enhanced: EnhancedBurnRateCalculator.EnhancedBurnRate?)?
    ) async -> [String] {
        guard configuration.enableAnomalyDetection,
              let enhanced = burnRate?.enhanced else {
            return []
        }
        
        let anomalies = enhancedBurnRateCalculator.detectAnomalies(
            currentRate: enhanced,
            provider: provider
        )
        
        return anomalies.map(\.description)
    }
    
    private func isSessionActive(for provider: ServiceProvider) async -> Bool {
        switch provider {
        case .claude:
            let sessionTracker = claudeLogManager.getSessionTracker()
            return sessionTracker.getActiveSession() != nil
        default:
            // Check if there's recent activity (within last 5 minutes)
            let usage = await getCurrentUsage(for: provider)
            let lastUsage = lastKnownUsage[provider] ?? 0
            return usage > lastUsage
        }
    }
    
    private func detectAndEmitEvents(
        provider: ServiceProvider,
        currentUsage: Double,
        burnRate: (basic: BurnRateCalculator.BurnRate?, enhanced: EnhancedBurnRateCalculator.EnhancedBurnRate?)?,
        percentage: Double,
        sessionActive: Bool,
        anomalies: [String]
    ) async {
        // Track usage changes
        let lastUsage = lastKnownUsage[provider] ?? 0
        if currentUsage > lastUsage {
            let delta = currentUsage - lastUsage
            if provider == .claude {
                eventSubject.send(.tokenUsage(
                    provider: provider,
                    tokens: Int(delta),
                    model: "claude-3"
                ))
            }
        }
        lastKnownUsage[provider] = currentUsage
        
        // Burn rate changes
        if let rate = burnRate?.enhanced?.ratePerHour,
           rate > configuration.burnRateThreshold {
            eventSubject.send(.burnRateChange(provider: provider, rate: rate))
        }
        
        // Limit warnings
        if percentage >= 90 {
            eventSubject.send(.limitWarning(provider: provider, percentage: percentage))
        }
        
        // Anomalies
        for anomaly in anomalies {
            eventSubject.send(.anomalyDetected(provider: provider, anomaly: anomaly))
        }
    }
    
    private func generateAlerts(
        provider: ServiceProvider,
        stats: RealTimeStats.ProviderStats,
        prediction: PredictionEngine.PredictionInfo?
    ) -> [RealTimeStats.Alert] {
        var alerts: [RealTimeStats.Alert] = []
        
        // Usage alerts
        let percentage = stats.limit > 0 ? (stats.currentUsage / stats.limit) * 100 : 0
        if percentage >= 90 {
            alerts.append(RealTimeStats.Alert(
                provider: provider,
                type: .usage,
                message: "Usage at \(Int(percentage))% of limit",
                timestamp: Date(),
                severity: .critical
            ))
        } else if percentage >= 70 {
            alerts.append(RealTimeStats.Alert(
                provider: provider,
                type: .usage,
                message: "Usage at \(Int(percentage))% of limit",
                timestamp: Date(),
                severity: .warning
            ))
        }
        
        // Burn rate alerts
        if let burnRate = stats.burnRate,
           burnRate > configuration.burnRateThreshold {
            alerts.append(RealTimeStats.Alert(
                provider: provider,
                type: .burnRate,
                message: "High burn rate: \(Int(burnRate))/hr",
                timestamp: Date(),
                severity: .warning
            ))
        }
        
        // Prediction alerts
        if let prediction = prediction,
           configuration.enablePredictiveAlerts {
            if prediction.hoursRemaining < 1 && prediction.confidence > 70 {
                alerts.append(RealTimeStats.Alert(
                    provider: provider,
                    type: .prediction,
                    message: prediction.recommendation,
                    timestamp: Date(),
                    severity: .critical
                ))
            }
        }
        
        // Anomaly alerts
        for anomaly in stats.anomalies {
            alerts.append(RealTimeStats.Alert(
                provider: provider,
                type: .anomaly,
                message: anomaly,
                timestamp: Date(),
                severity: .warning
            ))
        }
        
        return alerts
    }
    
    private func updateActiveAlerts(_ newAlerts: [RealTimeStats.Alert]) {
        // Keep alerts for 5 minutes
        let cutoff = Date().addingTimeInterval(-300)
        
        // Remove old alerts
        activeAlerts.removeAll { $0.timestamp < cutoff }
        
        // Add new alerts (avoid duplicates)
        for alert in newAlerts {
            let isDuplicate = activeAlerts.contains { existing in
                existing.provider == alert.provider &&
                existing.type == alert.type &&
                existing.message == alert.message &&
                existing.timestamp.timeIntervalSince(alert.timestamp) < 60
            }
            
            if !isDuplicate {
                activeAlerts.append(alert)
            }
        }
        
        // Sort by severity and timestamp
        activeAlerts.sort { lhs, rhs in
            if lhs.severity.rawValue != rhs.severity.rawValue {
                return lhs.severity.rawValue > rhs.severity.rawValue
            }
            return lhs.timestamp > rhs.timestamp
        }
    }
}

// MARK: - UI Integration

extension RealTimeMonitor.RealTimeStats {
    /// Get a summary view of all provider stats
    public var summary: String {
        var lines: [String] = []
        
        for (provider, stats) in providerStats.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            let percentage = stats.limit > 0 ? (stats.currentUsage / stats.limit) * 100 : 0
            let status = stats.sessionActive ? "🟢" : "⚫"
            let burnStr = stats.burnRate.map { " | \(Int($0))/hr" } ?? ""
            
            lines.append("\(status) \(provider.displayName): \(Int(percentage))%\(burnStr)")
        }
        
        if activeAlerts.isEmpty {
            lines.append("✅ No active alerts")
        } else {
            let counts = (
                critical: activeAlerts.filter { $0.severity == .critical }.count,
                warning: activeAlerts.filter { $0.severity == .warning }.count
            )
            lines.append("⚠️ Alerts: \(counts.critical) critical, \(counts.warning) warning")
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - WebSocket Support (Future Enhancement)

extension RealTimeMonitor {
    /// Placeholder for future WebSocket integration
    public func connectToLiveStream() async {
        logger.info("WebSocket live stream not yet implemented")
        // Future: Connect to provider APIs for real-time updates
    }
}