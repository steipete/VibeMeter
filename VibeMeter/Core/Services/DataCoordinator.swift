import Combine
import Foundation
import os.log

// MARK: - DataCoordinator Protocol

@MainActor
public protocol DataCoordinatorProtocol: AnyObject, Sendable {
    // State
    var isLoggedIn: Bool { get }
    var userEmail: String? { get }
    var teamName: String? { get }
    var currentSpendingUSD: Double? { get }
    var currentSpendingConverted: Double? { get }
    var warningLimitConverted: Double? { get }
    var upperLimitConverted: Double? { get }
    var selectedCurrencyCode: String { get }
    var selectedCurrencySymbol: String { get }
    var exchangeRatesAvailable: Bool { get }
    var menuBarDisplayText: String { get }
    var lastErrorMessage: String? { get }
    var teamIdFetchFailed: Bool { get }
    var currentExchangeRates: [String: Double] { get }
    var settingsManager: any SettingsManagerProtocol { get }

    // Actions
    func forceRefreshData(showSyncedMessage: Bool) async
    func initiateLoginFlow()
    func userDidRequestLogout()
    func cleanup()
}

// MARK: - Modern DataCoordinator Implementation

@MainActor
public final class DataCoordinator: DataCoordinatorProtocol, ObservableObject {
    // MARK: - Published State

    @Published public private(set) var isLoggedIn = false
    @Published public private(set) var userEmail: String?
    @Published public private(set) var teamName: String?
    @Published public private(set) var currentSpendingUSD: Double?
    @Published public private(set) var currentSpendingConverted: Double?
    @Published public private(set) var warningLimitConverted: Double?
    @Published public private(set) var upperLimitConverted: Double?
    @Published public private(set) var selectedCurrencyCode = "USD"
    @Published public private(set) var selectedCurrencySymbol = "$"
    @Published public private(set) var exchangeRatesAvailable = true
    @Published public private(set) var menuBarDisplayText = "Loading..."
    @Published public private(set) var lastErrorMessage: String?
    @Published public private(set) var teamIdFetchFailed = false
    @Published public private(set) var currentExchangeRates: [String: Double] = [:]
    @Published public private(set) var latestInvoiceResponse: MonthlyInvoice?

    // MARK: - Dependencies

    public let settingsManager: any SettingsManagerProtocol
    private let loginManager: LoginManager
    private let apiClient: CursorAPIClientProtocol
    private let exchangeRateManager: ExchangeRateManagerProtocol
    private let notificationManager: NotificationManagerProtocol

    // MARK: - Private State

    private let logger = Logger(subsystem: "com.vibemeter", category: "DataCoordinator")
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Singleton

    private static let _shared: DataCoordinatorProtocol = // Create the singleton on MainActor
        // This is safe because DataCoordinator is @MainActor
        MainActor.assumeIsolated {
            let settingsManager = SettingsManager.shared
            let apiClient = CursorAPIClient(settingsManager: settingsManager)
            let loginManager = LoginManager(settingsManager: settingsManager, apiClient: apiClient)
            return DataCoordinator(
                loginManager: loginManager,
                settingsManager: settingsManager,
                exchangeRateManager: ExchangeRateManager.shared,
                apiClient: apiClient,
                notificationManager: NotificationManager()
            )
        }

    public static var shared: DataCoordinatorProtocol {
        _shared
    }

    // MARK: - Initialization

    // Made internal for testing
    init(
        loginManager: LoginManager,
        settingsManager: any SettingsManagerProtocol,
        exchangeRateManager: ExchangeRateManagerProtocol,
        apiClient: CursorAPIClientProtocol,
        notificationManager: NotificationManagerProtocol
    ) {
        self.loginManager = loginManager
        self.settingsManager = settingsManager
        self.exchangeRateManager = exchangeRateManager
        self.apiClient = apiClient
        self.notificationManager = notificationManager

        isLoggedIn = loginManager.isLoggedIn()
        selectedCurrencyCode = settingsManager.selectedCurrencyCode
        selectedCurrencySymbol = ExchangeRateManager.getSymbol(for: selectedCurrencyCode)

        setupBindings()

        if isLoggedIn {
            Task {
                await forceRefreshData(showSyncedMessage: false)
            }
        } else {
            updateMenuBarDisplay()
        }

        setupRefreshTimer()

        Task {
            _ = await notificationManager.requestAuthorization()
            await notificationManager.resetAllNotificationStatesForNewSession()
        }

        logger.info("DataCoordinator initialized")
    }

