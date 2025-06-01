import Combine
import Foundation

@MainActor
class RealDataCoordinator: DataCoordinatorProtocol {
    // Managers - now using protocols where applicable, or concrete if testability is handled within them
    private let loginManager: LoginManager // Using concrete LoginManager for now
    private let apiClient: CursorAPIClientProtocol
    let settingsManager: SettingsManagerProtocol
    private let exchangeRateManager: ExchangeRateManagerProtocol
    private let notificationManager: NotificationManagerProtocol
    // weak var menuBarController: MenuBarController? // Retain if direct calls are needed beyond observation

    @Published var isLoggedIn: Bool = false
    @Published var userEmail: String?
    @Published var currentSpendingUSD: Double? // Internal state, not in protocol directly
    @Published var currentSpendingConverted: Double?
    @Published var warningLimitConverted: Double?
    @Published var upperLimitConverted: Double?
    @Published var teamName: String?
    @Published var selectedCurrencyCode: String = "USD"
    @Published var selectedCurrencySymbol: String = "$"
    @Published var exchangeRatesAvailable: Bool = true
    @Published var menuBarDisplayText: String = "Loading..."
    @Published var lastErrorMessage: String?
    @Published var teamIdFetchFailed: Bool = false
    @Published var currentExchangeRates: [String: Double] = [:]
    
    // Store the latest invoice response for debug display
    @Published var latestInvoiceResponse: CursorAPIClient.MonthlyInvoiceResponse?

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(
        loginManager: LoginManager, // Keep concrete for now, or use LoginManagerProtocol if created
        settingsManager: SettingsManagerProtocol,
        exchangeRateManager: ExchangeRateManagerProtocol,
        apiClient: CursorAPIClientProtocol,
        notificationManager: NotificationManagerProtocol
        // menuBarController: MenuBarController? = nil // Optional injection if needed
    ) {
        self.loginManager = loginManager
        self.settingsManager = settingsManager
        self.exchangeRateManager = exchangeRateManager
        self.apiClient = apiClient
        self.notificationManager = notificationManager
        // self.menuBarController = menuBarController

        isLoggedIn = self.loginManager.isLoggedIn()
        selectedCurrencyCode = self.settingsManager.selectedCurrencyCode
        selectedCurrencySymbol = RealExchangeRateManager
            .getSymbol(for: selectedCurrencyCode) // Use static method from protocol

        setupBindings()

        if isLoggedIn {
            Task {
                await forceRefreshData(showSyncedMessage: false)
            }
        } else {
            updateMenuBarDisplay()
        }
        setupRefreshTimer()
        
        // Request notification authorization on MainActor
        Task { @MainActor in
            self.notificationManager.requestAuthorization { _ in }
            self.notificationManager.resetAllNotificationStatesForNewSession()
        }
        
        LoggingService.info("RealDataCoordinator initialized.", category: .data)
    }

