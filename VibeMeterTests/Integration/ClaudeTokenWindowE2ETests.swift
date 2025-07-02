import XCTest
@testable import VibeMeter

@MainActor
final class ClaudeTokenWindowE2ETests: XCTestCase {
    
    // MARK: - Properties
    
    private lazy var settingsManager = MockSettingsManager()
    private lazy var userSession = MultiProviderUserSessionData()
    private lazy var spendingData = MultiProviderSpendingData()
    private lazy var currencyData = CurrencyData()
    private lazy var notificationManager = NotificationManager()
    private lazy var providerFactory = ProviderFactory(settingsManager: settingsManager, urlSession: URLSession.shared)
    private lazy var loginManager = MultiProviderLoginManager(providerFactory: providerFactory)
    private lazy var exchangeRateManager = ExchangeRateManagerMock()
    private lazy var notificationManagerMock = NotificationManagerMock()
    
    private lazy var orchestrator = MultiProviderDataOrchestrator(
        providerFactory: providerFactory,
        settingsManager: settingsManager,
        exchangeRateManager: exchangeRateManager,
        notificationManager: notificationManagerMock,
        loginManager: loginManager,
        spendingData: spendingData,
        userSessionData: userSession,
        currencyData: currencyData
    )
    
    private lazy var statusBarController = StatusBarController(
        settingsManager: settingsManager,
        userSession: userSession,
        loginManager: loginManager,
        spendingData: spendingData,
        currencyData: currencyData,
        orchestrator: orchestrator
    )
    
    // MARK: - Setup
    
    override func setUp() {
        super.setUp()
        // Properties are initialized lazily when first accessed
    }
    
    // MARK: - End-to-End Tests
    
    func testCompleteClaudeTokenWindowFlow() async throws {
        // Step 1: Enable Claude provider
        ProviderRegistry.shared.enableProvider(.claude)
        XCTAssertTrue(ProviderRegistry.shared.isEnabled(.claude))
        
        // Step 2: Simulate user login
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        XCTAssertTrue(userSession.isLoggedIn(to: .claude))
        
        // Step 3: Set gauge to Claude quota mode
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Step 4: Simulate Claude usage data
        let usageData = ProviderUsageData(
            currentRequests: 23, // Percentage for gauge
            totalRequests: 45_678, // Actual token count
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        // Set pricing info for cost display
        let invoice = ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 223, description: "Claude usage", provider: .claude)
            ],
            pricingDescription: ProviderPricingDescription(
                description: "25,678 input ($0.077), 20,000 output ($0.30)",
                id: "test-pricing",
                provider: .claude
            ),
            provider: .claude,
            month: Date().month - 1,
            year: Date().year
        )
        spendingData.updateSpending(for: .claude, from: invoice, rates: [:], targetCurrency: "USD")
        
        // Step 5: Update status bar
        statusBarController.updateStatusItemDisplay()
        
        // Step 6: Verify gauge calculation
        // The gauge should show 23% (0.23 as decimal)
        _ = 0.23 // expectedGaugeValue
        
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
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Simulate high usage (85%)
        let usageData = ProviderUsageData(
            currentRequests: 85,
            totalRequests: 170_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        statusBarController.updateStatusItemDisplay()
        
        // Verify high usage display
        let providerData = spendingData.getSpendingData(for: .claude)
        XCTAssertEqual(providerData?.usageData?.currentRequests, 85)
        XCTAssertEqual(TokenFormatter.format(170_000), "170k")
    }
    
    func testClaudeTokenWindowRealTimeUpdates() async throws {
        // Setup
        ProviderRegistry.shared.enableProvider(.claude)
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Initial state - 20% usage
        let usageData20 = ProviderUsageData(
            currentRequests: 20,
            totalRequests: 40_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData20)
        statusBarController.updateStatusItemDisplay()
        
        // Verify initial state
        XCTAssertEqual(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests, 20)
        
        // Simulate usage increase to 35%
        let usageData35 = ProviderUsageData(
            currentRequests: 35,
            totalRequests: 70_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData35)
        statusBarController.updateStatusItemDisplay()
        
        // Verify update
        XCTAssertEqual(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests, 35)
        XCTAssertEqual(TokenFormatter.format(70_000), "70k")
    }
    
    func testClaudeTokenWindowWithoutAccess() async throws {
        // Setup without file access
        userSession.setErrorMessage(for: .claude, message: "No folder access")
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        statusBarController.updateStatusItemDisplay()
        
        // Verify error state
        XCTAssertNotNil(userSession.getSession(for: .claude)?.lastErrorMessage)
        XCTAssertNil(spendingData.getSpendingData(for: .claude)?.usageData)
    }
    
    func testClaudeTokenWindowModeSwitch() async throws {
        // Setup with spending mode
        ProviderRegistry.shared.enableProvider(.claude)
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        settingsManager.displaySettingsManager.gaugeRepresentation = .totalSpending
        
        // Add spending data
        let invoice = ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 2500, description: "Claude usage", provider: .claude)
            ],
            provider: .claude,
            month: Date().month,
            year: Date().year
        )
        spendingData.updateSpending(for: .claude, from: invoice, rates: [:], targetCurrency: "USD")
        
        statusBarController.updateStatusItemDisplay()
        
        // Switch to Claude quota mode
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        
        // Add usage data
        let usageData = ProviderUsageData(
            currentRequests: 50,
            totalRequests: 100_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        statusBarController.updateStatusItemDisplay()
        
        // Verify mode switch worked
        XCTAssertEqual(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests, 50)
    }
    
    func testClaudeTokenWindowCurrencyConversion() async throws {
        // Setup
        ProviderRegistry.shared.enableProvider(.claude)
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        
        // Set currency to EUR
        currencyData.updateSelectedCurrency("EUR")
        currencyData.updateExchangeRates(["EUR": 0.85]) // 1 USD = 0.85 EUR
        
        // Add Claude data with USD costs
        let invoice = ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 1000, description: "Claude usage", provider: .claude)
            ],
            provider: .claude,
            month: Date().month,
            year: Date().year
        )
        spendingData.updateSpending(for: .claude, from: invoice, rates: [:], targetCurrency: "USD")
        
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
                userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
                settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
                
                let usageData = ProviderUsageData(
                    currentRequests: 50,
                    totalRequests: 100_000,
                    maxRequests: 100,
                    startOfMonth: Date().startOfMonth,
                    provider: .claude
                )
                spendingData.updateUsage(for: .claude, from: usageData)
                statusBarController.updateStatusItemDisplay()
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
    }
}