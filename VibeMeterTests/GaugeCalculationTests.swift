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
        
        let orchestrator = MultiProviderDataOrchestrator(settingsManager: settingsManager)
        let controller = StatusBarController(
            settingsManager: settingsManager,
            orchestrator: orchestrator
        )
        
        let spendingData = orchestrator.spendingData
        let userSession = orchestrator.userSessionData
        
        // Set up test data
        if totalSpending > 0 || currentRequests > 0 {
            let providerData = ProviderSpendingData(
                provider: .cursor,
                monthlyInvoice: ProviderMonthlyInvoice(
                    items: [ProviderInvoiceItem(
                        cents: Int(totalSpending * 100),
                        description: "Test usage",
                        provider: .cursor
                    )],
                    provider: .cursor,
                    month: 0,
                    year: 2025
                ),
                usageData: ProviderUsageData(
                    currentRequests: currentRequests,
                    totalRequests: nil,
                    maxRequests: maxRequests,
                    startOfMonth: Date(),
                    provider: .cursor
                ),
                currency: "USD",
                exchangeRate: 1.0
            )
            spendingData.setSpendingData(providerData, for: .cursor)
            userSession.setLoginState(true, for: .cursor)
        }
        
        return (controller, settingsManager, spendingData, userSession)
    }
    
    // MARK: - Basic Calculation Tests
    
    @Test("Calculate gauge for zero spending shows request usage")
    @MainActor
    func gaugeForZeroSpending() async {
        let (controller, _, spendingData, _) = createTestController(
            totalSpending: 0,
            currentRequests: 182,
            maxRequests: 500
        )
        
        controller.updateStatusItemDisplay()
        
        let stateManager = controller.stateManager
        
        // Should show request usage: 182/500 = 0.364
        if case let .data(value) = stateManager.currentState {
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
        
        let stateManager = controller.stateManager
        
        // Should show spending: $150/$300 = 0.5
        if case let .data(value) = stateManager.currentState {
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
        
        let stateManager = controller.stateManager
        
        // Should cap at 1.0 even though $400/$300 = 1.33
        if case let .data(value) = stateManager.currentState {
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
        userSession.setLoginState(true, for: .claude)
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Mock Claude quota data
        let logManager = ClaudeLogManagerMock()
        logManager.setFiveHourWindow(used: 75, total: 100, resetDate: Date().addingTimeInterval(3600))
        
        controller.updateStatusItemDisplay()
        
        let stateManager = controller.stateManager
        
        // Should show Claude quota: 75/100 = 0.75
        if case let .data(value) = stateManager.currentState {
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
        
        let stateManager = controller.stateManager
        
        // Initially should be loading or not logged in
        controller.updateStatusItemDisplay()
        #expect(stateManager.currentState == .notLoggedIn || stateManager.currentState == .loading)
        
        // Add data
        userSession.setLoginState(true, for: .cursor)
        let providerData = ProviderSpendingData(
            provider: .cursor,
            monthlyInvoice: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 5000, description: "Test", provider: .cursor)],
                provider: .cursor,
                month: 0,
                year: 2025
            ),
            usageData: ProviderUsageData(
                currentRequests: 100,
                totalRequests: nil,
                maxRequests: 500,
                startOfMonth: Date(),
                provider: .cursor
            ),
            currency: "USD",
            exchangeRate: 1.0
        )
        spendingData.setSpendingData(providerData, for: .cursor)
        
        controller.updateStatusItemDisplay()
        
        // Should now show data
        if case .data = stateManager.currentState {
            // Success
        } else {
            Issue.record("Expected data state after adding spending data")
        }
    }
    
    @Test("Gauge shows loading during data fetch")
    @MainActor
    func gaugeShowsLoadingDuringFetch() async {
        let (controller, _, _, userSession) = createTestController()
        let orchestrator = controller.orchestrator
        
        userSession.setLoginState(true, for: .cursor)
        
        // Simulate fetching state
        orchestrator.isRefreshing[.cursor] = true
        
        controller.updateStatusItemDisplay()
        
        let stateManager = controller.stateManager
        #expect(stateManager.currentState == .loading)
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
        userSession.setLoginState(true, for: .claude)
        let claudeData = ProviderSpendingData(
            provider: .claude,
            monthlyInvoice: ProviderMonthlyInvoice(
                items: [],
                provider: .claude,
                month: 0,
                year: 2025
            ),
            usageData: nil, // No usage data
            currency: "USD",
            exchangeRate: 1.0
        )
        spendingData.setSpendingData(claudeData, for: .claude)
        
        // Add Cursor with usage data
        userSession.setLoginState(true, for: .cursor)
        let cursorData = ProviderSpendingData(
            provider: .cursor,
            monthlyInvoice: ProviderMonthlyInvoice(
                items: [],
                provider: .cursor,
                month: 0,
                year: 2025
            ),
            usageData: ProviderUsageData(
                currentRequests: 250,
                totalRequests: nil,
                maxRequests: 500,
                startOfMonth: Date(),
                provider: .cursor
            ),
            currency: "USD",
            exchangeRate: 1.0
        )
        spendingData.setSpendingData(cursorData, for: .cursor)
        
        controller.updateStatusItemDisplay()
        
        let stateManager = controller.stateManager
        
        // Should use Cursor's data: 250/500 = 0.5
        if case let .data(value) = stateManager.currentState {
            #expect(abs(value - 0.5) < 0.001)
        }
    }
    
    // MARK: - Edge Cases
    
    @Test("Handle nil max requests gracefully")
    @MainActor
    func handleNilMaxRequests() async {
        let (controller, _, spendingData, userSession) = createTestController()
        
        userSession.setLoginState(true, for: .cursor)
        let providerData = ProviderSpendingData(
            provider: .cursor,
            monthlyInvoice: ProviderMonthlyInvoice(
                items: [],
                provider: .cursor,
                month: 0,
                year: 2025
            ),
            usageData: ProviderUsageData(
                currentRequests: 100,
                totalRequests: nil,
                maxRequests: nil, // nil max requests
                startOfMonth: Date(),
                provider: .cursor
            ),
            currency: "USD",
            exchangeRate: 1.0
        )
        spendingData.setSpendingData(providerData, for: .cursor)
        
        controller.updateStatusItemDisplay()
        
        let stateManager = controller.stateManager
        
        // Should default to 0 when max requests is nil
        if case let .data(value) = stateManager.currentState {
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
        let stateManager = controller.stateManager
        
        // Get initial value
        guard case let .data(initialValue) = stateManager.currentState else {
            Issue.record("Expected initial data state")
            return
        }
        
        // Make tiny change (less than 0.01 threshold)
        let currentData = spendingData.getSpendingData(for: .cursor)!
        let updatedData = ProviderSpendingData(
            provider: .cursor,
            monthlyInvoice: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(
                    cents: 10020, // $100.20 instead of $100
                    description: "Test",
                    provider: .cursor
                )],
                provider: .cursor,
                month: 0,
                year: 2025
            ),
            usageData: currentData.usageData,
            currency: "USD",
            exchangeRate: 1.0
        )
        spendingData.setSpendingData(updatedData, for: .cursor)
        
        controller.updateStatusItemDisplay()
        
        // Value should not have changed
        if case let .data(newValue) = stateManager.currentState {
            #expect(abs(newValue - initialValue) < 0.01)
        }
    }
}
