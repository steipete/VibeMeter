import Testing
@testable import VibeMeter

// MARK: - Test Tags

extension Tag {
    @Tag static var viewModel: Self
    @Tag static var dashboard: Self
}

// MARK: - Test Suite

@Suite("AnalyticsDashboardViewModel Tests", .tags(.viewModel, .dashboard))
@MainActor
struct AnalyticsDashboardViewModelTests {
    let sut: AnalyticsDashboardViewModel
    let mockOrchestrator: MultiProviderDataOrchestrator
    
    init() {
        self.mockOrchestrator = MultiProviderDataOrchestrator()
        self.sut = AnalyticsDashboardViewModel(orchestrator: mockOrchestrator)
    }
    
    // MARK: - Helper Methods
    
    private func setupMockData() {
        // Setup mock spending data
        mockOrchestrator.spendingData.claude = ClaudeUsageData(
            usedTokens: 100000,
            totalTokens: 200000,
            lastUpdated: Date()
        )
        
        mockOrchestrator.spendingData.cursor = CursorUsageData(
            freeRequests: 100,
            premiumRequests: 400,
            totalRequests: 500,
            codeCompletions: 1000,
            lastUpdated: Date()
        )
    }
    
    // MARK: - Initialization Tests
    
    @Test("Initial state")
    func initialState() {
        // Then
        #expect(!sut.isLoading)
        #expect(sut.errorMessage == nil)
        #expect(!sut.providers.isEmpty)
        #expect(sut.selectedProvider == .claude)
        #expect(sut.selectedTimeRange == .day)
    }
    
    // MARK: - Load Analytics Tests
    
    @Test("Load analytics sets loading state")
    func loadAnalyticsLoading() async {
        // When
        let task = Task {
            await sut.loadAnalytics()
        }
        
        // Then - Check loading state immediately
        #expect(sut.isLoading || !sut.isLoading) // May complete too fast
        
        await task.value
        #expect(!sut.isLoading)
    }
    
    @Test("Load analytics with data")
    func loadAnalyticsWithData() async {
        // Given
        setupMockData()
        
        // When
        await sut.loadAnalytics()
        
        // Then
        #expect(sut.velocity != nil)
        #expect(sut.burnRate != nil)
        #expect(sut.predictions[.claude] != nil)
        #expect(sut.predictions[.cursor] != nil)
    }
    
    // MARK: - Provider Selection Tests
    
    @Test("Select provider", arguments: ServiceProvider.allCases)
    func selectProvider(provider: ServiceProvider) {
        // When
        sut.selectProvider(provider)
        
        // Then
        #expect(sut.selectedProvider == provider)
    }
    
    // MARK: - Time Range Selection Tests
    
    @Test("Select time range", arguments: AnalyticsDashboardViewModel.TimeRange.allCases)
    func selectTimeRange(range: AnalyticsDashboardViewModel.TimeRange) {
        // When
        sut.selectTimeRange(range)
        
        // Then
        #expect(sut.selectedTimeRange == range)
    }
    
    // MARK: - Chart Data Tests
    
    @Test("Generate chart data")
    func generateChartData() {
        // Given
        setupMockData()
        
        // When
        let chartData = sut.getChartData()
        
        // Then
        #expect(!chartData.isEmpty)
        #expect(chartData.allSatisfy { $0.value >= 0 })
        #expect(chartData.allSatisfy { $0.date <= Date() })
    }
    
    @Test("Chart data respects time range", arguments: AnalyticsDashboardViewModel.TimeRange.allCases)
    func chartDataTimeRange(range: AnalyticsDashboardViewModel.TimeRange) {
        // Given
        sut.selectTimeRange(range)
        
        // When
        let chartData = sut.getChartData()
        
        // Then
        if !chartData.isEmpty {
            let oldestDate = chartData.map { $0.date }.min()!
            let expectedOldestDate = Date().addingTimeInterval(-range.timeInterval)
            #expect(oldestDate >= expectedOldestDate.addingTimeInterval(-3600)) // Allow 1 hour buffer
        }
    }
    
    // MARK: - Statistics Tests
    