    // MARK: - Setup

    private func setupBindings() {
        // Login manager callbacks
        loginManager.onLoginSuccess = { [weak self] in
            Task { @MainActor in
                await self?.handleLoginStatusChange(loggedIn: true, showSyncedMessage: true)
            }
        }

        loginManager.onLoginFailure = { [weak self] error in
            guard let self else { return }
            logger.warning("Login failed: \(error.localizedDescription)")

            if error.localizedDescription.contains("logged out") {
                self.lastErrorMessage = nil
            } else {
                self.lastErrorMessage = "Login failed or cancelled."
            }

            Task { @MainActor in
                await self.handleLoginStatusChange(loggedIn: false, showSyncedMessage: false)
            }
        }

        loginManager.onLoginDismiss = { [weak self] in
            guard let self else { return }
            if !self.loginManager.isLoggedIn(), self.lastErrorMessage == nil {
                logger.info("Login dismissed")
                self.updateMenuBarDisplay()
            }
        }

        // Settings manager changes
        if let concreteSettingsManager = settingsManager as? SettingsManager {
            concreteSettingsManager.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }

                    let newCode = self.settingsManager.selectedCurrencyCode
                    if self.selectedCurrencyCode != newCode {
                        self.selectedCurrencyCode = newCode
                        self.selectedCurrencySymbol = ExchangeRateManager.getSymbol(for: newCode)
                    }

                    Task {
                        await self.convertAndDisplayAmounts()
                    }
                    self.setupRefreshTimer()
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Public Methods

    public func forceRefreshData(showSyncedMessage: Bool = true) async {
        guard let authToken = loginManager.getAuthToken() else {
            logger.info("Not logged in, cannot refresh data")
            isLoggedIn = false
            lastErrorMessage = nil
            teamIdFetchFailed = false
            updateMenuBarDisplay()
            return
        }

        isLoggedIn = true
        menuBarDisplayText = "Loading..."

        if !showSyncedMessage {
            lastErrorMessage = nil
        }
        teamIdFetchFailed = false

        do {
            // Fetch data concurrently where possible
            async let userTask: Void = fetchUserAndTeamInfo(authToken: authToken)
            async let exchangeTask: Void = refreshExchangeRates()

            try await userTask
            await exchangeTask

            // Fetch invoice after we have team info
            try await fetchCurrentMonthInvoice(authToken: authToken)

            await convertAndDisplayAmounts()

            if showSyncedMessage {
                menuBarDisplayText = "Vibe synced! ✨"
                Task {
                    try? await Task.sleep(for: .seconds(2.5))
                    self.updateMenuBarDisplay()
                }
            } else {
                updateMenuBarDisplay()
            }

            await checkLimitsAndNotify()

        } catch let error as CursorAPIError where error == .unauthorized {
            logger.warning("Unauthorized, clearing session")
            lastErrorMessage = "Session expired. Please log in."
            loginManager.logOut()
        } catch let error as CursorAPIError where error == .noTeamFound {
            logger.error("Team not found")
            teamIdFetchFailed = true
            currentSpendingUSD = nil
            currentSpendingConverted = nil
            lastErrorMessage = "Hmm, can't find your team vibe right now. 😕 Try a refresh?"
            updateMenuBarDisplay()
        } catch {
            logger.error("Failed to refresh data: \(error)")
            lastErrorMessage = "Error fetching data: \(String(describing: error))".truncate(length: 50)
            currentSpendingUSD = nil
            updateMenuBarDisplay()
        }
    }

    public func initiateLoginFlow() {
        loginManager.showLoginWindow()
    }

    public func userDidRequestLogout() {
        logger.info("User requested logout")
        loginManager.logOut()
    }

    public func cleanup() {
        refreshTask?.cancel()
        refreshTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
        logger.info("DataCoordinator cleanup completed")
    }

    // MARK: - Private Methods

    private func handleLoginStatusChange(loggedIn: Bool, showSyncedMessage: Bool) async {
        isLoggedIn = loggedIn
        await notificationManager.resetAllNotificationStatesForNewSession()

        if loggedIn {
            await forceRefreshData(showSyncedMessage: showSyncedMessage)
        } else {
            clearUserData()
            updateMenuBarDisplay()
        }
        setupRefreshTimer()
    }

    private func clearUserData() {
        userEmail = nil
        currentSpendingUSD = nil
        currentSpendingConverted = nil
        warningLimitConverted = nil
        upperLimitConverted = nil
        teamName = nil
        teamIdFetchFailed = false
        lastErrorMessage = nil
        latestInvoiceResponse = nil
        settingsManager.clearUserSessionData()
    }

    private func setupRefreshTimer() {
        refreshTimer?.invalidate()
        guard isLoggedIn else {
            refreshTimer = nil
            return
        }

        let interval = TimeInterval(settingsManager.refreshIntervalMinutes * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.logger.info("Timer fired, refreshing data")
            Task { @MainActor in
                await self.forceRefreshData(showSyncedMessage: false)
            }
        }
    }

    private func updateMenuBarDisplay() {
        if !isLoggedIn {
            menuBarDisplayText = "Login Required"
        } else if teamIdFetchFailed {
            menuBarDisplayText = "Team Error"
        } else if let spending = currentSpendingConverted {
            menuBarDisplayText = "\(selectedCurrencySymbol)\(String(format: "%.2f", spending))"
        } else if let spendingUSD = currentSpendingUSD {
            menuBarDisplayText = "$\(String(format: "%.2f", spendingUSD))"
        } else {
            menuBarDisplayText = "Loading..."
        }
    }
}

// MARK: - Data Fetching Extension

extension DataCoordinator {
    private func fetchUserAndTeamInfo(authToken: String) async throws {
        let userInfo = try await apiClient.fetchUserInfo(authToken: authToken)
        settingsManager.userEmail = userInfo.email
        userEmail = userInfo.email
        logger.info("Fetched user: \(userInfo.email)")

        let teamId: Int
        if let teamIdFromUser = userInfo.teamId {
            teamId = teamIdFromUser
            logger.info("Team ID from user info: \(teamId)")

            let teamDetails = try await apiClient.fetchTeamInfo(authToken: authToken)
            settingsManager.teamName = teamDetails.name
            teamName = teamDetails.name
            logger.info("Team name: \(teamDetails.name)")
        } else {
            let teamDetails = try await apiClient.fetchTeamInfo(authToken: authToken)
            teamId = teamDetails.id
            settingsManager.teamName = teamDetails.name
            teamName = teamDetails.name
            logger.info("Team info from teams endpoint: \(teamDetails.name)")
        }

        settingsManager.teamId = teamId
    }

