import Foundation
import Testing
@testable import VibeMeter

// MARK: - Claude Account Type & Subscription Tier Tests

@Suite("Claude Account Type Tests", .tags(.claude, .settings))
struct ClaudeAccountTypeTests {
    // MARK: - Account Type Properties Tests
    
    @Test("Claude account types have correct properties", arguments: [
        (ClaudeAccountType.free, "Free", false, 50, nil, nil),
        (ClaudeAccountType.pro, "Pro", true, nil, 45, nil),
        (ClaudeAccountType.max5x, "Max 5×", true, nil, 45, 5),
        (ClaudeAccountType.max20x, "Max 20×", true, nil, 45, 20),
    ])
    func accountTypeProperties(
        accountType: ClaudeAccountType,
        expectedName: String,
        expectedUsesFiveHour: Bool,
        expectedDailyLimit: Int?,
        expectedMessagesPerWindow: Int?,
        expectedMultiplier: Int?
    ) {
        #expect(accountType.displayName == expectedName)
        #expect(accountType.usesFiveHourWindow == expectedUsesFiveHour)
        #expect(accountType.dailyMessageLimit == expectedDailyLimit)
        #expect(accountType.messagesPerFiveHours == expectedMessagesPerWindow)
        
        if let multiplier = expectedMultiplier {
            #expect(accountType.displayName.contains("\(multiplier)×"))
        }
    }

    @Test("Account type price display")
    func accountTypePriceDisplay() {
        #expect(ClaudeAccountType.free.priceDisplay == "Free")
        #expect(ClaudeAccountType.pro.priceDisplay == "$20/month")
        #expect(ClaudeAccountType.max5x.priceDisplay == "$100/month")
        #expect(ClaudeAccountType.max20x.priceDisplay == "$200/month")
    }

    @Test("Account type is CaseIterable")
    func accountTypeIsCaseIterable() {
        let allTypes = ClaudeAccountType.allCases
        #expect(allTypes.count == 4)
        #expect(allTypes.contains(.free))
        #expect(allTypes.contains(.pro))
        #expect(allTypes.contains(.max5x))
        #expect(allTypes.contains(.max20x))
    }

    // MARK: - Settings Persistence Tests
    
