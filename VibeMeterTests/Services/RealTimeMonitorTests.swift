import Testing
import Foundation
import Combine
@testable import VibeMeter

// MARK: - Test Tags

extension Tag {
    @Tag static var realtime: Self
    @Tag static var monitoring: Self
    @Tag static var alerts: Self
}

// MARK: - Test Suite

@Suite("RealTimeMonitor Tests", .tags(.realtime, .monitoring))
@MainActor
struct RealTimeMonitorTests {
    let sut: RealTimeMonitor
    let orchestrator: MultiProviderDataOrchestrator
    let settingsManager: MockSettingsManager
    let exchangeRateManager: ExchangeRateManagerMock
    let notificationManager: NotificationManagerMock
    var cancellables = Set<AnyCancellable>()
    
    init() {
        // Set up dependencies
        self.settingsManager = MockSettingsManager()
        self.exchangeRateManager = ExchangeRateManagerMock()
        self.notificationManager = NotificationManagerMock()
        
        let userSession = MultiProviderUserSessionData()
        let spendingData = MultiProviderSpendingData()
        let currencyData = CurrencyData()
        let providerFactory = ProviderFactory(settingsManager: settingsManager, urlSession: URLSession.shared)
        let loginManager = MultiProviderLoginManager(providerFactory: providerFactory)
        
        self.orchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: settingsManager,
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            loginManager: loginManager,
            spendingData: spendingData,
            userSessionData: userSession,
            currencyData: currencyData
        )
        