    private func fetchCurrentMonthInvoice(authToken: String) async throws {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date()) - 1 // 0-based for API
        let year = calendar.component(.year, from: Date())

        logger.info("Fetching invoice for \(month)/\(year)")

        let invoiceResponse = try await apiClient.fetchMonthlyInvoice(
            authToken: authToken,
            month: month,
            year: year
        )

        currentSpendingUSD = Double(invoiceResponse.totalSpendingCents) / 100.0
        latestInvoiceResponse = invoiceResponse

        logger.info("Fetched invoice: \(invoiceResponse.items.count) items, total $\(currentSpendingUSD ?? 0)")
    }

    private func refreshExchangeRates() async {
        await convertAndDisplayAmounts()
    }
}

// MARK: - Currency Handling Extension

extension DataCoordinator {
    private func convertAndDisplayAmounts() async {
        let targetCurrency = settingsManager.selectedCurrencyCode

        if targetCurrency == "USD" {
            exchangeRatesAvailable = true
            currentExchangeRates = [:]
            convertAmountsWithRates([:])
            return
        }

        let rates = await exchangeRateManager.getExchangeRates()
        currentExchangeRates = rates
        exchangeRatesAvailable = !rates.isEmpty

        if !exchangeRatesAvailable {
            logger.warning("Exchange rates unavailable")
            currentExchangeRates = exchangeRateManager.fallbackRates
        }

        convertAmountsWithRates(currentExchangeRates)
    }

