import Foundation
@testable import VibeMeter

@MainActor
final class CursorAPIClientMock: CursorAPIClientProtocol, @unchecked Sendable {
    var fetchTeamInfoCallCount = 0
    var fetchUserInfoCallCount = 0
    var fetchMonthlyInvoiceCallCount = 0

    // MARK: - Controllable Responses

    var teamInfoToReturn: TeamInfo? = TeamInfo(id: 123, name: "Mock Team")
    var userInfoToReturn: UserInfo? = UserInfo(email: "mock@example.com", teamId: 12345)
    var monthlyInvoiceToReturn: MonthlyInvoice? = MonthlyInvoice(
        items: [
            InvoiceItem(cents: 5000, description: "Mock Pro Usage"),
            InvoiceItem(cents: 1000, description: "Mock Fast Prompts"),
        ],
        pricingDescription: nil
    )

    // MARK: - Controllable Errors

    var teamInfoError: Error?
    var userInfoError: Error?
    var monthlyInvoiceError: Error?

    // MARK: - Captured Parameters

    var lastAuthTokenUsed: String?
    var lastMonthRequested: Int?
    var lastYearRequested: Int?

    // MARK: - CursorAPIClientProtocol

    func fetchTeamInfo(authToken: String) async throws -> TeamInfo {
        fetchTeamInfoCallCount += 1
        lastAuthTokenUsed = authToken

        if let error = teamInfoError {
            throw error
        }

        guard let teamInfo = teamInfoToReturn else {
            throw CursorAPIError.noTeamFound
        }

        return teamInfo
    }

    func fetchUserInfo(authToken: String) async throws -> UserInfo {
        fetchUserInfoCallCount += 1
        lastAuthTokenUsed = authToken

        if let error = userInfoError {
            throw error
        }

        guard let userInfo = userInfoToReturn else {
            throw CursorAPIError.networkError(message: "No user info to return", statusCode: nil)
        }

        return userInfo
    }

    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> MonthlyInvoice {
        fetchMonthlyInvoiceCallCount += 1
        lastAuthTokenUsed = authToken
        lastMonthRequested = month
        lastYearRequested = year

        if let error = monthlyInvoiceError {
            throw error
        }

        guard let invoice = monthlyInvoiceToReturn else {
            throw CursorAPIError.networkError(message: "No invoice to return", statusCode: nil)
        }

        return invoice
    }

    // MARK: - Reset

    func reset() {
        fetchTeamInfoCallCount = 0
        fetchUserInfoCallCount = 0
        fetchMonthlyInvoiceCallCount = 0

        teamInfoToReturn = TeamInfo(id: 123, name: "Mock Team")
        userInfoToReturn = UserInfo(email: "mock@example.com", teamId: 12345)
        monthlyInvoiceToReturn = MonthlyInvoice(
            items: [
                InvoiceItem(cents: 5000, description: "Mock Pro Usage"),
                InvoiceItem(cents: 1000, description: "Mock Fast Prompts"),
            ],
            pricingDescription: nil
        )

        teamInfoError = nil
        userInfoError = nil
        monthlyInvoiceError = nil

        lastAuthTokenUsed = nil
        lastMonthRequested = nil
        lastYearRequested = nil
    }
}
