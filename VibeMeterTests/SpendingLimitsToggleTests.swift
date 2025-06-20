import Foundation
import Testing
@testable import VibeMeter

@Suite("Spending Limits Toggle Tests", .tags(.settings, .unit, .fast))
@MainActor
struct SpendingLimitsToggleTests {
    let limitsManager: SpendingLimitsManager
    let testUserDefaults: UserDefaults

    init() {
        // Unique suite name for UserDefaults to avoid interference between tests
        let testSuiteName = "com.vibemeter.tests.SpendingLimitsToggleTests"
        let suite = UserDefaults(suiteName: testSuiteName)!
        suite.removePersistentDomain(forName: testSuiteName)
        
        self.testUserDefaults = suite
        self.limitsManager = SpendingLimitsManager(userDefaults: testUserDefaults)
    }

    @Test("Limits enabled by default")
    func limitsEnabledByDefault() {
        #expect(limitsManager.limitsEnabled == true)
    }

    @Test("Can disable limits")
    func canDisableLimits() {
        limitsManager.limitsEnabled = false
        #expect(limitsManager.limitsEnabled == false)
        
        // Verify persistence
        let newManager = SpendingLimitsManager(userDefaults: testUserDefaults)
        #expect(newManager.limitsEnabled == false)
    }

    @Test("Can re-enable limits")
    func canReEnableLimits() {
        limitsManager.limitsEnabled = false
        limitsManager.limitsEnabled = true
        
        #expect(limitsManager.limitsEnabled == true)
        
        // Verify persistence
        let newManager = SpendingLimitsManager(userDefaults: testUserDefaults)
        #expect(newManager.limitsEnabled == true)
    }

    @Test("Reset to defaults enables limits")
    func resetToDefaultsEnablesLimits() {
        limitsManager.limitsEnabled = false
        limitsManager.resetToDefaults()
        
        #expect(limitsManager.limitsEnabled == true)
        #expect(limitsManager.warningLimitUSD == 200.0)
        #expect(limitsManager.upperLimitUSD == 1000.0)
    }
} 