    private func convertAmountsWithRates(_ rates: [String: Double]) {
        let targetCurrency = settingsManager.selectedCurrencyCode

        // Current spending
        if let spendingUSD = currentSpendingUSD {
            currentSpendingConverted = exchangeRateManager.convert(
                spendingUSD,
                from: "USD",
                to: targetCurrency,
                rates: rates
            ) ?? spendingUSD
        }

        // Warning limit
        let warningUSD = settingsManager.warningLimitUSD
        warningLimitConverted = exchangeRateManager.convert(
            warningUSD,
            from: "USD",
            to: targetCurrency,
            rates: rates
        ) ?? warningUSD

        // Upper limit
        let upperUSD = settingsManager.upperLimitUSD
        upperLimitConverted = exchangeRateManager.convert(
            upperUSD,
            from: "USD",
            to: targetCurrency,
            rates: rates
        ) ?? upperUSD

        updateMenuBarDisplay()
    }

    private func checkLimitsAndNotify() async {
        guard let spendingUSD = currentSpendingUSD else { return }

        let warningLimitUSD = settingsManager.warningLimitUSD
        let upperLimitUSD = settingsManager.upperLimitUSD
        let displayCurrency = exchangeRatesAvailable ? selectedCurrencyCode : "USD"

        await notificationManager.resetNotificationStateIfBelow(
            limitType: .warning,
            currentSpendingUSD: spendingUSD,
            warningLimitUSD: warningLimitUSD,
            upperLimitUSD: upperLimitUSD
        )

        await notificationManager.resetNotificationStateIfBelow(
            limitType: .upper,
            currentSpendingUSD: spendingUSD,
            warningLimitUSD: warningLimitUSD,
            upperLimitUSD: upperLimitUSD
        )

        if spendingUSD >= warningLimitUSD {
            let displaySpending = exchangeRateManager.convert(
                spendingUSD,
                from: "USD",
                to: displayCurrency,
                rates: exchangeRatesAvailable ? currentExchangeRates : exchangeRateManager.fallbackRates
            ) ?? spendingUSD

            let displayWarningLimit = exchangeRateManager.convert(
                warningLimitUSD,
                from: "USD",
                to: displayCurrency,
                rates: exchangeRatesAvailable ? currentExchangeRates : exchangeRateManager.fallbackRates
            ) ?? warningLimitUSD

            await notificationManager.showWarningNotification(
                currentSpending: displaySpending,
                limitAmount: displayWarningLimit,
                currencyCode: displayCurrency
            )
        }

        if spendingUSD >= upperLimitUSD {
            let displaySpending = exchangeRateManager.convert(
                spendingUSD,
                from: "USD",
                to: displayCurrency,
                rates: exchangeRatesAvailable ? currentExchangeRates : exchangeRateManager.fallbackRates
            ) ?? spendingUSD

            let displayUpperLimit = exchangeRateManager.convert(
                upperLimitUSD,
                from: "USD",
                to: displayCurrency,
                rates: exchangeRatesAvailable ? currentExchangeRates : exchangeRateManager.fallbackRates
            ) ?? upperLimitUSD

            await notificationManager.showUpperLimitNotification(
                currentSpending: displaySpending,
                limitAmount: displayUpperLimit,
                currencyCode: displayCurrency
            )
        }
    }
}

// MARK: - String Extension

private extension String {
    func truncate(length: Int) -> String {
        if count > length {
            return String(prefix(length - 3)) + "..."
        }
        return self
    }
}
