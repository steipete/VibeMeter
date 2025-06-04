import Foundation
import os.log

/// Transforms Cursor API responses into domain model objects.
///
/// This transformer handles the conversion from Cursor-specific API responses
/// to generic provider models used throughout the application.
enum CursorDataTransformer {
    private static let logger = Logger(subsystem: "com.vibemeter", category: "CursorDataTransformer")

    // MARK: - Transformation Methods

    static func transformTeamInfo(from response: CursorTeamsResponse) throws -> ProviderTeamInfo {
        // Handle new API format that may return empty object or no teams array
        guard let teams = response.teams, !teams.isEmpty else {
            logger.warning("Cursor API returned empty teams response - this may indicate API changes")
            // Create a fallback team info since the user is authenticated but no team data is available
            // This allows the app to continue functioning even with the changed API
            logger.info("Creating fallback team info due to empty teams response")
            return ProviderTeamInfo(id: 0, name: "Individual", provider: .cursor)
        }
        
        let firstTeam = teams.first!
        logger.info("Successfully transformed Cursor team: \(firstTeam.name, privacy: .public)")
        return ProviderTeamInfo(id: firstTeam.id, name: firstTeam.name, provider: .cursor)
    }

    static func transformUserInfo(from response: CursorUserResponse) -> ProviderUserInfo {
        logger.info("Successfully transformed Cursor user: \(response.email, privacy: .public)")
        return ProviderUserInfo(email: response.email, teamId: response.teamId, provider: .cursor)
    }

    static func transformInvoice(from response: CursorInvoiceResponse, month: Int,
                                 year: Int) -> ProviderMonthlyInvoice {
        logger.info("Transforming invoice response for \(month)/\(year)")
        logger.debug("Invoice response items count: \(response.items?.count ?? 0)")
        
        let genericItems: [ProviderInvoiceItem] = response.items?.map { item in
            logger.debug("Processing invoice item: \(item.description) - \(item.cents) cents")
            return ProviderInvoiceItem(
                cents: item.cents,
                description: item.description,
                provider: .cursor)
        } ?? []

        let genericPricing = response.pricingDescription.map { pricing in
            ProviderPricingDescription(
                description: pricing.description,
                id: pricing.id,
                provider: .cursor)
        }

        let totalCents = genericItems.reduce(0) { $0 + $1.cents }
        let totalUSD = Double(totalCents) / 100.0
        logger.info("Successfully transformed Cursor invoice: \(genericItems.count) items, total: \(totalCents) cents ($\(totalUSD))")

        return ProviderMonthlyInvoice(
            items: genericItems,
            pricingDescription: genericPricing,
            provider: .cursor,
            month: month,
            year: year)
    }

    static func transformUsageData(from response: CursorUsageResponse) throws -> ProviderUsageData {
        let primaryUsage = response.gpt4

        let dateFormatter = ISO8601DateFormatter()
        let startOfMonth = dateFormatter.date(from: response.startOfMonth) ?? Date()

        logger
            .info(
                "Successfully transformed Cursor usage: \(primaryUsage.numRequests)/\(primaryUsage.maxRequestUsage ?? 0) requests")

        return ProviderUsageData(
            currentRequests: primaryUsage.numRequests,
            totalRequests: primaryUsage.numRequestsTotal,
            maxRequests: primaryUsage.maxRequestUsage,
            startOfMonth: startOfMonth,
            provider: .cursor)
    }
}