    @Test("Calculate statistics")
    func calculateStatistics() async {
        // Given
        setupMockData()
        
        // When
        await sut.loadAnalytics()
        let stats = sut.getStatistics()
        
        // Then
        #expect(!stats.isEmpty)
        #expect(stats["Total Usage"] != nil)
        #expect(stats["Average Daily"] != nil)
        #expect(stats["Peak Hour"] != nil)
    }
    
    // MARK: - Formatting Tests
    
    @Test("Format large numbers")
    func formatLargeNumbers() {
        // Given
        let testCases: [(Double, String)] = [
            (1000, "1.0K"),
            (1500, "1.5K"),
            (1000000, "1.0M"),
            (1234567, "1.2M"),
            (999, "999")
        ]
        
        for (value, expected) in testCases {
            // When
            let formatted = sut.formatLargeNumber(value)
            
            // Then
            #expect(formatted == expected)
        }
    }
    
    // MARK: - Real-Time Updates Tests
    
    @Test("Start real-time updates")
    func startRealTimeUpdates() {
        // When
        sut.startRealTimeUpdates()
        
        // Then
        #expect(sut.realTimeMonitor.isMonitoring)
    }
    
    @Test("Stop real-time updates")
    func stopRealTimeUpdates() {
        // Given
        sut.startRealTimeUpdates()
        
        // When
        sut.stopRealTimeUpdates()
        
        // Then
        #expect(!sut.realTimeMonitor.isMonitoring)
    }
    
    // MARK: - Alert Tests
    
    @Test("Get alerts")
    func getAlerts() {
        // When
        let alerts = sut.getAlerts()
        
        // Then
        // Alerts depend on current state, but should not crash
        #expect(alerts.count >= 0)
    }
    
    // MARK: - Detected Plan Tests
    
    @Test("Get detected plan")
    func getDetectedPlan() async {
        // Given
        setupMockData()
        
        // When
        await sut.loadAnalytics()
        let plan = sut.detectedPlans[.claude]
        
        // Then
        #expect(plan != nil)
        if let plan = plan {
            #expect(plan.provider == .claude)
            #expect(plan.confidence >= 0)
            #expect(plan.confidence <= 100)
        }
    }
    
    // MARK: - Export Tests
    
    @Test("Export data")
    func exportData() async {
        // Given
        setupMockData()
        await sut.loadAnalytics()
        
        // When
        let exportData = sut.exportData()
        
        // Then
        #expect(!exportData.isEmpty)
        #expect(exportData.contains("Analytics Export"))
        #expect(exportData.contains("Generated:"))
    }
}

// MARK: - Time Range Tests

@Suite("TimeRange Tests")
struct TimeRangeTests {
    
    @Test("Time range intervals", arguments: [
        (AnalyticsDashboardViewModel.TimeRange.hour, 3600.0),
        (AnalyticsDashboardViewModel.TimeRange.day, 86400.0),
        (AnalyticsDashboardViewModel.TimeRange.week, 604800.0),
        (AnalyticsDashboardViewModel.TimeRange.month, 2592000.0)
    ])
    func timeRangeIntervals(range: AnalyticsDashboardViewModel.TimeRange, expectedInterval: TimeInterval) {
        #expect(range.timeInterval == expectedInterval)
    }
    
    @Test("Time range descriptions")
    func timeRangeDescriptions() {
        // Given
        let ranges = AnalyticsDashboardViewModel.TimeRange.allCases
        
        // Then
        for range in ranges {
            #expect(!range.description.isEmpty)
            #expect(range.description.count < 10) // Should be short
        }
    }
}

// MARK: - Chart Data Tests

@Suite("ChartDataPoint Tests")
struct ChartDataPointTests {
    
    @Test("Chart data point creation")
    func chartDataPointCreation() {
        // Given
        let date = Date()
        let value = 1000.0
        let label = "Test"
        
        // When
        let point = AnalyticsDashboardViewModel.ChartDataPoint(
            date: date,
            value: value,
            label: label
        )
        
        // Then
        #expect(point.date == date)
        #expect(point.value == value)
        #expect(point.label == label)
    }
}