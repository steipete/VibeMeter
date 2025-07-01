import Testing
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
    
    init() {
        self.sut = RealTimeMonitor()
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
        #expect(sut.getRealtimeStats() == nil)
    }
    
    // MARK: - Monitoring Control Tests
    
    @Test("Start monitoring activates monitor")
    func startMonitoring() {
        // When
        sut.startMonitoring(interval: 5)
        
        // Then
        #expect(sut.isMonitoring)
    }
    
    @Test("Stop monitoring deactivates monitor")
    func stopMonitoring() {
        // Given
        sut.startMonitoring(interval: 5)
        
        // When
        sut.stopMonitoring()
        
        // Then
        #expect(!sut.isMonitoring)
    }
    
    // MARK: - Update Tests
    
    @Test("Update with new entry creates stats")
    func updateWithNewEntry() {
        // Given
        let entry = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3",
            inputTokens: 1000,
            outputTokens: 500
        )
        
        // When
        sut.updateWithEntry(entry, provider: .claude)
        
        // Then
        let stats = sut.getRealtimeStats()
        #expect(stats != nil)
        #expect(stats?.totalTokens == 1650) // input + output + cache tokens
        #expect(stats?.provider == .claude)
    }
    
    @Test("Multiple updates accumulate stats")
    func multipleUpdatesAccumulate() {
        // Given
        let entries = createMockLogEntries(count: 5)
        
        // When
        for entry in entries {
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // Then
        let stats = sut.getRealtimeStats()
        #expect(stats?.entryCount == 5)
        #expect(stats?.totalTokens > 0)
        #expect(stats?.averageTokensPerEntry > 0)
    }
    
    // MARK: - Statistics Tests
    
    @Test("Calculate statistics correctly")
    func calculateStatistics() {
        // Given
        let entries = createMockLogEntries(count: 10, interval: 60) // 1 minute intervals
        
        // When
        for entry in entries {
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // Then
        let stats = sut.getRealtimeStats()
        #expect(stats != nil)
        #expect(stats?.entryCount == 10)
        #expect(stats?.duration > 0)
        #expect(stats?.tokensPerMinute > 0)
        #expect(stats?.tokensPerHour == (stats?.tokensPerMinute ?? 0) * 60)
    }
    
    @Test("Peak usage detection")
    func peakUsageDetection() {
        // Given
        let now = Date()
        
        // Create entries with varying token counts
        let entries = [
            ClaudeLogEntry(timestamp: now, model: "claude-3", inputTokens: 1000, outputTokens: 500),
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-60), model: "claude-3", inputTokens: 5000, outputTokens: 2500), // Peak
            ClaudeLogEntry(timestamp: now.addingTimeInterval(-120), model: "claude-3", inputTokens: 2000, outputTokens: 1000)
        ]
        
        // When
        for entry in entries {
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // Then
        let stats = sut.getRealtimeStats()
        #expect(stats?.peakTokens == 7650) // 5000 + 2500 + 100 + 50
    }
    
    // MARK: - Alert Detection Tests
    
    @Test("Detect high usage alert", .tags(.alerts))
    func detectHighUsageAlert() {
        // Given
        let entries = (0..<5).map { _ in
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3",
                inputTokens: 10000,
                outputTokens: 5000
            )
        }
        
        // When
        for entry in entries {
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // Then
        let alerts = sut.checkForAlerts(threshold: 1000)
        #expect(!alerts.isEmpty)
        #expect(alerts.contains { alert in
            if case .highUsage = alert {
                return true
            }
            return false
        })
    }
    
    @Test("Detect sustained high usage alert", .tags(.alerts))
    func detectSustainedHighUsageAlert() {
        // Given - Create entries over 5 minutes with high usage
        let now = Date()
        let entries = (0..<10).map { i in
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(Double(-i) * 30), // 30 second intervals
                model: "claude-3",
                inputTokens: 5000,
                outputTokens: 2500
            )
        }
        
        // When
        for entry in entries {
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // Then
        let alerts = sut.checkForAlerts(threshold: 5000)
        #expect(alerts.contains { alert in
            if case .sustainedHighUsage = alert {
                return true
            }
            return false
        })
    }
    
    @Test("Detect spike alert", .tags(.alerts))
    func detectSpikeAlert() {
        // Given
        // Normal usage entries
        for i in 0..<5 {
            let entry = ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(Double(-i-5) * 60),
                model: "claude-3",
                inputTokens: 1000,
                outputTokens: 500
            )
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // Spike entry
        let spikeEntry = ClaudeLogEntry(
            timestamp: Date(),
            model: "claude-3",
            inputTokens: 50000,
            outputTokens: 25000
        )
        
        // When
        sut.updateWithEntry(spikeEntry, provider: .claude)
        
        // Then
        let alerts = sut.checkForAlerts(threshold: 2000)
        #expect(alerts.contains { alert in
            if case .spike = alert {
                return true
            }
            return false
        })
    }
    
    // MARK: - Event Stream Tests
    
    @Test("Event stream emits events")
    func eventStreamEmitsEvents() async throws {
        // Given
        let events = sut.eventStream
        var receivedEvents: [RealTimeMonitor.MonitorEvent] = []
        
        // Start collecting events
        let task = Task {
            for await event in events {
                receivedEvents.append(event)
                if receivedEvents.count >= 2 {
                    break
                }
            }
        }
        
        // When
        let entry1 = ClaudeLogEntry(timestamp: Date(), model: "claude-3", inputTokens: 1000, outputTokens: 500)
        sut.updateWithEntry(entry1, provider: .claude)
        
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        let entry2 = ClaudeLogEntry(timestamp: Date(), model: "claude-3", inputTokens: 2000, outputTokens: 1000)
        sut.updateWithEntry(entry2, provider: .claude)
        
        // Wait for events
        await task.value
        
        // Then
        #expect(receivedEvents.count >= 2)
        #expect(receivedEvents.allSatisfy { event in
            if case .statsUpdated = event {
                return true
            }
            return false
        })
    }
    
    // MARK: - Summary Generation Tests
    
    @Test("Generate summary with data")
    func generateSummaryWithData() {
        // Given
        let entries = createMockLogEntries(count: 20)
        for entry in entries {
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // When
        let summary = sut.getSummary()
        
        // Then
        #expect(summary.contains("📊"))
        #expect(summary.contains("Real-time"))
        #expect(summary.contains("tokens"))
        #expect(summary.contains("entries"))
    }
    
    @Test("Generate summary without data")
    func generateSummaryWithoutData() {
        // When
        let summary = sut.getSummary()
        
        // Then
        #expect(summary.contains("No monitoring data"))
    }
    
    // MARK: - Reset Tests
    
    @Test("Reset clears all data")
    func resetClearsData() {
        // Given
        let entries = createMockLogEntries(count: 5)
        for entry in entries {
            sut.updateWithEntry(entry, provider: .claude)
        }
        
        // When
        sut.reset()
        
        // Then
        #expect(sut.getRealtimeStats() == nil)
        #expect(sut.checkForAlerts(threshold: 1000).isEmpty)
    }
    
    // MARK: - Integration Tests
    
    @Test("Real-time monitoring flow")
    func realtimeMonitoringFlow() async throws {
        // Given
        sut.startMonitoring(interval: 1)
        
        // When
        // Simulate real usage
        for i in 0..<5 {
            let entry = ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3",
                inputTokens: 1000 * (i + 1),
                outputTokens: 500 * (i + 1)
            )
            sut.updateWithEntry(entry, provider: .claude)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        // Then
        let stats = sut.getRealtimeStats()
        #expect(stats != nil)
        #expect(stats?.entryCount == 5)
        #expect(sut.isMonitoring)
        
        // Cleanup
        sut.stopMonitoring()
    }
}

