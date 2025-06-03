import Foundation

// MARK: - Currency Handling

extension RealDataCoordinator {
    func convertAndDisplayAmounts() async {
        guard let spendingUSD = currentSpendingUSD else {
            currentSpendingConverted = nil
            warningLimitConverted = nil
            upperLimitConverted = nil
            menuBarDisplayText = "Loading..."
            return
        }

        let selectedCode = settingsManager.selectedCurrencyCode
        selectedCurrencyCode = selectedCode
        selectedCurrencySymbol = RealExchangeRateManager.getSymbol(for: selectedCode)

        // Update exchange rates if needed
        let rates = await exchangeRateManager.getRates()
        currentExchangeRates = rates
        exchangeRatesAvailable = !rates.isEmpty

        if exchangeRatesAvailable {
            currentSpendingConverted = exchangeRateManager.convert(
                spendingUSD,
                from: "USD",
                to: selectedCode,
                rates: rates
            )
            warningLimitConverted = exchangeRateManager.convert(
                settingsManager.warningLimitUSD,
                from: "USD",
                to: selectedCode,
                rates: rates
            )
            upperLimitConverted = exchangeRateManager.convert(
                settingsManager.upperLimitUSD,
                from: "USD",
                to: selectedCode,
                rates: rates
            )

            if let spending = currentSpendingConverted {
                LoggingService.info(
                    "Conversion: $\(String(format: "%.2f", spendingUSD)) USD = " +
                        "\(selectedCurrencySymbol)\(String(format: "%.2f", spending)) \(selectedCode)",
                    category: .data
                )
            }
        } else {
            // Fallback if no rates available: display USD directly
            LoggingService.warning(
                "Exchange rates not available. Displaying amounts in USD.",
                category: .exchangeRate
            )
            selectedCurrencySymbol = RealExchangeRateManager.getSymbol(for: "USD")
            if let spending = currentSpendingUSD {
                currentSpendingConverted = spending
            }
            warningLimitConverted = settingsManager.warningLimitUSD
            upperLimitConverted = settingsManager.upperLimitUSD
            if isLoggedIn, currentSpendingUSD != nil, teamIdFetchFailed == false,
               lastErrorMessage == nil || lastErrorMessage == "Vibe synced! ✨"
            {
                lastErrorMessage = "Rates MIA! Showing USD for now. ✨"
            }
        }

        updateMenuBarDisplay()
    }

    func updateMenuBarDisplay() {
        if !isLoggedIn {
            menuBarDisplayText = "" // Show only icon when not logged in
        } else if teamIdFetchFailed {
            menuBarDisplayText = "Error (No Team)" // More specific error
        } else if let specificError = lastErrorMessage,
                  specificError != "Rates MIA! Showing USD for now. ✨", specificError != "Vibe synced! ✨"
        {
            menuBarDisplayText = "Error"
        } else if let spending = currentSpendingConverted, let warning = warningLimitConverted {
            let spendingText = "\(selectedCurrencySymbol)\(String(format: "%.2f", spending))"
            let warningText = "\(selectedCurrencySymbol)\(String(format: "%.2f", warning))"
            menuBarDisplayText = "\(spendingText) / \(warningText)"
        } else if let spendingUSD = currentSpendingUSD,
                  !exchangeRatesAvailable
        { // Fallback to USD display if rates out, and converted values are nil
            let warningUSD = settingsManager.warningLimitUSD
            menuBarDisplayText = "$\(String(format: "%.2f", spendingUSD)) / $\(String(format: "%.2f", warningUSD))"
        } else {
            menuBarDisplayText = "Loading..."
        }
    }
}
