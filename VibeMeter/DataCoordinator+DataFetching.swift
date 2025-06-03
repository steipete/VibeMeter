import Foundation

// MARK: - Data Fetching

extension RealDataCoordinator {
    func fetchUserAndTeamInfo(authToken: String) async throws {
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
            LoggingService.info(
                "Team info fetched from teams endpoint: ID \(teamDetails.id), Name \(teamDetails.name)",
                category: .data
            )
        }

        settingsManager.teamId = teamId
    }

    func fetchCurrentMonthInvoice(authToken: String) async throws {
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
        let items = invoiceResponse.items
        if items.isEmpty {
            LoggingService.info(
                "Fetched Invoice: No usage items yet this month, Total $\(currentSpendingUSD ?? 0)",
                category: .data
            )
        } else {
            LoggingService.info(
                "Fetched Invoice: \(items.count) items, Total $\(currentSpendingUSD ?? 0)",
                category: .data
            )
            for item in items {
                LoggingService.debug("Invoice item: \(item.description) - \(item.cents) cents", category: .data)
            }
        }
        if let pricingDesc = invoiceResponse.pricingDescription {
            LoggingService.debug("Pricing description available: ID \(pricingDesc.id)", category: .data)
        }
    }

    func refreshExchangeRates() async {
        await convertAndDisplayAmounts()
    }
}
