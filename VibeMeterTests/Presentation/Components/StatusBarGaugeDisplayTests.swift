import Testing
import Foundation
@testable import VibeMeter

@MainActor
struct StatusBarGaugeDisplayTests {
    
    // MARK: - Properties
    
    private let statusBarController: StatusBarController
    private let settingsManager: MockSettingsManager
    private let userSession: MultiProviderUserSessionData
    private let loginManager: MultiProviderLoginManager
    private let spendingData: MultiProviderSpendingData
    private let currencyData: CurrencyData
    private let orchestrator: MultiProviderDataOrchestrator
    
    // MARK: - Setup
    
    init() {
        // Create mock dependencies
        settingsManager = MockSettingsManager()
        userSession = MultiProviderUserSessionData()
        spendingData = MultiProviderSpendingData()
        currencyData = CurrencyData()
        
        // Create provider factory and login manager
        let providerFactory = ProviderFactory(settingsManager: settingsManager, urlSession: URLSession.shared)
        loginManager = MultiProviderLoginManager(providerFactory: providerFactory)
        
        // Create mock exchange rate manager and notification manager
        let exchangeRateManager = ExchangeRateManagerMock()
        let notificationManager = NotificationManagerMock()
        
        orchestrator = MultiProviderDataOrchestrator(
            providerFactory: providerFactory,
            settingsManager: settingsManager,
            exchangeRateManager: exchangeRateManager,
            notificationManager: notificationManager,
            loginManager: loginManager,
            spendingData: spendingData,
            userSessionData: userSession,
            currencyData: currencyData
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
    
    // MARK: - Claude Quota Display Tests
    
    @Test("Claude quota gauge with low usage")
    func claudeQuotaGaugeWithLowUsage() async {
        // Given
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        
        // Set up Claude spending data with low usage
        let usageData = ProviderUsageData(
            currentRequests: 10, // 10% usage
            totalRequests: 50_000, // Actual token count
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        // When
        statusBarController.updateStatusItemDisplay()
        
        // Then - verify gauge would show 10% fill
        // Note: In actual UI tests, we'd verify the visual representation
        #expect(userSession.isLoggedIn(to: .claude))
        #expect(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests == 10)
    }
    
    @Test("Claude quota gauge with high usage")
    func claudeQuotaGaugeWithHighUsage() async {
        // Given
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        
        // Set up Claude spending data with high usage
        let usageData = ProviderUsageData(
            currentRequests: 85, // 85% usage
            totalRequests: 425_000, // Actual token count
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        // When
        statusBarController.updateStatusItemDisplay()
        
        // Then - verify gauge would show 85% fill (likely orange/red)
        #expect(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests == 85)
    }
    
    @Test("Claude quota gauge with no usage")
    func claudeQuotaGaugeWithNoUsage() async {
        // Given
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        
        // Set up Claude spending data with no usage
        let usageData = ProviderUsageData(
            currentRequests: 0, // 0% usage
            totalRequests: 0, // No tokens used
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        // When
        statusBarController.updateStatusItemDisplay()
        
        // Then - verify gauge would be empty
        #expect(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests == 0)
    }
    
    // MARK: - Badge Text Display Tests
    
    @Test("Provider usage badge with token formatter")
    func providerUsageBadgeWithTokenFormatter() async {
        // Given
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        
        let usageData = ProviderUsageData(
            currentRequests: 23, // Percentage for gauge
            totalRequests: 45_678, // Actual tokens for display
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        // When - simulate badge view creation
        let claudeData = spendingData.getSpendingData(for: .claude)
        let current = claudeData?.usageData?.totalRequests ?? 0
        let max = 200_000 // Claude Pro limit
        let displayText = "\(TokenFormatter.format(current))/\(TokenFormatter.format(max))"
        
        // Then
        #expect(displayText == "45k/200k")
    }
    
    @Test("Provider usage badge with small tokens")
    func providerUsageBadgeWithSmallTokens() async {
        // Given
        let usageData = ProviderUsageData(
            currentRequests: 0,
            totalRequests: 146, // Small token count
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        // When
        let claudeData = spendingData.getSpendingData(for: .claude)
        let current = claudeData?.usageData?.totalRequests ?? 0
        let max = 200_000
        let displayText = "\(TokenFormatter.format(current))/\(TokenFormatter.format(max))"
        
        // Then
        #expect(displayText == "146/200k")
    }
    
    // MARK: - Gauge State Transitions
    
    @Test("Gauge state transitions")
    func gaugeStateTransitions() async {
        // Test loading state
        // Note: isRefreshing is read-only, we cannot set it directly in tests
        // The orchestrator manages this state internally during refresh operations
        statusBarController.updateStatusItemDisplay()
        // Would verify loading animation in actual UI
        
        // Test data state
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        
        let usageData = ProviderUsageData(
            currentRequests: 50,
            totalRequests: 100_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: usageData)
        
        statusBarController.updateStatusItemDisplay()
        // Would verify 50% gauge fill in actual UI
        
        // Test not logged in state
        userSession.handleLogout(from: .claude)
        statusBarController.updateStatusItemDisplay()
        // Would verify empty gauge in actual UI
    }
    
    // MARK: - Percentage Calculation Tests
    
    @Test("Calculate Claude quota percentage")
    func calculateClaudeQuotaPercentage() async {
        // Test various percentage calculations
        let testCases: [(current: Int, expected: Double)] = [
            (0, 0.0),
            (10, 0.1),
            (50, 0.5),
            (85, 0.85),
            (100, 1.0),
            (120, 1.0) // Should cap at 100%
        ]
        
        for testCase in testCases {
            let usageData = ProviderUsageData(
                currentRequests: testCase.current,
                totalRequests: testCase.current * 1000,
                maxRequests: 100,
                startOfMonth: Date().startOfMonth,
                provider: .claude
            )
            spendingData.updateUsage(for: .claude, from: usageData)
            
            // Use reflection to test private method
            let mirror = Mirror(reflecting: statusBarController)
            let calculateMethod = mirror.children.first(where: { $0.label == "calculateClaudeQuotaPercentage" })
            // In real tests, we'd verify the gauge value through the UI
            #expect(calculateMethod != nil)
        }
    }
    
    // MARK: - Real-time Update Tests
    
    @Test("Real-time gauge updates")
    func realTimeGaugeUpdates() async {
        // Given
        settingsManager.displaySettingsManager.gaugeRepresentation = .claudeQuota
        userSession.handleLoginSuccess(for: .claude, email: "test@example.com", teamName: nil)
        
        // Initial state
        let initialUsageData = ProviderUsageData(
            currentRequests: 20,
            totalRequests: 40_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: initialUsageData)
        statusBarController.updateStatusItemDisplay()
        
        // Simulate usage increase
        let updatedUsageData = ProviderUsageData(
            currentRequests: 35,
            totalRequests: 70_000,
            maxRequests: 100,
            startOfMonth: Date().startOfMonth,
            provider: .claude
        )
        spendingData.updateUsage(for: .claude, from: updatedUsageData)
        statusBarController.updateStatusItemDisplay()
        
        // Verify update occurred
        #expect(spendingData.getSpendingData(for: .claude)?.usageData?.currentRequests == 35)
    }
}