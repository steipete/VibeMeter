import Foundation
import Testing
@testable import VibeMeter

// MARK: - Claude Provider Tests

@Suite("Claude Provider Tests")
struct ClaudeProviderTests {
    // MARK: - Mock Settings Manager

    @MainActor
    private func createMockSettingsManager() -> any SettingsManagerProtocol {
        MockSettingsManager()
    }

    // MARK: - Provider Tests

    @Test("Claude provider initialization")
    @MainActor
    func providerInitialization() async {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        let providerType = await provider.provider
        #expect(providerType == .claude)
    }

    @Test("Claude provider validates token correctly")
    @MainActor
    func testValidateToken() async {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        // Test without access
        logManager.setHasAccess(false)
        let isInvalid = await provider.validateToken(authToken: "dummy_token")
        #expect(!isInvalid)

        // Test with access
        logManager.setHasAccess(true)
        let isValid = await provider.validateToken(authToken: "dummy_token")
        #expect(isValid)
    }

    @Test("Claude provider fetches user info")
    @MainActor
    func testFetchUserInfo() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        // Set up mock to have access
        logManager.setHasAccess(true)

        let userInfo = try await provider.fetchUserInfo(authToken: "dummy_token")

        #expect(userInfo.provider == .claude)
        #expect(userInfo.email == NSUserName())
        #expect(userInfo.teamId == nil)
    }

    @Test("Claude provider throws error for team info")
    @MainActor
    func fetchTeamInfoThrows() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        await #expect(throws: ProviderError.unsupportedProvider(.claude)) {
            _ = try await provider.fetchTeamInfo(authToken: "dummy_token")
        }
    }

    @Test("Claude provider authentication URL is local")
    @MainActor
    func authenticationURL() async {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        let url = provider.getAuthenticationURL()
        #expect(url.scheme == "file")
        #expect(url.host == "localhost")
    }

    @Test("Claude provider extracts dummy auth token")
    @MainActor
    func testExtractAuthToken() async {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        let token = provider.extractAuthToken(from: [:])
        #expect(token == "claude_local_access")
    }

    @Test("Claude provider fetches monthly invoice")
    @MainActor
    func testFetchMonthlyInvoice() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        // Set up mock data
        logManager.setHasAccess(true)
        let sampleUsage = ClaudeLogManagerMock.createSampleDailyUsage(daysCount: 5)
        logManager.setDailyUsage(sampleUsage)

        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1 // 0-indexed
        let year = calendar.component(.year, from: now)

        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: month,
            year: year,
            teamId: nil)

        #expect(invoice.provider == .claude)
        #expect(invoice.month == month)
        #expect(invoice.year == year)
        let totalCents = invoice.items.reduce(0) { $0 + $1.cents }
        #expect(totalCents > 0)
        #expect(logManager.callCount(for: "getDailyUsage") == 1)
    }

    @Test("Claude provider fetches usage data with five-hour window")
    @MainActor
    func testFetchUsageData() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        // Set up mock data
        logManager.setHasAccess(true)
        // Create sample daily usage data that will result in the desired five-hour window
        let sampleUsage = ClaudeLogManagerMock.createSampleDailyUsage(daysCount: 1)
        logManager.setDailyUsage(sampleUsage)
        logManager.setFiveHourWindow(used: 75, total: 100, resetDate: Date().addingTimeInterval(3600))

        let usage = try await provider.fetchUsageData(authToken: "dummy_token")

        #expect(usage.provider == .claude)
        #expect(usage.currentRequests == 75)
        #expect(usage.maxRequests == 100)
        #expect(logManager.callCount(for: "getDailyUsage") == 1)
        #expect(logManager.callCount(for: "calculateFiveHourWindow") == 1)
    }

    @Test("Claude provider throws error when no access")
    @MainActor
    func throwsErrorWhenNoAccess() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        // No access granted
        logManager.setHasAccess(false)

        await #expect(throws: ProviderError.self) {
            _ = try await provider.fetchMonthlyInvoice(
                authToken: "dummy_token",
                month: 0,
                year: 2025,
                teamId: nil)
        }
    }

    @Test("Claude provider caches daily usage")
    @MainActor
    func cachesDailyUsage() async throws {
        let settingsManager = createMockSettingsManager()
        let logManager = ClaudeLogManagerMock()
        let provider = ClaudeProvider(settingsManager: settingsManager, logManager: logManager)

        // Set up mock data
        logManager.setHasAccess(true)
        let sampleUsage = ClaudeLogManagerMock.createSampleDailyUsage(daysCount: 3)
        logManager.setDailyUsage(sampleUsage)

        // First call
        _ = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: 0,
            year: 2025,
            teamId: nil)

        // Second call within cache validity
        _ = try await provider.fetchMonthlyInvoice(
            authToken: "dummy_token",
            month: 0,
            year: 2025,
            teamId: nil)

        // Should only fetch once due to caching
        #expect(logManager.callCount(for: "getDailyUsage") == 1)
    }
}

