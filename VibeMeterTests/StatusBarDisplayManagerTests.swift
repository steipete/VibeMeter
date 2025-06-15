@testable import VibeMeter
import XCTest

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

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    override func tearDownWithError() throws {
        // Properties will be cleaned up when tests complete
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    @MainActor
    private func setupTest() {
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
            currencyData: currencyData)
    }

    // MARK: - Menu Bar Display Mode Tests

    @MainActor
    func testIconOnlyModeShowsNoText() throws {
        // Setup
        setupTest()

        // Given
        settingsManager.menuBarDisplayMode = .iconOnly
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test User")
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        let year = calendar.component(.year, from: currentDate)

        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 1000, description: "Test usage", provider: .cursor)],
                provider: .cursor,
                month: month,
                year: year),
            rates: [:],
            targetCurrency: "USD")
        stateManager.setState(.data(value: 0.5))

        // When
        sut.updateDisplay(for: mockButton)

        // Then
        XCTAssertEqual(mockButton.title, "", "Icon only mode should not display any text")
        XCTAssertNotNil(mockButton.image, "Icon only mode should display an icon")
    }

    @MainActor
    func testMoneyOnlyModeShowsNoIcon() throws {
        // Setup
        setupTest()

        // Given
        settingsManager.menuBarDisplayMode = .moneyOnly
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test User")
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        let year = calendar.component(.year, from: currentDate)

        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 1000, description: "Test usage", provider: .cursor)],
                provider: .cursor,
                month: month,
                year: year),
            rates: [:],
            targetCurrency: "USD")
        currencyData.updateSelectedCurrency("USD")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)

        // When
        sut.updateDisplay(for: mockButton)

        // Then
        XCTAssertNotEqual(mockButton.title, "", "Money only mode should display text")
        XCTAssertTrue(mockButton.title.contains("$"), "Money only mode should include currency symbol")
        XCTAssertNil(mockButton.image, "Money only mode should not display an icon")
    }

    @MainActor
    func testBothModeShowsIconAndText() throws {
        // Setup
        setupTest()

        // Given
        settingsManager.menuBarDisplayMode = .both
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test User")
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        let year = calendar.component(.year, from: currentDate)

        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 1000, description: "Test usage", provider: .cursor)],
                provider: .cursor,
                month: month,
                year: year),
            rates: [:],
            targetCurrency: "USD")
        currencyData.updateSelectedCurrency("USD")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)

        // When
        sut.updateDisplay(for: mockButton)

        // Then
        XCTAssertNotEqual(mockButton.title, "", "Both mode should display text")
        XCTAssertTrue(mockButton.title.contains("$"), "Both mode should include currency symbol")
        XCTAssertNotNil(mockButton.image, "Both mode should display an icon")
    }

    @MainActor
    func testNoDataAlwaysShowsIcon() throws {
        // Setup
        setupTest()

        // Given
        let modes: [MenuBarDisplayMode] = [.iconOnly, .moneyOnly, .both]

        for mode in modes {
            settingsManager.menuBarDisplayMode = mode
            userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test User")
            // No spending data
            stateManager.setState(.loading)

            // When
            sut.updateDisplay(for: mockButton)

            // Then
            XCTAssertNotNil(mockButton.image, "Should always show icon when there's no data, even in \(mode) mode")
            XCTAssertEqual(mockButton.title, "", "Should not show text when there's no data in \(mode) mode")
        }
    }

    @MainActor
    func testTextSpacingWithIcon() throws {
        // Setup
        setupTest()

        // Given
        settingsManager.menuBarDisplayMode = .both
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test User")
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        let year = calendar.component(.year, from: currentDate)

        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 1000, description: "Test usage", provider: .cursor)],
                provider: .cursor,
                month: month,
                year: year),
            rates: [:],
            targetCurrency: "USD")
        currencyData.updateSelectedCurrency("USD")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)

        // When
        sut.updateDisplay(for: mockButton)

        // Then
        XCTAssertTrue(mockButton.title.hasPrefix("  "), "Text should have spacing when icon is shown")
    }

    @MainActor
    func testTextNoSpacingWithoutIcon() throws {
        // Setup
        setupTest()

        // Given
        settingsManager.menuBarDisplayMode = .moneyOnly
        userSession.handleLoginSuccess(for: .cursor, email: "test@example.com", teamName: "Test User")
        let currentDate = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: currentDate)
        let year = calendar.component(.year, from: currentDate)

        spendingData.updateSpending(
            for: .cursor,
            from: ProviderMonthlyInvoice(
                items: [ProviderInvoiceItem(cents: 1000, description: "Test usage", provider: .cursor)],
                provider: .cursor,
                month: month,
                year: year),
            rates: [:],
            targetCurrency: "USD")
        currencyData.updateSelectedCurrency("USD")
        stateManager.setState(.data(value: 0.5))
        stateManager.setCostValueImmediately(10.0)

        // When
        sut.updateDisplay(for: mockButton)

        // Then
        XCTAssertFalse(mockButton.title.hasPrefix("  "), "Text should not have spacing when icon is not shown")
        XCTAssertTrue(mockButton.title.hasPrefix("$"), "Text should start with currency symbol")
    }
}
