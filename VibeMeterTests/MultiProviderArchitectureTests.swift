@testable import VibeMeter
import XCTest

/// Tests for the new multi-provider architecture to ensure basic functionality works
@MainActor
final class MultiProviderArchitectureTests: XCTestCase {
    func testServiceProviderCases() {
        // Test that ServiceProvider enum has expected cases
        let allCases = ServiceProvider.allCases
        XCTAssertTrue(allCases.contains(.cursor), "Should contain cursor provider")
        XCTAssertFalse(allCases.isEmpty, "Should have at least one provider")
    }

    func testServiceProviderProperties() {
        let cursor = ServiceProvider.cursor

        // Test basic properties
        XCTAssertEqual(cursor.displayName, "Cursor", "Display name should be Cursor")
        XCTAssertEqual(cursor.defaultCurrency, "USD", "Default currency should be USD")
        XCTAssertTrue(cursor.supportsTeams, "Cursor should support teams")
        XCTAssertEqual(cursor.keychainService, "com.steipete.vibemeter.cursor", "Keychain service should be correct")

        // Test URLs
        XCTAssertNotNil(cursor.authenticationURL, "Should have authentication URL")
        XCTAssertNotNil(cursor.websiteURL, "Should have website URL")

        // Test cookie properties
        XCTAssertEqual(cursor.authCookieName, "WorkosCursorSessionToken", "Cookie name should be correct")
        XCTAssertEqual(cursor.cookieDomain, ".cursor.com", "Cookie domain should be correct")
    }

    func testMultiProviderUserSessionData() {
        let userSession = MultiProviderUserSessionData()

        // Test initial state
        XCTAssertFalse(userSession.isLoggedInToAnyProvider, "Should not be logged into any provider initially")
        XCTAssertTrue(userSession.loggedInProviders.isEmpty, "Should have no logged in providers initially")
        XCTAssertNil(userSession.mostRecentSession, "Should have no recent session initially")

        // Test login success
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test Team", teamId: 123)

        XCTAssertTrue(userSession.isLoggedInToAnyProvider, "Should be logged into a provider after login")
        XCTAssertTrue(userSession.isLoggedIn(to: .cursor), "Should be logged into cursor")
        XCTAssertEqual(userSession.loggedInProviders, [.cursor], "Should have cursor in logged in providers")

        let session = userSession.getSession(for: .cursor)
        XCTAssertNotNil(session, "Should have a session for cursor")
        XCTAssertEqual(session?.userEmail, "test@example.com", "Email should be correct")
        XCTAssertEqual(session?.teamName, "Test Team", "Team name should be correct")
        XCTAssertEqual(session?.teamId, 123, "Team ID should be correct")
        XCTAssertTrue(session?.isLoggedIn ?? false, "Session should be logged in")

        // Test logout
        userSession.handleLogout(from: .cursor)

        XCTAssertFalse(userSession.isLoggedInToAnyProvider, "Should not be logged into any provider after logout")
        XCTAssertFalse(userSession.isLoggedIn(to: .cursor), "Should not be logged into cursor after logout")
        XCTAssertTrue(userSession.loggedInProviders.isEmpty, "Should have no logged in providers after logout")
    }

    func testMultiProviderSpendingData() {
        let spendingData = MultiProviderSpendingData()

        // Test initial state
        XCTAssertTrue(spendingData.providersWithData.isEmpty, "Should have no providers with data initially")
        XCTAssertEqual(spendingData.totalSpendingUSD, 0.0, "Total spending should be 0 initially")
        XCTAssertNil(spendingData.getSpendingData(for: .cursor), "Should have no spending data for cursor initially")

        // Test updating limits
        spendingData.updateLimits(
            for: .cursor,
            warningUSD: 50.0,
            upperUSD: 100.0,
            rates: ["USD": 1.0],
            targetCurrency: "USD")

        XCTAssertTrue(spendingData.providersWithData.contains(.cursor), "Should have cursor in providers with data")

        let cursorData = spendingData.getSpendingData(for: .cursor)
        XCTAssertNotNil(cursorData, "Should have spending data for cursor")
        XCTAssertEqual(cursorData?.displayWarningLimit, 50.0, "Warning limit should be correct")
        XCTAssertEqual(cursorData?.displayUpperLimit, 100.0, "Upper limit should be correct")

        // Test clearing data
        spendingData.clear(provider: .cursor)
        XCTAssertFalse(
            spendingData.providersWithData.contains(.cursor),
            "Should not have cursor in providers with data after clearing")
    }

    func testCurrencyData() {
        let currencyData = CurrencyData()

        // Test initial state
        XCTAssertEqual(currencyData.selectedCode, "USD", "Should default to USD")
        XCTAssertEqual(currencyData.selectedSymbol, "$", "Should default to $ symbol")
        XCTAssertTrue(currencyData.exchangeRatesAvailable, "Exchange rates should be available initially")
        XCTAssertTrue(currencyData.isUSD, "Should be USD initially")

        // Test updating currency
        currencyData.updateSelectedCurrency("EUR")
        XCTAssertEqual(currencyData.selectedCode, "EUR", "Should update to EUR")
        XCTAssertFalse(currencyData.isUSD, "Should not be USD after changing to EUR")

        // Test updating exchange rates
        let testRates = ["EUR": 1.0, "USD": 1.1]
        currencyData.updateExchangeRates(testRates)
        XCTAssertEqual(currencyData.currentExchangeRates, testRates, "Exchange rates should be updated")

        // Test setting unavailable
        currencyData.setExchangeRatesUnavailable()
        XCTAssertFalse(currencyData.exchangeRatesAvailable, "Exchange rates should be unavailable")

        // Test reset
        currencyData.reset()
        XCTAssertEqual(currencyData.selectedCode, "USD", "Should reset to USD")
        XCTAssertTrue(currencyData.exchangeRatesAvailable, "Exchange rates should be available after reset")
    }

    func testSettingsManager() {
        // Test that SettingsManager can be created and has reasonable defaults
        let settings = SettingsManager.shared

        XCTAssertGreaterThan(settings.warningLimitUSD, 0, "Warning limit should be positive")
        XCTAssertGreaterThan(settings.upperLimitUSD, 0, "Upper limit should be positive")
        XCTAssertGreaterThan(
            settings.upperLimitUSD,
            settings.warningLimitUSD,
            "Upper limit should be greater than warning limit")
        XCTAssertNotNil(settings.selectedCurrencyCode, "Should have a selected currency code")
        XCTAssertGreaterThan(settings.refreshIntervalMinutes, 0, "Refresh interval should be positive")
    }

    func testKeychain() {
        // Test that KeychainHelper can be created without crashing
        let keychain = KeychainHelper(service: "test.service")

        // Test basic operations (should not crash)
        let initialToken = keychain.getToken()
        XCTAssertNil(initialToken, "Should have no token initially")

        // Note: We don't test actual save/delete operations as they would affect the real keychain
        // Those would be tested in integration tests with a mock keychain service
    }
}
