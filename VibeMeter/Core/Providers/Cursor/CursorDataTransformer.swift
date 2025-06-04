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
        guard let firstTeam = response.teams.first else {
            logger.error("No teams found in Cursor response")
            throw ProviderError.noTeamFound
        }

        logger.info("Successfully transformed Cursor team: \(firstTeam.name, privacy: .public)")
        return ProviderTeamInfo(id: firstTeam.id, name: firstTeam.name, provider: .cursor)
    }

    static func transformUserInfo(from response: CursorUserResponse) -> ProviderUserInfo {
        logger.info("Successfully transformed Cursor user: \(response.email, privacy: .public)")
        return ProviderUserInfo(email: response.email, teamId: response.teamId, provider: .cursor)
    }

    static func transformInvoice(from response: CursorInvoiceResponse, month: Int,
                                 year: Int) -> ProviderMonthlyInvoice {
        let genericItems = (response.items ?? []).map { item in
            ProviderInvoiceItem(
                cents: item.cents,
                description: item.description,
                provider: .cursor)
        }

        let genericPricing = response.pricingDescription.map { pricing in
            ProviderPricingDescription(
                description: pricing.description,
                id: pricing.id,
                provider: .cursor)
        }

        let totalCents = genericItems.reduce(0) { $0 + $1.cents }
        logger.info("Successfully transformed Cursor invoice: \(genericItems.count) items, total: \(totalCents) cents")

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
