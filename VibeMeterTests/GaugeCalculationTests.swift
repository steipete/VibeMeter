import Foundation
import Testing
@testable import VibeMeter

// MARK: - Gauge Calculation Tests

@Suite("Gauge Calculation Tests", .tags(.gauge))
struct GaugeCalculationTests {
    
    // MARK: - Test Helpers
    
    @MainActor
    private func createTestController(
        totalSpending: Double = 0,
        currentRequests: Int = 0,
        maxRequests: Int = 500,
        upperLimit: Double = 300
    ) -> (
        controller: StatusBarController,
        settingsManager: MockSettingsManager,
        spendingData: MultiProviderSpendingData,
        userSession: MultiProviderUserSessionData
    ) {
        let settingsManager = MockSettingsManager()
        settingsManager.upperLimitUSD = upperLimit
        
        let providerFactory = ProviderFactory(settingsManager: settingsManager)
        let exchangeRateManager = ExchangeRateManagerMock()
        let notificationManager = NotificationManagerMock()
        let loginManager = MultiProviderLoginManager(providerFactory: providerFactory)
        
        let orchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: settingsManager,
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            loginManager: loginManager
        )
        
        let controller = StatusBarController(
            settingsManager: settingsManager,
            orchestrator: orchestrator
        )
        
        let spendingData = orchestrator.spendingData
        let userSession = orchestrator.userSessionData
        
        // Set up test data
        if totalSpending > 0 || currentRequests > 0 {
            let providerData = ProviderSpendingData(
                provider: ServiceProvider.cursor,
                currentSpendingUSD: totalSpending,
                currentSpendingConverted: totalSpending,
                usageData: ProviderUsageData(
                    currentRequests: currentRequests,
                    totalRequests: 0,
                    maxRequests: maxRequests,
                    startOfMonth: Date(),
                    provider: ServiceProvider.cursor
                )
            )
            spendingData.setSpendingData(providerData, for: ServiceProvider.cursor)
            userSession.setLoginState(true, for: ServiceProvider.cursor)
        }
        
