import AppKit
import SwiftUI

@MainActor
class MenuBarMenuBuilder {
    weak var controller: MenuBarController?
    weak var dataCoordinator: (any DataCoordinatorProtocol)?

    init(controller: MenuBarController, dataCoordinator: any DataCoordinatorProtocol) {
        self.controller = controller
        self.dataCoordinator = dataCoordinator
    }

    // MARK: - Helper Methods

    private func addStatusMessages(to menu: NSMenu) {
        guard let dataCoordinator else { return }

        // Display contextual error/status messages from DataCoordinator
        if let coordinatorMessage = dataCoordinator.lastErrorMessage {
            let item = NSMenuItem(title: coordinatorMessage, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        if dataCoordinator.teamIdFetchFailed, dataCoordinator.isLoggedIn {
            let item = NSMenuItem(
                title: "Hmm, can't find your team vibe right now. 😕 Try a refresh?",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }

        if !dataCoordinator.exchangeRatesAvailable, dataCoordinator.isLoggedIn, dataCoordinator
            .currentSpendingUSD != nil {
            let item = NSMenuItem(title: "Rates MIA! Showing USD for now. ✨", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        // Separator if any message was added above and we have more items
        if !menu.items.isEmpty, dataCoordinator.isLoggedIn || !dataCoordinator.isLoggedIn {
            menu.addItem(NSMenuItem.separator())
        }
    }

    private func addUserInfo(to menu: NSMenu) {
        guard let dataCoordinator else { return }

        if let email = dataCoordinator.userEmail {
            menu.addItem(NSMenuItem(title: "Logged In As: \(email)", action: nil, keyEquivalent: ""))
        } else {
            menu.addItem(NSMenuItem(title: "Logged In", action: nil, keyEquivalent: ""))
        }
    }

    private func addSpendingInfo(to menu: NSMenu) {
        guard let dataCoordinator else { return }

        let spendingText = if let spending = dataCoordinator.currentSpendingConverted {
            "\(dataCoordinator.selectedCurrencySymbol)\(String(format: "%.2f", spending))"
        } else if let spendingUSD = dataCoordinator.currentSpendingUSD, !dataCoordinator.exchangeRatesAvailable {
            "$\(String(format: "%.2f", spendingUSD)) (USD)"
        } else {
            "Loading..."
        }
        menu.addItem(NSMenuItem(title: "Current Spending: \(spendingText)", action: nil, keyEquivalent: ""))

        let warningText = if let limit = dataCoordinator.warningLimitConverted {
            "\(dataCoordinator.selectedCurrencySymbol)\(String(format: "%.2f", limit))"
        } else if !dataCoordinator.exchangeRatesAvailable {
            "$\(String(format: "%.2f", dataCoordinator.settingsManager.warningLimitUSD)) (USD)"
        } else {
            "N/A"
        }
        menu.addItem(NSMenuItem(title: "Warning at: \(warningText)", action: nil, keyEquivalent: ""))

        let upperText = if let limit = dataCoordinator.upperLimitConverted {
            "\(dataCoordinator.selectedCurrencySymbol)\(String(format: "%.2f", limit))"
        } else if !dataCoordinator.exchangeRatesAvailable {
            "$\(String(format: "%.2f", dataCoordinator.settingsManager.upperLimitUSD)) (USD)"
        } else {
            "N/A"
        }
        menu.addItem(NSMenuItem(title: "Max: \(upperText)", action: nil, keyEquivalent: ""))

        if let team = dataCoordinator.teamName {
            menu.addItem(NSMenuItem(title: "Vibing with: \(team)", action: nil, keyEquivalent: ""))
        }
    }

    private func formatCurrency(_ cents: Int) -> String {
        guard let dataCoordinator else { return "$0.00" }
        let dollarsUSD = Double(cents) / 100.0

        // Convert to selected currency if exchange rates are available
        if dataCoordinator.exchangeRatesAvailable,
           let convertedAmount = ExchangeRateManagerImpl.shared.convert(
               dollarsUSD,
               from: "USD",
               to: dataCoordinator.selectedCurrencyCode,
               rates: dataCoordinator.currentExchangeRates
           )
        {
            return "\(dataCoordinator.selectedCurrencySymbol)\(String(format: "%.2f", convertedAmount))"
        } else {
            return "$\(String(format: "%.2f", dollarsUSD))"
        }
    }

    private func addInvoiceDetails(to menu: NSMenu, invoiceResponse: MonthlyInvoice) {
        guard let dataCoordinator else { return }

        menu.addItem(NSMenuItem.separator())

        // Add a header for the debug section
        let debugHeader = NSMenuItem(title: "📋 Invoice Details", action: nil, keyEquivalent: "")
        debugHeader.isEnabled = false
        menu.addItem(debugHeader)

        // Add total spending (converted to selected currency)
        let totalCents = invoiceResponse.totalSpendingCents
        let totalUSD = Double(totalCents) / 100.0

        let totalFormatted = if dataCoordinator.exchangeRatesAvailable,
                                let convertedTotal = ExchangeRateManagerImpl.shared.convert(
                                    totalUSD,
                                    from: "USD",
                                    to: dataCoordinator.selectedCurrencyCode,
                                    rates: dataCoordinator.currentExchangeRates
                                )
        {
            "\(dataCoordinator.selectedCurrencySymbol)\(String(format: "%.2f", convertedTotal))"
        } else {
            "$\(String(format: "%.2f", totalUSD))"
        }

        let totalItem = NSMenuItem(title: "Total: \(totalFormatted)", action: nil, keyEquivalent: "")
        totalItem.isEnabled = false
        menu.addItem(totalItem)

        // Add individual items
        addInvoiceItems(to: menu, items: invoiceResponse.items)

        // Add pricing description if available
        if let pricingDesc = invoiceResponse.pricingDescription {
            let pricingItem = NSMenuItem(
                title: "Pricing ID: \(String(pricingDesc.id.prefix(8)))...",
                action: nil,
                keyEquivalent: ""
            )
            pricingItem.isEnabled = false
            menu.addItem(pricingItem)
        }
    }

    private func addInvoiceItems(to menu: NSMenu, items: [InvoiceItem]?) {
        guard let items else {
            let noItemsItem = NSMenuItem(title: "No usage items this month", action: nil, keyEquivalent: "")
            noItemsItem.isEnabled = false
            menu.addItem(noItemsItem)
            return
        }

        let itemCountItem = NSMenuItem(title: "Usage Items: \(items.count)", action: nil, keyEquivalent: "")
        itemCountItem.isEnabled = false
        menu.addItem(itemCountItem)

        // First, show the "Mid-month usage paid" item at the top if it exists
        let midMonthItems = items.filter { $0.description.contains("Mid-month usage paid") }
        let otherItems = items.filter { !$0.description.contains("Mid-month usage paid") }

        // Show mid-month usage items first (these are important - credits/refunds)
        for item in midMonthItems {
            let formattedAmount = formatCurrency(item.cents)
            let itemDescription = item.description.count > 50
                ? String(item.description.prefix(47)) + "..."
                : item.description
            let menuItem = NSMenuItem(
                title: "💰 \(itemDescription): \(formattedAmount)",
                action: nil,
                keyEquivalent: ""
            )
            menuItem.isEnabled = false
            menu.addItem(menuItem)
        }

        // Show other usage items (limit to avoid very long menu)
        // Show more if no mid-month items
        let itemsToShow = min(otherItems.count, midMonthItems.isEmpty ? 8 : 6)
        for item in otherItems.prefix(itemsToShow) {
            let formattedAmount = formatCurrency(item.cents)
            let itemDescription = item.description.count > 50
                ? String(item.description.prefix(47)) + "..."
                : item.description
            let menuItem = NSMenuItem(
                title: "• \(itemDescription): \(formattedAmount)",
                action: nil,
                keyEquivalent: ""
            )
            menuItem.isEnabled = false
            menu.addItem(menuItem)
        }

        let totalShown = midMonthItems.count + itemsToShow
        if items.count > totalShown {
            let moreItem = NSMenuItem(
                title: "... and \(items.count - totalShown) more items",
                action: nil,
                keyEquivalent: ""
            )
            moreItem.isEnabled = false
            menu.addItem(moreItem)
        }
    }

    private func addLoggedInActions(to menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(
            title: "Refresh Now",
            action: #selector(MenuBarController.refreshNowClicked),
            keyEquivalent: "r"
        )
        refreshItem.target = controller
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(MenuBarController.settingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = controller
        menu.addItem(settingsItem)

        let logOutItem = NSMenuItem(
            title: "Log Out",
            action: #selector(MenuBarController.logOutClicked),
            keyEquivalent: "q"
        )
        logOutItem.target = controller
        menu.addItem(logOutItem)
    }

    private func addLoggedOutActions(to menu: NSMenu) {
        // Add Login menu item
        let loginItem = NSMenuItem(
            title: "Login",
            action: #selector(MenuBarController.loginClicked),
            keyEquivalent: "l"
        )
        loginItem.target = controller
        menu.addItem(loginItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(MenuBarController.settingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = controller
        menu.addItem(settingsItem)
    }

    private func addCommonActions(to menu: NSMenu) {
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit Vibe Meter",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "Q"
        )
        menu.addItem(quitItem)
    }

    func buildMenu() -> NSMenu {
        let menu = NSMenu()

        guard let dataCoordinator else { return menu }

        // Add status messages
        addStatusMessages(to: menu)

        if dataCoordinator.isLoggedIn {
            // Add user info and spending details
            addUserInfo(to: menu)
            addSpendingInfo(to: menu)

            // Add invoice details if available
            if let coordinator = dataCoordinator as? DataCoordinator,
               let invoiceResponse = coordinator.latestInvoiceResponse
            {
                addInvoiceDetails(to: menu, invoiceResponse: invoiceResponse)
            }

            // Add logged in actions
            addLoggedInActions(to: menu)
        } else {
            // Add logged out actions
            addLoggedOutActions(to: menu)
        }

        // Add common actions
        addCommonActions(to: menu)

        return menu
    }
}