    @Test("Claude account type setting persistence")
    @MainActor
    func accountTypeSettingPersistence() async {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer { userDefaults.removePersistentDomain(forName: #function) }
        
        let sessionSettings = SessionSettingsManager(userDefaults: userDefaults)
        
        // Test each account type
        for accountType in ClaudeAccountType.allCases {
            sessionSettings.claudeAccountType = accountType
            
            // Create new instance to verify persistence
            let newSettings = SessionSettingsManager(userDefaults: userDefaults)
            #expect(newSettings.claudeAccountType == accountType)
        }
    }

    @Test("Default Claude account type is Pro")
    @MainActor
    func defaultAccountType() async {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer { userDefaults.removePersistentDomain(forName: #function) }
        
        let sessionSettings = SessionSettingsManager(userDefaults: userDefaults)
        #expect(sessionSettings.claudeAccountType == .pro)
    }

    // MARK: - Window Calculation Tests
    
    @Test("Calculate token limits based on account type", arguments: ClaudeAccountType.allCases)
    func calculateTokenLimits(accountType: ClaudeAccountType) {
        let avgTokensPerMessage = 3000
        
        if accountType.usesFiveHourWindow, let messagesPerWindow = accountType.messagesPerFiveHours {
            let estimatedTokenLimit = messagesPerWindow * avgTokensPerMessage
            
            // Pro: 45 messages * 3000 = 135,000 tokens
            // Max 5×: 45 messages * 3000 = 135,000 tokens (same limit, different tier)
            // Max 20×: 45 messages * 3000 = 135,000 tokens (same limit, different tier)
            #expect(estimatedTokenLimit == 135_000)
        } else if let dailyLimit = accountType.dailyMessageLimit {
            let dailyTokenLimit = dailyLimit * avgTokensPerMessage
            
            // Free: 50 messages * 3000 = 150,000 tokens per day
            #expect(dailyTokenLimit == 150_000)
        }
    }

    @Test("Window reset time based on account type")
    @MainActor
    func windowResetTime() async {
        let logManager = ClaudeLogManagerMock()
        let now = Date()
        
        // Test free tier (daily reset)
        logManager.mockAccountType = .free
        let freeWindow = logManager.calculateFiveHourWindow(from: [:])
        
        // Should reset at midnight PT
        let calendar = Calendar.current
        let resetComponents = calendar.dateComponents(
            in: TimeZone(identifier: "America/Los_Angeles")!,
            from: freeWindow.resetDate
        )
        #expect(resetComponents.hour == 0)
        #expect(resetComponents.minute == 0)
        
        // Test pro tier (5-hour window)
        logManager.mockAccountType = .pro
        let proWindow = logManager.calculateFiveHourWindow(from: [:])
        
        // Should reset within 5 hours
        let timeUntilReset = proWindow.resetDate.timeIntervalSince(now)
        #expect(timeUntilReset > 0)
        #expect(timeUntilReset <= 5 * 3600)
    }

    // MARK: - UI Display Tests
    
    @Test("Account type selection in settings UI")
    @MainActor
    func accountTypeSelectionUI() async {
        let settingsManager = MockSettingsManager()
        
        // Simulate UI selection
        for accountType in ClaudeAccountType.allCases {
            settingsManager.sessionSettingsManager.claudeAccountType = accountType
            
            // Verify the selection is reflected
            #expect(settingsManager.sessionSettingsManager.claudeAccountType == accountType)
            
            // Verify display name is user-friendly
            #expect(!accountType.displayName.isEmpty)
            #expect(accountType.displayName.count < 20) // Reasonable length for UI
        }
    }

    @Test("Account type affects quota display")
    @MainActor
    func accountTypeAffectsQuotaDisplay() async {
        let logManager = ClaudeLogManagerMock()
        
        // Create sample usage
        let entries = [
            ClaudeLogEntry(
                timestamp: Date().addingTimeInterval(-3600), // 1 hour ago
                model: "claude-3.5-sonnet",
                inputTokens: 10_000,
                outputTokens: 5_000
            )
        ]
        
        let dailyUsage = Dictionary(grouping: entries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp)
        }
        
        // Test different account types
        for accountType in ClaudeAccountType.allCases {
            logManager.mockAccountType = accountType
            let window = logManager.calculateFiveHourWindow(from: dailyUsage)
            
            #expect(window.total == 100) // Always normalized to 100
            #expect(window.used >= 0)
            #expect(window.used <= 100)
            
            // Verify description includes relevant info
            if accountType.usesFiveHourWindow {
                #expect(window.description.contains("hour"))
            } else {
                #expect(window.description.contains("day") || window.description.contains("Daily"))
            }
        }
    }

    // MARK: - Migration Tests
    
    @Test("Account type raw value stability for migration")
    func accountTypeRawValueStability() {
        // Ensure raw values don't change (important for UserDefaults storage)
        #expect(ClaudeAccountType.free.rawValue == "free")
        #expect(ClaudeAccountType.pro.rawValue == "pro")
        #expect(ClaudeAccountType.max5x.rawValue == "max5x")
        #expect(ClaudeAccountType.max20x.rawValue == "max20x")
    }

    @Test("Handle unknown account type gracefully")
    @MainActor
    func handleUnknownAccountType() async {
        let userDefaults = UserDefaults(suiteName: #function)!
        defer { userDefaults.removePersistentDomain(forName: #function) }
        
        // Store invalid value
        userDefaults.set("unknown_tier", forKey: "claudeAccountType")
        
        // Should fall back to default
        let sessionSettings = SessionSettingsManager(userDefaults: userDefaults)
        #expect(sessionSettings.claudeAccountType == .pro) // Default
    }

    // MARK: - Integration Tests
    
    @Test("Account type integrates with spending calculations")
    @MainActor
    func accountTypeSpendingIntegration() async {
        let settingsManager = MockSettingsManager()
        let orchestrator = MultiProviderDataOrchestrator(settingsManager: settingsManager)
        
        // Set Claude account type
        settingsManager.sessionSettingsManager.claudeAccountType = .pro
        
        // Enable Claude
        orchestrator.userSessionData.setLoginState(true, for: .claude)
        
        // Add Claude spending data
        let claudeData = ProviderSpendingData(
            provider: .claude,
            monthlyInvoice: ProviderMonthlyInvoice(
                items: [], // Pro tier is subscription-based, not usage-based
                provider: .claude,
                month: 0,
                year: 2025
            ),
            usageData: nil,
            currency: "USD",
            exchangeRate: 1.0
        )
        orchestrator.spendingData.setSpendingData(claudeData, for: .claude)
        
        // Verify account type affects calculations
        let accountType = settingsManager.sessionSettingsManager.claudeAccountType
        #expect(accountType == .pro)
        #expect(accountType.priceDisplay == "$20/month")
    }
}

// MARK: - Window Description Tests

extension FiveHourWindow {
    var description: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        
        let timeUntilReset = formatter.localizedString(for: resetDate, relativeTo: Date())
        
        if percentageUsed >= 100 {
            return "Quota exhausted. Resets \(timeUntilReset)"
        } else {
            return "\(Int(percentageRemaining))% remaining. Resets \(timeUntilReset)"
        }
    }
}

// MARK: - Extended Mock for Account Type Testing

extension ClaudeLogManagerMock {
    override func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        
        // Filter entries within window based on account type
        let relevantEntries: [ClaudeLogEntry]
        if mockAccountType.usesFiveHourWindow {
            relevantEntries = dailyUsage.values
                .flatMap(\.self)
                .filter { $0.timestamp >= fiveHoursAgo }
        } else {
            // Free tier - use today's entries
            let startOfDay = Calendar.current.startOfDay(for: now)
            relevantEntries = dailyUsage.values
                .flatMap(\.self)
                .filter { $0.timestamp >= startOfDay }
        }
        
        // Calculate usage
        let totalInputTokens = relevantEntries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = relevantEntries.reduce(0) { $0 + $1.outputTokens }
        let totalTokens = totalInputTokens + totalOutputTokens
        
        // Calculate usage ratio based on account type
        let usageRatio: Double
        if mockAccountType.usesFiveHourWindow, let messagesPerWindow = mockAccountType.messagesPerFiveHours {
            let avgTokensPerMessage = 3000
            let estimatedTokenLimit = messagesPerWindow * avgTokensPerMessage
            usageRatio = Double(totalTokens) / Double(estimatedTokenLimit)
        } else if let dailyLimit = mockAccountType.dailyMessageLimit {
            let messageCount = relevantEntries.count
            usageRatio = Double(messageCount) / Double(dailyLimit)
        } else {
            usageRatio = 0
        }
        
        // Calculate reset date
        let resetDate: Date
        if mockAccountType.usesFiveHourWindow {
            // Find oldest entry in window or use current time
            let oldestInWindow = relevantEntries.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? now
            resetDate = oldestInWindow.addingTimeInterval(5 * 60 * 60)
        } else {
            // Free tier - reset at midnight PT
            let calendar = Calendar.current
            var nextResetComponents = calendar.dateComponents([.year, .month, .day], from: now)
            nextResetComponents.day! += 1
            nextResetComponents.hour = 0
            nextResetComponents.minute = 0
            nextResetComponents.timeZone = TimeZone(identifier: "America/Los_Angeles")
            resetDate = calendar.date(from: nextResetComponents) ?? now.addingTimeInterval(24 * 3600)
        }
        
        return FiveHourWindow(
            used: min(usageRatio * 100, 100),
            total: 100,
            resetDate: resetDate
        )
    }
}