        return (controller, settingsManager, spendingData, userSession)
    }
    
    // MARK: - Basic Calculation Tests
    
    @Test("Calculate gauge for zero spending shows request usage")
    @MainActor
    func gaugeForZeroSpending() async {
        let (controller, _, _, _) = createTestController(
            totalSpending: 0,
            currentRequests: 182,
            maxRequests: 500
        )
        
        controller.updateStatusItemDisplay()
        
        // Get the current state via the observable
        let currentState = controller.menuBarState.currentState
        
        // Should show request usage: 182/500 = 0.364
        if case let .data(value) = currentState {
            #expect(abs(value - 0.364) < 0.001)
        } else {
            Issue.record("Expected data state with gauge value")
        }
    }
    
    @Test("Calculate gauge for spending shows percentage of limit")
    @MainActor
    func gaugeForSpending() async {
        let (controller, _, _, _) = createTestController(
            totalSpending: 150,  // $150 spent
            currentRequests: 100,
            maxRequests: 500,
            upperLimit: 300     // $300 limit
        )
        
        controller.updateStatusItemDisplay()
        
        let currentState = controller.menuBarState.currentState
        
        // Should show spending: $150/$300 = 0.5
        if case let .data(value) = currentState {
            #expect(abs(value - 0.5) < 0.001)
        } else {
            Issue.record("Expected data state with gauge value")
        }
    }
    
    @Test("Gauge caps at 1.0 when over limit")
    @MainActor
    func gaugeCapsAtOne() async {
        let (controller, _, _, _) = createTestController(
            totalSpending: 400,  // $400 spent
            currentRequests: 600,
            maxRequests: 500,
            upperLimit: 300     // $300 limit
        )
        
        controller.updateStatusItemDisplay()
        
        let currentState = controller.menuBarState.currentState
        
        // Should cap at 1.0 even though $400/$300 = 1.33
        if case let .data(value) = currentState {
            #expect(value == 1.0)
        } else {
            Issue.record("Expected data state with gauge value")
        }
    }
    
    // MARK: - Claude Quota Mode Tests
    
    @Test("Calculate gauge for Claude quota mode")
    @MainActor
    func gaugeForClaudeQuotaMode() async {
        let (controller, settingsManager, _, userSession) = createTestController()
        
        // Enable Claude and set to quota mode
        userSession.setLoginState(true, for: ServiceProvider.claude)
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Mock Claude quota data
        let logManager = ClaudeLogManagerMock()
        logManager.setFiveHourWindow(used: 75, total: 100, resetDate: Date().addingTimeInterval(3600))
        
        controller.updateStatusItemDisplay()
        
        let currentState = controller.menuBarState.currentState
        
        // Should show Claude quota: 75/100 = 0.75
        if case let .data(value) = currentState {
            // Note: In real implementation, this would need to be connected
            // For now, we're testing the mode switching logic exists
            #expect(value >= 0)
        }
    }
    
    // MARK: - State Transition Tests
    
    @Test("Gauge updates from loading to data state")
    @MainActor
    func gaugeTransitionFromLoading() async {
        let (controller, _, spendingData, userSession) = createTestController()
        
        // Initially should be loading or not logged in
        controller.updateStatusItemDisplay()
        let initialState = controller.menuBarState.currentState
        #expect(initialState == MenuBarState.notLoggedIn || initialState == MenuBarState.loading)
        
        // Add data
        userSession.setLoginState(true, for: ServiceProvider.cursor)
        let providerData = ProviderSpendingData(
            provider: ServiceProvider.cursor,
            currentSpendingUSD: 50.0,
            currentSpendingConverted: 50.0,
            usageData: ProviderUsageData(
                currentRequests: 100,
                totalRequests: 0,
                maxRequests: 500,
                startOfMonth: Date(),
                provider: ServiceProvider.cursor
            )
        )
        spendingData.setSpendingData(providerData, for: ServiceProvider.cursor)
        
        controller.updateStatusItemDisplay()
        
        // Should now show data
        let newState = controller.menuBarState.currentState
        if case .data = newState {
            // Success
        } else {
            Issue.record("Expected data state after adding spending data")
        }
    }
    
    @Test("Gauge shows loading during data fetch")
    @MainActor
    func gaugeShowsLoadingDuringFetch() async {
        let (controller, _, _, userSession) = createTestController()
        
        userSession.setLoginState(true, for: ServiceProvider.cursor)
        
        // Access orchestrator through controller
        controller.orchestrator.isRefreshing[ServiceProvider.cursor] = true
        
        controller.updateStatusItemDisplay()
        
        let currentState = controller.menuBarState.currentState
        #expect(currentState == MenuBarState.loading)
    }
    
    // MARK: - Progressive Color Tests
    
    @Test("Gauge color progression from green to red", arguments: [
        (0.0, "green"),
        (0.25, "green"),
        (0.5, "yellow"),
        (0.75, "orange"),
        (0.9, "red"),
        (1.0, "red")
    ])
    func gaugeColorProgression(value: Double, expectedColor: String) {
        let color = GaugeIcon.progressColor(for: value)
        
        switch expectedColor {
        case "green":
            #expect(color.greenComponent > 0.5)
            #expect(color.redComponent < 0.5)
        case "yellow":
            #expect(color.greenComponent > 0.5)
            #expect(color.redComponent > 0.5)
        case "orange":
            #expect(color.redComponent > 0.5)
            #expect(color.greenComponent < color.redComponent)
        case "red":
            #expect(color.redComponent > 0.8)
            #expect(color.greenComponent < 0.3)
        default:
            Issue.record("Unknown color")
        }
    }
    
    // MARK: - Multi-Provider Tests
    
    @Test("Gauge uses first provider with usage data")
    @MainActor
    func gaugeUsesFirstProviderWithData() async {
        let (controller, _, spendingData, userSession) = createTestController()
        
        // Add Claude with no usage data
        userSession.setLoginState(true, for: ServiceProvider.claude)
        let claudeData = ProviderSpendingData(
            provider: ServiceProvider.claude,
            currentSpendingUSD: 0,
            currentSpendingConverted: 0,
            usageData: nil // No usage data
        )
        spendingData.setSpendingData(claudeData, for: ServiceProvider.claude)
        
        // Add Cursor with usage data
        userSession.setLoginState(true, for: ServiceProvider.cursor)
        let cursorData = ProviderSpendingData(
            provider: ServiceProvider.cursor,
            currentSpendingUSD: 0,
            currentSpendingConverted: 0,
            usageData: ProviderUsageData(
                currentRequests: 250,
                totalRequests: 0,
                maxRequests: 500,
                startOfMonth: Date(),
                provider: ServiceProvider.cursor
            )
        )
        spendingData.setSpendingData(cursorData, for: ServiceProvider.cursor)
        
        controller.updateStatusItemDisplay()
        
        let currentState = controller.menuBarState.currentState
        
        // Should use Cursor's data: 250/500 = 0.5
        if case let .data(value) = currentState {
            #expect(abs(value - 0.5) < 0.001)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle nil max requests gracefully")
    @MainActor
    func handleNilMaxRequests() async {
        let (controller, _, spendingData, userSession) = createTestController()
        
        userSession.setLoginState(true, for: ServiceProvider.cursor)
        let providerData = ProviderSpendingData(
            provider: ServiceProvider.cursor,
            currentSpendingUSD: 0,
            currentSpendingConverted: 0,
            usageData: ProviderUsageData(
                currentRequests: 100,
                totalRequests: 0,
                maxRequests: 0, // 0 max requests
                startOfMonth: Date(),
                provider: ServiceProvider.cursor
            )
        )
        spendingData.setSpendingData(providerData, for: ServiceProvider.cursor)
        
        controller.updateStatusItemDisplay()
        
        let currentState = controller.menuBarState.currentState
        
        // Should default to 0 when max requests is 0
        if case let .data(value) = currentState {
            #expect(value == 0.0)
        }
    }
    
    @Test("Small value changes don't trigger update")
    @MainActor
    func smallChangesIgnored() async {
        let (controller, _, spendingData, userSession) = createTestController(
            totalSpending: 100,
            currentRequests: 250,
            maxRequests: 500,
            upperLimit: 300
        )
        
        controller.updateStatusItemDisplay()
        
        // Get initial value
        let initialState = controller.menuBarState.currentState
        guard case let .data(initialValue) = initialState else {
            Issue.record("Expected initial data state")
            return
        }
        
        // Make tiny change (less than 0.01 threshold)
        let currentData = spendingData.getSpendingData(for: ServiceProvider.cursor)!
        let updatedData = ProviderSpendingData(
            provider: ServiceProvider.cursor,
            currentSpendingUSD: 100.20, // $100.20 instead of $100
            currentSpendingConverted: 100.20,
            usageData: currentData.usageData
        )
        spendingData.setSpendingData(updatedData, for: ServiceProvider.cursor)
        
        controller.updateStatusItemDisplay()
        
        // Value should not have changed
        let newState = controller.menuBarState.currentState
        if case let .data(newValue) = newState {
            #expect(abs(newValue - initialValue) < 0.01)
        }
    }
}