// MARK: - Claude Data Model Tests

@Suite("Claude Data Model Tests")
struct ClaudeDataModelTests {
    @Test("ClaudeLogEntry decoding from JSON")
    func claudeLogEntryDecoding() throws {
        let json = """
        {
            "timestamp": "2025-01-06T10:30:00.000Z",
            "model": "claude-3.5-sonnet",
            "message": {
                "usage": {
                    "input_tokens": 1000,
                    "output_tokens": 500
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let entry = try decoder.decode(ClaudeLogEntry.self, from: Data(json.utf8))

        #expect(entry.model == "claude-3.5-sonnet")
        #expect(entry.inputTokens == 1000)
        #expect(entry.outputTokens == 500)
    }

    @Test("ClaudeLogEntry decoding with missing model")
    func claudeLogEntryDecodingWithoutModel() throws {
        let json = """
        {
            "timestamp": "2025-01-06T10:30:00Z",
            "message": {
                "usage": {
                    "input_tokens": 2000,
                    "output_tokens": 1000
                }
            }
        }
        """

        let decoder = JSONDecoder()
        let entry = try decoder.decode(ClaudeLogEntry.self, from: Data(json.utf8))

        #expect(entry.model == nil)
        #expect(entry.inputTokens == 2000)
        #expect(entry.outputTokens == 1000)
    }

    @Test("FiveHourWindow calculations")
    func fiveHourWindowCalculations() {
        let window = FiveHourWindow(
            used: 75,
            total: 100,
            resetDate: Date().addingTimeInterval(3600), // 1 hour from now
            tokensUsed: 75000,
            estimatedTokenLimit: 100_000)

        #expect(window.remaining == 25)
        #expect(window.percentageUsed == 75)
        #expect(window.percentageRemaining == 25)
        #expect(!window.isExhausted)
    }

    @Test("FiveHourWindow exhausted state")
    func fiveHourWindowExhausted() {
        let window = FiveHourWindow(
            used: 100,
            total: 100,
            resetDate: Date().addingTimeInterval(3600),
            tokensUsed: 100_000,
            estimatedTokenLimit: 100_000)

        #expect(window.remaining == 0)
        #expect(window.percentageUsed == 100)
        #expect(window.isExhausted)
    }

    @Test("ClaudeDailyUsage aggregation")
    func claudeDailyUsageAggregation() {
        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3.5-sonnet",
                inputTokens: 1000,
                outputTokens: 500),
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3.5-sonnet",
                inputTokens: 2000,
                outputTokens: 1000),
        ]

        let dailyUsage = ClaudeDailyUsage(
            date: Date(),
            entries: entries)

        #expect(dailyUsage.totalInputTokens == 3000)
        #expect(dailyUsage.totalOutputTokens == 1500)
        #expect(dailyUsage.totalTokens == 4500)
    }

    @Test("Claude cost calculation for Pro tier")
    func claudeCostCalculation() {
        let entries = [
            ClaudeLogEntry(
                timestamp: Date(),
                model: "claude-3.5-sonnet",
                inputTokens: 1_000_000, // 1M tokens
                outputTokens: 1_000_000 // 1M tokens
            ),
        ]

        let dailyUsage = ClaudeDailyUsage(
            date: Date(),
            entries: entries)

        // Pro tier pricing: $3 per 1M input, $15 per 1M output
        let cost = dailyUsage.calculateCostWithPricing(
            inputPricePerMillion: 3.0,
            outputPricePerMillion: 15.0)

        #expect(cost == 18.0) // $3 + $15
    }

    @Test("Claude pricing tier properties")
    func claudePricingTierProperties() {
        let freeTier = ClaudePricingTier.free
        let proTier = ClaudePricingTier.pro

        #expect(freeTier.displayName == "Free")
        #expect(proTier.displayName == "Pro ($20/mo)")

        #expect(freeTier.dailyMessageLimit == 50)
        #expect(proTier.messagesPerFiveHours == 45)

        #expect(!freeTier.usesFiveHourWindow)
        #expect(proTier.usesFiveHourWindow)
    }
}

// MARK: - Claude Settings Tests

@Suite("Claude Settings Tests", .tags(.settings))
struct ClaudeSettingsTests {
    @Test("Display settings gauge representation")
    @MainActor
    func gaugeRepresentationSetting() async {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer { userDefaults.removePersistentDomain(forName: #function) }

        let displaySettings = DisplaySettingsManager(userDefaults: userDefaults)

        // Default should be total spending
        #expect(displaySettings.gaugeRepresentation == .totalSpending)

        // Change to Claude quota
        displaySettings.gaugeRepresentation = .claudeQuota
        #expect(displaySettings.gaugeRepresentation == .claudeQuota)

        // Verify persistence
        let newSettings = DisplaySettingsManager(userDefaults: userDefaults)
        #expect(newSettings.gaugeRepresentation == .claudeQuota)
    }

    @Test("Session settings Claude account type")
    @MainActor
    func claudeAccountTypeSetting() async {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer { userDefaults.removePersistentDomain(forName: #function) }

        let sessionSettings = SessionSettingsManager(userDefaults: userDefaults)

        // Default should be Pro
        #expect(sessionSettings.claudeAccountType == .pro)

        // Change to Free
        sessionSettings.claudeAccountType = .free
        #expect(sessionSettings.claudeAccountType == .free)

        // Verify persistence
        let newSettings = SessionSettingsManager(userDefaults: userDefaults)
        #expect(newSettings.claudeAccountType == .free)
    }
}

// MARK: - Integration Tests

@Suite("Claude Integration Tests", .tags(.integration))
struct ClaudeIntegrationTests {
    @Test("Provider factory creates Claude provider")
    @MainActor
    func providerFactoryCreatesClaudeProvider() async {
        let settingsManager = MockSettingsManager()
        let factory = ProviderFactory(settingsManager: settingsManager)

        let provider = factory.createProvider(for: .claude)

        #expect(provider is ClaudeProvider)
    }

    @Test("Service provider Claude properties")
    func serviceProviderClaudeProperties() async {
        let provider = ServiceProvider.claude

        #expect(provider.displayName == "Claude")
        #expect(provider.websiteURL.absoluteString == "https://claude.ai")
        #expect(provider.dashboardURL.absoluteString == "https://claude.ai/usage")
        #expect(provider.keychainService == "com.steipete.vibemeter.claude")
        #expect(provider.defaultCurrency == "USD")
        #expect(!provider.supportsTeams)
        #expect(provider.iconName == "bubble.right")
        #expect(provider.brandColor == "#D97757")
    }
}
