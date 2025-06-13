import XCTest
@testable import VibeMeter

@MainActor
final class StatusBarDisplayManagerTests: XCTestCase {
    // MARK: - Properties
    
    private var sut: StatusBarDisplayManager!
    private var stateManager: MenuBarStateManager!
    private var settingsManager: MockSettingsManager!
    private var userSession: MultiProviderUserSessionData!
    private var spendingData: MultiProviderSpendingData!
    private var currencyData: CurrencyData!
    private var mockButton: NSStatusBarButton!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        stateManager = MenuBarStateManager()
        settingsManager = MockSettingsManager()
        userSession = MultiProviderUserSessionData()
        spendingData = MultiProviderSpendingData()
        currencyData = CurrencyData()
        mockButton = NSStatusBarButton()
        
        sut = StatusBarDisplayManager(
            stateManager: stateManager,
            settingsManager: settingsManager,
            userSession: userSession,
            spendingData: spendingData,
            currencyData: currencyData
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        stateManager = nil
        settingsManager = nil
        userSession = nil
        spendingData = nil
        currencyData = nil
        mockButton = nil
        try await super.tearDown()
    }
    
    // MARK: - Menu Bar Display Mode Tests
    
    func testIconOnlyModeShowsNoText() {
        // Given
        settingsManager.menuBarDisplayMode = .iconOnly
        userSession.providerSessionStates[.cursor] = .loggedIn
        spendingData.updateSpendingData(
            for: .cursor,
            data: ProviderSpendingData(
                currentMonthCost: 10.0,
                accountName: "Test User",
                usageData: nil
            )
        )
        stateManager.setState(.data(value: 0.5))
        
        // When
        sut.updateDisplay(for: mockButton)
        
        // Then
        XCTAssertEqual(mockButton.title, "", "Icon only mode should not display any text")
        XCTAssertNotNil(mockButton.image, "Icon only mode should display an icon")
    }
    
    func testMoneyOnlyModeShowsNoIcon() {
        // Given
        settingsManager.menuBarDisplayMode = .moneyOnly
        userSession.providerSessionStates[.cursor] = .loggedIn
        spendingData.updateSpendingData(
            for: .cursor,
            data: ProviderSpendingData(
                currentMonthCost: 10.0,
                accountName: "Test User",
                usageData: nil
            )
        )
        currencyData.updateSelectedCurrency(code: "USD", symbol: "$")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)
        
        // When
        sut.updateDisplay(for: mockButton)
        
        // Then
        XCTAssertNotEqual(mockButton.title, "", "Money only mode should display text")
        XCTAssertTrue(mockButton.title.contains("$"), "Money only mode should include currency symbol")
        XCTAssertNil(mockButton.image, "Money only mode should not display an icon")
    }
    
    func testBothModeShowsIconAndText() {
        // Given
        settingsManager.menuBarDisplayMode = .both
        userSession.providerSessionStates[.cursor] = .loggedIn
        spendingData.updateSpendingData(
            for: .cursor,
            data: ProviderSpendingData(
                currentMonthCost: 10.0,
                accountName: "Test User",
                usageData: nil
            )
        )
        currencyData.updateSelectedCurrency(code: "USD", symbol: "$")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)
        
        // When
        sut.updateDisplay(for: mockButton)
        
        // Then
        XCTAssertNotEqual(mockButton.title, "", "Both mode should display text")
        XCTAssertTrue(mockButton.title.contains("$"), "Both mode should include currency symbol")
        XCTAssertNotNil(mockButton.image, "Both mode should display an icon")
    }
    
    func testNoDataAlwaysShowsIcon() {
        // Given
        let modes: [MenuBarDisplayMode] = [.iconOnly, .moneyOnly, .both]
        
        for mode in modes {
            settingsManager.menuBarDisplayMode = mode
            userSession.providerSessionStates[.cursor] = .loggedIn
            // No spending data
            stateManager.setState(.loading)
            
            // When
            sut.updateDisplay(for: mockButton)
            
            // Then
            XCTAssertNotNil(mockButton.image, "Should always show icon when there's no data, even in \(mode) mode")
            XCTAssertEqual(mockButton.title, "", "Should not show text when there's no data in \(mode) mode")
        }
    }
    
    func testTextSpacingWithIcon() {
        // Given
        settingsManager.menuBarDisplayMode = .both
        userSession.providerSessionStates[.cursor] = .loggedIn
        spendingData.updateSpendingData(
            for: .cursor,
            data: ProviderSpendingData(
                currentMonthCost: 10.0,
                accountName: "Test User",
                usageData: nil
            )
        )
        currencyData.updateSelectedCurrency(code: "USD", symbol: "$")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)
        
        // When
        sut.updateDisplay(for: mockButton)
        
        // Then
        XCTAssertTrue(mockButton.title.hasPrefix("  "), "Text should have spacing when icon is shown")
    }
    
    func testTextNoSpacingWithoutIcon() {
        // Given
        settingsManager.menuBarDisplayMode = .moneyOnly
        userSession.providerSessionStates[.cursor] = .loggedIn
        spendingData.updateSpendingData(
            for: .cursor,
            data: ProviderSpendingData(
                currentMonthCost: 10.0,
                accountName: "Test User",
                usageData: nil
            )
        )
        currencyData.updateSelectedCurrency(code: "USD", symbol: "$")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)
        
        // When
        sut.updateDisplay(for: mockButton)
        
        // Then
        XCTAssertFalse(mockButton.title.hasPrefix("  "), "Text should not have spacing when icon is not shown")
        XCTAssertTrue(mockButton.title.hasPrefix("$"), "Text should start with currency symbol")
    }
}