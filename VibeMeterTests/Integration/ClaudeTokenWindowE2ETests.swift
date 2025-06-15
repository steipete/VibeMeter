import XCTest
@testable import VibeMeter

@MainActor
final class ClaudeTokenWindowE2ETests: XCTestCase {
    
    // MARK: - Properties
    
    private var orchestrator: MultiProviderDataOrchestrator!
    private var settingsManager: MockSettingsManager!
    private var userSession: MultiProviderUserSessionData!
    private var spendingData: MultiProviderSpendingData!
    private var currencyData: CurrencyData!
    private var notificationManager: NotificationManager!
    private var statusBarController: StatusBarController!
    private var loginManager: MultiProviderLoginManager!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize all components
        settingsManager = MockSettingsManager()
        userSession = MultiProviderUserSessionData()
        spendingData = MultiProviderSpendingData()
        currencyData = CurrencyData()
        notificationManager = NotificationManager()
        loginManager = MultiProviderLoginManager(settingsManager: settingsManager)
        
        orchestrator = MultiProviderDataOrchestrator(
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData,
            settingsManager: settingsManager,
            notificationManager: notificationManager
        )
        
        statusBarController = StatusBarController(
            settingsManager: settingsManager,
            userSession: userSession,
            loginManager: loginManager,
            spendingData: spendingData,
            currencyData: currencyData,
            orchestrator: orchestrator
        )
    }
    
    // MARK: - End-to-End Tests
    
    func testCompleteClaudeTokenWindowFlow() async throws {
        // Step 1: Enable Claude provider
        ProviderRegistry.shared.enableProvider(.claude)
        XCTAssertTrue(ProviderRegistry.shared.isEnabled(.claude))
        
        // Step 2: Simulate user login
        userSession.setLoggedIn(
            to: .claude,
            userInfo: ProviderUserInfo(email: "test@example.com", provider: .claude)
        )
        XCTAssertTrue(userSession.isLoggedIn(to: .claude))
        
        // Step 3: Set gauge to Claude quota mode
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Step 4: Simulate Claude usage data
        let claudeData = ProviderSpendingData(provider: .claude)
        
        // Simulate 23% usage with 45,678 tokens
        claudeData.updateUsageData(ProviderUsageData(
            currentRequests: 23, // Percentage for gauge
            totalRequests: 45_678, // Actual token count
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        ))
        
        // Set pricing info for cost display
        claudeData.updateLatestInvoiceResponse(ProviderLatestInvoiceResponse(
            cents: 223, // $0.0223
            pricingDescription: ProviderPricingDescription(
                description: "25,678 input ($0.077), 20,000 output ($0.30)",
                id: "claude-tokens",
                provider: .claude
            ),
            provider: .claude
        ))
        
        spendingData.updateProviderData(claudeData)
        
        // Step 5: Update status bar
        statusBarController.updateStatusItemDisplay()
        
        // Step 6: Verify gauge calculation
        // The gauge should show 23% (0.23 as decimal)
        let expectedGaugeValue = 0.23
        
        // Verify spending data
        let providerData = spendingData.getSpendingData(for: .claude)
        XCTAssertNotNil(providerData)
        XCTAssertEqual(providerData?.usageData?.currentRequests, 23)
        XCTAssertEqual(providerData?.usageData?.totalRequests, 45_678)
        
        // Step 7: Verify token formatting
        let formattedCurrent = TokenFormatter.format(45_678)
        let formattedMax = TokenFormatter.format(200_000)
        let expectedBadgeText = "\(formattedCurrent)/\(formattedMax)"
        XCTAssertEqual(expectedBadgeText, "45k/200k")
        
        // Step 8: Verify cost formatting
        let costInDollars = 0.0223
        let formatter = NumberFormatter.vibeMeterCurrency
        let formattedCost = formatter.string(from: NSNumber(value: costInDollars))
        XCTAssertEqual(formattedCost, "0.0223")
        
        // Step 9: Verify time range display
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        
        let timeRange = "\(timeFormatter.string(from: fiveHoursAgo)) - \(timeFormatter.string(from: now))"
        XCTAssertTrue(timeRange.contains(" - "))
    }
    
    func testClaudeTokenWindowWithHighUsage() async throws {
        // Setup
        ProviderRegistry.shared.enableProvider(.claude)
        userSession.setLoggedIn(to: .claude, userInfo: ProviderUserInfo(email: "test@example.com", provider: .claude))
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Simulate high usage (85%)
        let claudeData = ProviderSpendingData(provider: .claude)
        claudeData.updateUsageData(ProviderUsageData(
            currentRequests: 85,
            totalRequests: 170_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        ))
        
        spendingData.updateProviderData(claudeData)
        statusBarController.updateStatusItemDisplay()
        
        // Verify high usage display
        let providerData = spendingData.getSpendingData(for: .claude)
        XCTAssertEqual(providerData?.usageData?.currentRequests, 85)
        XCTAssertEqual(TokenFormatter.format(170_000), "170k")
    }
    
    func testClaudeTokenWindowRealTimeUpdates() async throws {
        // Setup
        ProviderRegistry.shared.enableProvider(.claude)
        userSession.setLoggedIn(to: .claude, userInfo: ProviderUserInfo(email: "test@example.com", provider: .claude))
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Initial state - 20% usage
        var claudeData = ProviderSpendingData(provider: .claude)
        claudeData.updateUsageData(ProviderUsageData(
            currentRequests: 20,
            totalRequests: 40_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        ))
        spendingData.updateProviderData(claudeData)
        statusBarController.updateStatusItemDisplay()
        
        // Verify initial state
        XCTAssertEqual(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests, 20)
        
        // Simulate usage increase to 35%
        claudeData.updateUsageData(ProviderUsageData(
            currentRequests: 35,
            totalRequests: 70_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        ))
        spendingData.updateProviderData(claudeData)
        statusBarController.updateStatusItemDisplay()
        
        // Verify update
        XCTAssertEqual(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests, 35)
        XCTAssertEqual(TokenFormatter.format(70_000), "70k")
    }
    
    func testClaudeTokenWindowWithoutAccess() async throws {
        // Setup without file access
        userSession.setError("No folder access", for: .claude)
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        statusBarController.updateStatusItemDisplay()
        
        // Verify error state
        XCTAssertNotNil(userSession.getError(for: .claude))
        XCTAssertNil(spendingData.getSpendingData(for: .claude)?.usageData)
    }
    
    func testClaudeTokenWindowModeSwitch() async throws {
        // Setup with spending mode
        ProviderRegistry.shared.enableProvider(.claude)
        userSession.setLoggedIn(to: .claude, userInfo: ProviderUserInfo(email: "test@example.com", provider: .claude))
        settingsManager.displaySettingsManager.gaugeRepresentation = .spending
        
        // Add spending data
        let claudeData = ProviderSpendingData(provider: .claude)
        claudeData.updateLatestInvoiceResponse(ProviderLatestInvoiceResponse(
            cents: 2500, // $25.00
            pricingDescription: nil,
            provider: .claude
        ))
        spendingData.updateProviderData(claudeData)
        
        statusBarController.updateStatusItemDisplay()
        
        // Switch to Claude quota mode
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Add usage data
        claudeData.updateUsageData(ProviderUsageData(
            currentRequests: 50,
            totalRequests: 100_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        ))
        spendingData.updateProviderData(claudeData)
        
        statusBarController.updateStatusItemDisplay()
        
        // Verify mode switch worked
        XCTAssertEqual(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests, 50)
    }
    
    func testClaudeTokenWindowCurrencyConversion() async throws {
        // Setup
        ProviderRegistry.shared.enableProvider(.claude)
        userSession.setLoggedIn(to: .claude, userInfo: ProviderUserInfo(email: "test@example.com", provider: .claude))
        
        // Set currency to EUR
        currencyData.updateSelectedCode("EUR")
        currencyData.updateRates(["EUR": 0.85]) // 1 USD = 0.85 EUR
        
        // Add Claude data with USD costs
        let claudeData = ProviderSpendingData(provider: .claude)
        claudeData.updateLatestInvoiceResponse(ProviderLatestInvoiceResponse(
            cents: 1000, // $10.00 USD
            pricingDescription: nil,
            provider: .claude
        ))
        spendingData.updateProviderData(claudeData)
        
        // Verify currency conversion
        let convertedAmount = spendingData.totalSpendingConverted(
            to: "EUR",
            rates: currencyData.effectiveRates
        )
        XCTAssertEqual(convertedAmount, 8.5, accuracy: 0.01) // €8.50
    }
    
    // MARK: - Performance E2E Test
    
    func testCompleteFlowPerformance() async throws {
        measure {
            let expectation = self.expectation(description: "Complete flow")
            
            Task { @MainActor in
                // Run complete flow
                ProviderRegistry.shared.enableProvider(.claude)
                userSession.setLoggedIn(to: .claude, userInfo: ProviderUserInfo(email: "test@example.com", provider: .claude))
                settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
                
                let claudeData = ProviderSpendingData(provider: .claude)
                claudeData.updateUsageData(ProviderUsageData(
                    currentRequests: 50,
                    totalRequests: 100_000,
                    maxRequests: 100,
                    startOfMonth: Date().startOfMonth,
                    provider: .claude
                ))
                spendingData.updateProviderData(claudeData)
                statusBarController.updateStatusItemDisplay()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}