// MARK: - Alert Type Tests

@Suite("RealTimeMonitor Alert Tests", .tags(.alerts))
struct AlertTypeTests {
    
    @Test("Alert descriptions")
    func alertDescriptions() {
        // Given
        let alerts: [RealTimeMonitor.AlertType] = [
            .highUsage(current: 10000, threshold: 5000),
            .sustainedHighUsage(duration: 300, rate: 8000),
            .spike(current: 20000, average: 5000),
            .rapidAcceleration(rate: 150)
        ]
        
        // Then
        for alert in alerts {
            let description = alert.description
            #expect(description.contains("⚠️"))
            #expect(!description.isEmpty)
            
            // Verify specific content
            switch alert {
            case .highUsage:
                #expect(description.contains("High usage"))
            case .sustainedHighUsage:
                #expect(description.contains("Sustained"))
            case .spike:
                #expect(description.contains("Spike"))
            case .rapidAcceleration:
                #expect(description.contains("acceleration"))
            }
        }
    }
    
    @Test("Alert severity levels")
    func alertSeverityLevels() {
        // Given
        let alerts: [(RealTimeMonitor.AlertType, RealTimeMonitor.AlertType.Severity)] = [
            (.highUsage(current: 10000, threshold: 5000), .warning),
            (.sustainedHighUsage(duration: 300, rate: 8000), .critical),
            (.spike(current: 20000, average: 5000), .warning),
            (.rapidAcceleration(rate: 150), .critical)
        ]
        
        // Then
        for (alert, expectedSeverity) in alerts {
            #expect(alert.severity == expectedSeverity)
        }
    }
}

// MARK: - Statistics Tests

@Suite("RealTimeStats Tests")
struct RealTimeStatsTests {
    
    @Test("Format statistics display")
    func formatStatisticsDisplay() {
        // Given
        let stats = RealTimeMonitor.RealtimeStats(
            startTime: Date().addingTimeInterval(-3600),
            lastUpdate: Date(),
            entryCount: 100,
            totalTokens: 150000,
            averageTokensPerEntry: 1500,
            tokensPerMinute: 2500,
            tokensPerHour: 150000,
            peakTokens: 5000,
            provider: .claude
        )
        
        // When
        let formatted = stats.formattedDisplay
        
        // Then
        #expect(formatted.contains("100 entries"))
        #expect(formatted.contains("150K tokens"))
        #expect(formatted.contains("2.5K/min"))
        #expect(formatted.contains("150K/hr"))
    }
}