    private func setupBindings() {
        // LoginManager callbacks - assuming LoginManager exposes these directly or via a protocol method
        loginManager.onLoginSuccess = { [weak self] in // Assuming onLoginSuccess exists
            Task { await self?.handleLoginStatusChange(loggedIn: true, showSyncedMessage: true) }
        }
        loginManager.onLoginFailure = { [weak self] error in
            LoggingService.warning(
                "Login failed or was cancelled. Error: \(error.localizedDescription)",
                category: .data
            )
            self?.lastErrorMessage = "Login failed or cancelled."
            Task { await self?.handleLoginStatusChange(loggedIn: false, showSyncedMessage: false) }
        }
        loginManager.onLoginDismiss = { [weak self] in // If login window closed without explicit success/failure
            // Only update UI if not already handling a success/failure which would also close window
            if self?.loginManager.isLoggedIn() == false && self?.lastErrorMessage == nil {
                LoggingService.info("Login dismissed.", category: .data)
                self?.updateMenuBarDisplay() // Reflect current state
            }
        }

        // Since we're using concrete SettingsManager type (which is ObservableObject),
        // we can observe its changes
        if let concreteSettingsManager = settingsManager as? SettingsManager {
            concreteSettingsManager.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    // Check specific properties if needed, or re-evaluate relevant state
                    let newCode = settingsManager.selectedCurrencyCode
                    if selectedCurrencyCode != newCode {
                        selectedCurrencyCode = newCode
                        selectedCurrencySymbol = RealExchangeRateManager.getSymbol(for: newCode)
                    }
                    // For limits and refresh interval, changes will trigger re-calculation or timer setup
                    Task { await self.convertAndDisplayAmounts() }
                    setupRefreshTimer() // Refresh interval might have changed
                }
                .store(in: &cancellables)
        }
    }

    private func handleLoginStatusChange(loggedIn: Bool, showSyncedMessage: Bool) async {
        isLoggedIn = loggedIn
        // Token for apiClient is handled by its own shared instance, or if RealCursorAPIClient needs explicit update,
        // how?
        // The RealCursorAPIClient currently doesn't have an explicit token update method, it relies on SettingsManager
        // for teamID
        // and expects token to be passed into its methods. This interaction needs clarification for DataCoordinator.
        // For now, assume LoginManager gives token to API methods called in forceRefreshData.

        notificationManager.resetAllNotificationStatesForNewSession()

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
        settingsManager.clearUserSessionData()
    }

    func forceRefreshData(showSyncedMessage: Bool = true) async {
        guard let authToken = loginManager.getAuthToken() else { // Get token for API calls
            LoggingService.info("Not logged in (no auth token), cannot refresh data.", category: .data)
            isLoggedIn = false // Ensure state consistency
            lastErrorMessage = nil
            teamIdFetchFailed = false
            updateMenuBarDisplay()
            return
        }
        isLoggedIn = true // Has token, proceed

        menuBarDisplayText = "Loading..."
        if !showSyncedMessage { lastErrorMessage = nil
        } // Clear previous error only if not showing transient like "synced"
        teamIdFetchFailed = false

        do {
            // First, fetch user info (/me endpoint) to get email and potentially team ID
            let userInfo = try await apiClient.fetchUserInfo(authToken: authToken)
            settingsManager.userEmail = userInfo.email
            userEmail = userInfo.email
            LoggingService.info("Fetched User: \(userInfo.email)", category: .data)
            
            // Check if team ID is available in the /me response and log it
            let teamId: Int
            if let teamIdFromMe = userInfo.teamId {
                teamId = teamIdFromMe
                LoggingService.info("Team ID extracted from /me endpoint: \(teamId)", category: .data)
                // Still need to get team name from teams endpoint
                let teamDetails = try await apiClient.fetchTeamInfo(authToken: authToken)
                settingsManager.teamName = teamDetails.name
                teamName = teamDetails.name
                LoggingService.info("Team name fetched: \(teamDetails.name)", category: .data)
            } else {
                // Fallback to teams endpoint for team ID
                let teamDetails = try await apiClient.fetchTeamInfo(authToken: authToken)
                teamId = teamDetails.id
                settingsManager.teamName = teamDetails.name
                teamName = teamDetails.name
                LoggingService.info("Team info fetched from teams endpoint: ID \(teamDetails.id), Name \(teamDetails.name)", category: .data)
            }
            
            settingsManager.teamId = teamId

            let calendar = Calendar.current
            let monthOneIndexed = calendar.component(.month, from: Date()) // Returns 1-12 (May = 5)
            let year = calendar.component(.year, from: Date())
            
            // Convert to zero-based month for Cursor API (January = 0, February = 1, May = 4, etc.)
            let month = monthOneIndexed - 1
            
            LoggingService.info("Fetching invoice for month \(month) (0-based), year \(year)", category: .data)

            // Now fetch monthly invoice data using the team ID we just obtained
            let invoiceResponse = try await apiClient.fetchMonthlyInvoice(
                authToken: authToken,
                month: month,
                year: year
            )
            let totalCents = invoiceResponse.totalSpendingCents
            currentSpendingUSD = Double(totalCents) / 100.0
            
            // Store the invoice response for debug display
            latestInvoiceResponse = invoiceResponse
            
            // Log invoice details for debugging
            if let items = invoiceResponse.items {
                LoggingService.info("Fetched Invoice: \(items.count) items, Total $\(currentSpendingUSD ?? 0)", category: .data)
                for item in items {
                    LoggingService.debug("Invoice item: \(item.description) - \(item.cents) cents", category: .data)
                }
            } else {
                LoggingService.info("Fetched Invoice: No usage items yet this month, Total $\(currentSpendingUSD ?? 0)", category: .data)
                if let pricingDesc = invoiceResponse.pricingDescription {
                    LoggingService.debug("Pricing description available: ID \(pricingDesc.id)", category: .data)
                }
            }

            // Convert to display currency and update menu bar immediately with spending data
            await convertAndDisplayAmounts()
            if showSyncedMessage {
                menuBarDisplayText = "Vibe synced! ✨"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.updateMenuBarDisplay()
                }
            } else {
                updateMenuBarDisplay()
            }
            checkLimitsAndNotify()

        } catch let error as CursorAPIClient.APIError where error == .unauthorized {
            LoggingService.warning("API Error: Not authenticated. Clearing session.", category: .data, error: error)
            lastErrorMessage = "Session expired. Please log in."
            loginManager.logOut() // This will trigger loginManager.onLoginSuccess/Failure via its own logic
            // which in turn calls handleLoginStatusChange.
        } catch let error as CursorAPIClient.APIError where error == .noTeamFound {
            LoggingService.error("API Error: Team not found after login.", category: .data, error: error)
            teamIdFetchFailed = true
            currentSpendingUSD = nil
            currentSpendingConverted = nil
            lastErrorMessage = "Hmm, can't find your team vibe right now. 😕 Try a refresh?"
            updateMenuBarDisplay()
        } catch {
            LoggingService.error("Failed to refresh data: \(error.localizedDescription)", category: .data, error: error)
            lastErrorMessage = "Error fetching data: \(String(describing: error))".truncate(length: 50)
            currentSpendingUSD = nil
            updateMenuBarDisplay()
        }
    }

    private func convertAndDisplayAmounts() async {
        let rates = await exchangeRateManager.getRates()
        currentExchangeRates = rates // Update the published property
        exchangeRatesAvailable = !rates.merging(exchangeRateManager.fallbackRates) { current, _ in current }
            .isEmpty && rates["USD"] != nil

        if !exchangeRatesAvailable || rates[selectedCurrencyCode] == nil {
            LoggingService.warning(
                "Exchange rates unavailable or selected currency rate missing. Displaying in USD.",
                category: .data
            )
            selectedCurrencySymbol = RealExchangeRateManager.getSymbol(for: "USD")
            if let spending = currentSpendingUSD {
                currentSpendingConverted = spending
            }
            warningLimitConverted = settingsManager.warningLimitUSD
            upperLimitConverted = settingsManager.upperLimitUSD
            if isLoggedIn && currentSpendingUSD != nil && teamIdFetchFailed == false &&
                (lastErrorMessage == nil || lastErrorMessage == "Vibe synced! ✨")
            {
                lastErrorMessage = "Rates MIA! Showing USD for now. ✨"
            }
        } else {
            selectedCurrencySymbol = RealExchangeRateManager.getSymbol(for: selectedCurrencyCode)
            // Use the stored self.currentExchangeRates for conversion now
            if let spending = currentSpendingUSD {
                currentSpendingConverted = exchangeRateManager.convert(
                    spending,
                    from: "USD",
                    to: selectedCurrencyCode,
                    rates: currentExchangeRates
                )
            }
            warningLimitConverted = exchangeRateManager.convert(
                settingsManager.warningLimitUSD,
                from: "USD",
                to: selectedCurrencyCode,
                rates: currentExchangeRates
            )
            upperLimitConverted = exchangeRateManager.convert(
                settingsManager.upperLimitUSD,
                from: "USD",
                to: selectedCurrencyCode,
                rates: currentExchangeRates
            )

            if lastErrorMessage == "Rates MIA! Showing USD for now. ✨" {
                lastErrorMessage = nil
            }
        }
        updateMenuBarDisplay()
    }

    private func updateMenuBarDisplay() {
        if !isLoggedIn {
            menuBarDisplayText = "" // Show only icon when not logged in
        } else if teamIdFetchFailed {
            menuBarDisplayText = "Error (No Team)" // More specific error
        } else if let specificError = lastErrorMessage,
                  specificError != "Rates MIA! Showing USD for now. ✨" && specificError != "Vibe synced! ✨"
        {
            menuBarDisplayText = "Error"
        } else if let spending = currentSpendingConverted, let warning = warningLimitConverted {
            menuBarDisplayText =
                "\(selectedCurrencySymbol)\(String(format: "%.2f", spending)) / \(selectedCurrencySymbol)\(String(format: "%.2f", warning))"
        } else if let spendingUSD = currentSpendingUSD,
                  !exchangeRatesAvailable
        { // Fallback to USD display if rates out, and converted values are nil
            let warningUSD = settingsManager.warningLimitUSD
            menuBarDisplayText = "$\(String(format: "%.2f", spendingUSD)) / $\(String(format: "%.2f", warningUSD))"
        } else {
            menuBarDisplayText = "Loading..."
        }
    }

    private func setupRefreshTimer() {
        refreshTimer?.invalidate()
        guard isLoggedIn else { refreshTimer = nil; return }
        let interval = TimeInterval(settingsManager.refreshIntervalMinutes * 60)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            LoggingService.info("Timer fired. Refreshing data.", category: .data)
            Task {
                await self?.forceRefreshData(showSyncedMessage: false)
            }
        }
    }

    func initiateLoginFlow() {
        // LoginManager now handles its own window and callbacks directly.
        // DataCoordinator's role is to observe loginManager's state changes (onLoginSuccess/Failure/Dismiss).
        loginManager.showLoginWindow()
    }

    private func checkLimitsAndNotify() {
        guard let spendingUSD = currentSpendingUSD else { return }

        let warningLimitUSD = settingsManager.warningLimitUSD
        let upperLimitUSD = settingsManager.upperLimitUSD
        let displayCurrency = exchangeRatesAvailable ? selectedCurrencyCode : "USD"

        // Use RealNotificationManager.LimitType
        notificationManager.resetNotificationStateIfBelow(
            limitType: .warning,
            currentSpendingUSD: spendingUSD,
            warningLimitUSD: warningLimitUSD,
            upperLimitUSD: upperLimitUSD
        )
        notificationManager.resetNotificationStateIfBelow(
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
            notificationManager.showWarningNotification(currentSpending: displaySpending, limitAmount: displayWarningLimit, currencyCode: displayCurrency)
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
            notificationManager.showUpperLimitNotification(
                currentSpending: displaySpending,
                limitAmount: displayUpperLimit,
                currencyCode: displayCurrency
            )
        }
    }

    func userDidRequestLogout() {
        LoggingService.info("User requested logout.", category: .data)
        loginManager.logOut() // This will clear token and trigger onLoginFailure through its own logic.
        // The onLoginFailure binding in setupBindings() will call handleLoginStatusChange(loggedIn: false,...)
        // which already calls clearUserData() and updateMenuBarDisplay().
    }

    func cleanup() {
        refreshTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
        LoggingService.info("RealDataCoordinator cleanup completed.", category: .data)
    }
}