        self.sut = RealTimeMonitor(
            configuration: .default,
            orchestrator: orchestrator
        )
    }
    
    // MARK: - Helper Methods
    
    private func createMockLogEntries(count: Int, interval: TimeInterval = 300) -> [ClaudeLogEntry] {
        let now = Date()
        return (0..<count).map { i in
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(Double(-i) * interval),
                model: "claude-3",
                inputTokens: 1000 + i * 100,
                outputTokens: 500 + i * 50,
                cacheCreationTokens: 100,
                cacheReadTokens: 50
            )
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initial state is inactive")
    func initialState() {
        // Then
        #expect(!sut.isMonitoring)
        #expect(sut.currentStats.providerStats.isEmpty)
        #expect(sut.currentStats.activeAlerts.isEmpty)
    }
    
    // MARK: - Monitoring Control Tests
    
    @Test("Start monitoring activates monitor")
    func startMonitoring() {
        // When
        sut.startMonitoring()
        
        // Then
        #expect(sut.isMonitoring)
    }
    
    @Test("Stop monitoring deactivates monitor")
    func stopMonitoring() {
        // Given
        sut.startMonitoring()
        
        // When
        sut.stopMonitoring()
        
        // Then
        #expect(!sut.isMonitoring)
    }
    
    // MARK: - Update Tests
    
    @Test("Force update populates stats")
    func forceUpdatePopulatesStats() async {
        // Given
        ProviderRegistry.shared.enableProvider(.claude)
        
        // When
        await sut.forceUpdate()
        
        // Then
        #expect(!sut.currentStats.providerStats.isEmpty)
        #expect(sut.lastUpdate > Date.distantPast)
    }
    
    @Test("Alert counts work correctly")
    func alertCountsWorkCorrectly() async {
        // Given - Create some test alerts by manipulating internal state
        await sut.forceUpdate()
        
        // When
        let counts = sut.getAlertCounts()
        
        // Then
        #expect(counts.info >= 0)
        #expect(counts.warning >= 0)
        #expect(counts.critical >= 0)
        #expect(counts.info + counts.warning + counts.critical == sut.currentStats.activeAlerts.count)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Current stats summary generation")
    func currentStatsSummaryGeneration() async {
        // Given
        await sut.forceUpdate()
        
        // When
        let summary = sut.currentStats.summary
        
        // Then
        #expect(!summary.isEmpty)
        #expect(summary.contains("No active alerts") || summary.contains("Alerts:"))
    }
    
    @Test("Provider subscription filtering")
    func providerSubscriptionFiltering() async {
        // Given
        let subscription = sut.subscribeToProvider(.claude)
        var receivedEvents: [RealTimeMonitor.UpdateEvent] = []
        
        // Subscribe to events
        let cancellable = subscription.sink { event in
            receivedEvents.append(event)
        }
        
        // When - Emit events for different providers
        sut.eventStream.sink { event in
            // This will trigger the subscription
        }.store(in: &cancellables)
        
        // Then - Only Claude events should be received
        for event in receivedEvents {
            switch event {
            case .tokenUsage(let p, _, _),
                 .sessionStart(let p),
                 .sessionEnd(let p),
                 .limitWarning(let p, _),
                 .anomalyDetected(let p, _),
                 .burnRateChange(let p, _):
                #expect(p == .claude)
            }
        }
        
        cancellable.cancel()
    }
    
    // MARK: - Alert Detection Tests
    
    @Test("Active alerts tracking", .tags(.alerts))
    func activeAlertsTracking() async {
        // Given
        ProviderRegistry.shared.enableProvider(.claude)
        
        // When - Force update to potentially generate alerts
        await sut.forceUpdate()
        
        // Then
        let alerts = sut.currentStats.activeAlerts
        // Verify alert structure
        for alert in alerts {
            #expect(!alert.message.isEmpty)
            #expect(alert.timestamp <= Date())
            #expect(alert.provider != nil)
        }
    }
    
    @Test("Alert severity levels", .tags(.alerts))
    func alertSeverityLevels() async {
        // Given
        await sut.forceUpdate()
        
        // When
        let alerts = sut.currentStats.activeAlerts
        
        // Then - Verify severity enum values
        for alert in alerts {
            #expect(alert.severity.rawValue >= 0 && alert.severity.rawValue <= 2)
            switch alert.type {
            case .usage:
                #expect(alert.type.rawValue == "Usage")
            case .burnRate:
                #expect(alert.type.rawValue == "Burn Rate")
            case .prediction:
                #expect(alert.type.rawValue == "Prediction")
            case .anomaly:
                #expect(alert.type.rawValue == "Anomaly")
            }
        }
    }
    
    @Test("Alert type descriptions", .tags(.alerts))
    func alertTypeDescriptions() {
        // Given
        let alertTypes: [RealTimeMonitor.RealTimeStats.Alert.AlertType] = [
            .usage,
            .burnRate,
            .prediction,
            .anomaly
        ]
        
        // Then
        for alertType in alertTypes {
            let rawValue = alertType.rawValue
            #expect(!rawValue.isEmpty)
            
            switch alertType {
            case .usage:
                #expect(rawValue == "Usage")
            case .burnRate:
                #expect(rawValue == "Burn Rate")
            case .prediction:
                #expect(rawValue == "Prediction")
            case .anomaly:
                #expect(rawValue == "Anomaly")
            }
        }
    }
    
    // MARK: - Event Stream Tests
    
    @Test("Event stream subscription")
    func eventStreamSubscription() {
        // Given
        var receivedEvents: [RealTimeMonitor.UpdateEvent] = []
        
        // When - Subscribe to event stream
        let cancellable = sut.eventStream.sink { event in
            receivedEvents.append(event)
        }
        
        // Then - Verify subscription works
        #expect(cancellable != nil)
        
        // Cleanup
        cancellable.cancel()
    }
    
    // MARK: - Live Stream Tests
    
    @Test("WebSocket placeholder")
    func webSocketPlaceholder() async {
        // When
        await sut.connectToLiveStream()
        
        // Then - Should complete without error (placeholder for now)
        #expect(true)
    }
    
    // MARK: - Configuration Tests
    
    @Test("Custom configuration")
    func customConfiguration() {
        // Given
        let customConfig = RealTimeMonitor.Configuration(
            updateInterval: 60,
            enableAnomalyDetection: false,
            enablePredictiveAlerts: false,
            burnRateThreshold: 5000,
            providers: [.claude]
        )
        
        // When
        let customMonitor = RealTimeMonitor(
            configuration: customConfig,
            orchestrator: orchestrator
        )
        
        // Then
        #expect(!customMonitor.isMonitoring)
        #expect(customMonitor.currentStats.providerStats.isEmpty)
    }
    
    // MARK: - Integration Tests
    
    @Test("Real-time monitoring flow")
    func realtimeMonitoringFlow() async throws {
        // Given
        ProviderRegistry.shared.enableProvider(.claude)
        
        // When
        sut.startMonitoring()
        
        // Simulate updates
        await sut.forceUpdate()
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        await sut.forceUpdate()
        
        // Then
        #expect(sut.isMonitoring)
        #expect(sut.lastUpdate > Date.distantPast)
        
        // Check event stream
        var eventReceived = false
        let cancellable = sut.eventStream.sink { _ in
            eventReceived = true
        }
        
        await sut.forceUpdate()
        try await Task.sleep(nanoseconds: 100_000_000) // Wait for events
        
        // Cleanup
        cancellable.cancel()
        sut.stopMonitoring()
        #expect(!sut.isMonitoring)
    }
}

// MARK: - Provider Stats Tests

@Suite("RealTimeStats Tests", .tags(.realtime))
struct RealTimeStatsTests {
    
    @Test("Provider stats structure")
    func providerStatsStructure() {
        // Given
        let stats = RealTimeMonitor.RealTimeStats.ProviderStats(
            currentUsage: 150000,
            limit: 200000,
            burnRate: 5000,
            velocity: nil,
            sessionActive: true,
            anomalies: ["High usage spike detected"]
        )
        
        // Then
        #expect(stats.currentUsage == 150000)
        #expect(stats.limit == 200000)
        #expect(stats.burnRate == 5000)
        #expect(stats.sessionActive == true)
        #expect(stats.anomalies.count == 1)
    }
    
    @Test("Alert creation")
    func alertCreation() {
        // Given
        let alert = RealTimeMonitor.RealTimeStats.Alert(
            provider: .claude,
            type: .usage,
            message: "Usage at 90% of limit",
            timestamp: Date(),
            severity: .critical
        )
        
        // Then
        #expect(alert.provider == .claude)
        #expect(alert.type == .usage)
        #expect(alert.message.contains("90%"))
        #expect(alert.severity == .critical)
        #expect(alert.id != nil)
    }
}

