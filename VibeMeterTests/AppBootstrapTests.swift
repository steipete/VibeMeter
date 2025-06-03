import XCTest
@testable import VibeMeter

/// Minimal test to verify app can start up without crashing.
/// This helps isolate bootstrap issues from complex test logic.
@MainActor
final class AppBootstrapTests: XCTestCase, @unchecked Sendable {
    
    func testCanCreateBasicServices() {
        // Test that we can create basic services without crashing
        let settingsManager = SettingsManager(userDefaults: UserDefaults(), startupManager: StartupManagerMock())
        XCTAssertNotNil(settingsManager)
        
        let providerFactory = ProviderFactory(settingsManager: settingsManager)
        XCTAssertNotNil(providerFactory)
        
        let loginManager = MultiProviderLoginManager(providerFactory: providerFactory)
        XCTAssertNotNil(loginManager)
    }
    
    func testCanCreateObservableModels() {
        // Test that we can create the observable models
        let spendingData = MultiProviderSpendingData()
        XCTAssertNotNil(spendingData)
        
        let userSession = MultiProviderUserSessionData()
        XCTAssertNotNil(userSession)
        
        let currencyData = CurrencyData()
        XCTAssertNotNil(currencyData)
    }
}