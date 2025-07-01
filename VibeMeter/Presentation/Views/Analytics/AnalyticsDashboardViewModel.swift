import Foundation
import Combine
import AppKit

/// View model for the analytics dashboard
@MainActor
final class AnalyticsDashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var realTimeStats: RealTimeMonitor.RealTimeStats?
    @Published private(set) var activeAlerts: [RealTimeMonitor.RealTimeStats.Alert] = []
    @Published private(set) var burnRateHistory: [ServiceProvider: [BurnRateDataPoint]] = [:]
    @Published private(set) var sessionAnalysis: ClaudeSessionTracker.SessionPatternAnalysis?
    
    struct BurnRateDataPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let rate: Double
    }
    
    // MARK: - Dependencies
    
    private let orchestrator: MultiProviderDataOrchestrator
    private let realTimeMonitor: RealTimeMonitor
    private let velocityTracker = VelocityTracker()
    private let predictionEngine = PredictionEngine()
    private let claudeLogManager = ClaudeLogManager.shared
    private let enhancedBurnRateCalculator = EnhancedBurnRateCalculator()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(orchestrator: MultiProviderDataOrchestrator? = nil) {
        // Get orchestrator from app delegate or use provided one
        if let orchestrator = orchestrator {
            self.orchestrator = orchestrator
        } else if let appDelegate = NSApp.delegate as? AppDelegate,
                  let appOrchestrator = appDelegate.multiProviderOrchestrator {
            self.orchestrator = appOrchestrator
        } else {
            // Create a minimal orchestrator for preview/testing
            let settings = SettingsManager.shared
            let factory = ProviderFactory(settingsManager: settings)
            let exchangeRate = ExchangeRateManager.shared
            let notification = NotificationManager()
            let login = MultiProviderLoginManager(providerFactory: factory)
            self.orchestrator = MultiProviderDataOrchestrator(
                providerFactory: factory,
                settingsManager: settings,
                exchangeRateManager: exchangeRate,
                notificationManager: notification,
                loginManager: login
            )
        }
        self.realTimeMonitor = RealTimeMonitor(orchestrator: self.orchestrator)
        
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func startMonitoring() {
        realTimeMonitor.startMonitoring()
        loadInitialData()
    }
    
    func stopMonitoring() {
        realTimeMonitor.stopMonitoring()
    }
    
    // MARK: - Data Access Methods
    
    func getCurrentUsageText(for provider: ServiceProvider) -> String {
        guard let stats = realTimeStats?.providerStats[provider] else {
            return "—"
        }
        
        switch provider {
        case .claude:
            return TokenFormatter.format(Int(stats.currentUsage))
        default:
            return stats.currentUsage.formattedCurrency
        }
    }
    
    func getUsageTrend(for provider: ServiceProvider) -> String? {
        guard let velocity = realTimeStats?.providerStats[provider]?.velocity else {
            return nil
        }
        
        let arrow = velocity.trend == .increasing ? "↑" : "↓"
        return "\(arrow) \(Int(abs(velocity.trendPercent)))%"
    }
    
    func getBurnRateText(for provider: ServiceProvider) -> String {
        guard let rate = realTimeStats?.providerStats[provider]?.burnRate else {
            return "—"
        }
        
        switch provider {
        case .claude:
            return "\(Int(rate))/hr"
        default:
            let dollarsPerHour = rate / 100
            return String(format: "$%.2f/hr", dollarsPerHour)
        }
    }
    
    func getBurnRateTrend(for provider: ServiceProvider) -> String? {
        guard let velocity = realTimeStats?.providerStats[provider]?.velocity else {
            return nil
        }
        
        return velocity.trendEmoji
    }
    
    func getTimeRemainingText(for provider: ServiceProvider) -> String {
        guard let prediction = realTimeStats?.predictions[provider] else {
            return "—"
        }
        
        return prediction.depletionText
    }
    
    func getEfficiencyText(for provider: ServiceProvider) -> String {
        if provider == .claude {
            let sessionTracker = claudeLogManager.getSessionTracker()
            let (_, _, efficiency) = sessionTracker.getSessionProgress()
            return "\(Int(efficiency)) tokens/min"
        } else {
            return "—"
        }
    }
    
    func getEfficiencyTrend(for provider: ServiceProvider) -> String? {
        // Could calculate efficiency trend over time
        return nil
    }
    
    func getVelocity(for provider: ServiceProvider) -> VelocityTracker.VelocityInfo? {
        realTimeStats?.providerStats[provider]?.velocity
    }
    
    func getCurrentVelocityText(for provider: ServiceProvider) -> String {
        guard let velocity = getVelocity(for: provider) else {
            return "—"
        }
        return formatVelocityRate(velocity.current, provider: provider)
    }
    
    func get24hVelocityText(for provider: ServiceProvider) -> String {
        guard let velocity = getVelocity(for: provider) else {
            return "—"
        }
        return formatVelocityRate(velocity.average24h, provider: provider)
    }
    
    func get7dVelocityText(for provider: ServiceProvider) -> String {
        guard let velocity = getVelocity(for: provider) else {
            return "—"
        }
        return formatVelocityRate(velocity.average7d, provider: provider)
    }
    
    func getPeakHourText(for provider: ServiceProvider) -> String {
        guard let velocity = getVelocity(for: provider) else {
            return "—"
        }
        return "\(velocity.peakHour):00"
    }
    
    func getPrediction(for provider: ServiceProvider) -> PredictionEngine.PredictionInfo? {
        realTimeStats?.predictions[provider]
    }
    
    func getSessionAnalysis() -> ClaudeSessionTracker.SessionPatternAnalysis? {
        sessionAnalysis
    }
    
    func getBurnRateHistory(for provider: ServiceProvider, range: AnalyticsDashboardView.TimeRange) -> [BurnRateDataPoint] {
        burnRateHistory[provider] ?? generateMockBurnRateHistory(range: range)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Subscribe to real-time updates
        realTimeMonitor.$currentStats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                self?.realTimeStats = stats
                self?.activeAlerts = stats.activeAlerts
            }
            .store(in: &cancellables)
        
        // Subscribe to event stream for history tracking
        realTimeMonitor.eventStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                self?.handleRealtimeEvent(event)
            }
            .store(in: &cancellables)
    }
    
    private func loadInitialData() {
        Task {
            // Load Claude session analysis
            if claudeLogManager.hasAccess {
                let sessionTracker = claudeLogManager.getSessionTracker()
                sessionAnalysis = sessionTracker.analyzeSessionPatterns()
            }
            
            // Load historical burn rate data
            await loadBurnRateHistory()
        }
    }
    
    private func handleRealtimeEvent(_ event: RealTimeMonitor.UpdateEvent) {
        switch event {
        case .burnRateChange(let provider, let rate):
            // Add to history
            var history = burnRateHistory[provider] ?? []
            history.append(BurnRateDataPoint(timestamp: Date(), rate: rate))
            
            // Keep only recent history
            let cutoff = Date().addingTimeInterval(-86400) // 24 hours
            history.removeAll { $0.timestamp < cutoff }
            
            burnRateHistory[provider] = history
            
        default:
            break
        }
    }
    
    private func loadBurnRateHistory() async {
        // In a real implementation, this would load from persistent storage
        // For now, generate some sample data
        for provider in ServiceProvider.allCases {
            burnRateHistory[provider] = generateMockBurnRateHistory(range: .day)
        }
    }
    
    private func generateMockBurnRateHistory(range: AnalyticsDashboardView.TimeRange) -> [BurnRateDataPoint] {
        var points: [BurnRateDataPoint] = []
        let now = Date()
        let interval = range.interval / 20 // 20 data points
        
        for i in 0..<20 {
            let timestamp = now.addingTimeInterval(-range.interval + (Double(i) * interval))
            let baseRate = 5000.0
            let variation = Double.random(in: -2000...2000)
            let rate = max(0, baseRate + variation + (Double(i) * 100)) // Slight upward trend
            
            points.append(BurnRateDataPoint(timestamp: timestamp, rate: rate))
        }
        
        return points
    }
    
    private func formatVelocityRate(_ rate: Double, provider: ServiceProvider) -> String {
        switch provider {
        case .claude:
            if rate >= 1000 {
                return String(format: "%.1fK/hr", rate / 1000)
            } else {
                return "\(Int(rate))/hr"
            }
        default:
            return String(format: "$%.2f/hr", rate / 100)
        }
    }
}

// MARK: - Mock Session Analysis

extension ClaudeSessionTracker.SessionPatternAnalysis {
    var formattedAverageLength: String {
        let minutes = Int(averageSessionLength / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            return String(format: "%.1fh", averageSessionLength / 3600)
        }
    }
    
    var formattedAverageGap: String {
        let minutes = Int(averageGapLength / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            return String(format: "%.1fh", averageGapLength / 3600)
        }
    }
    
    var recentSessions: [ClaudeSessionTracker.Session] {
        // This would come from the actual session tracker
        []
    }
}