import Foundation
@testable import VibeMeter

class CursorAPIClientMock: CursorAPIClientProtocol {
    var fetchTeamInfoCallCount = 0
    var fetchUserInfoCallCount = 0
    var fetchMonthlyInvoiceCallCount = 0

    // MARK: - Controllable Responses

    var teamInfoToReturn: (id: Int, name: String)? = (123, "Mock Team")
    var userInfoToReturn: UserInfo? = UserInfo(email: "mock@example.com", teamId: 12345)
    var monthlyInvoiceToReturn: MonthlyInvoice? = MonthlyInvoice(items: [
            InvoiceItem(cents: 5000, description: "Mock Pro Usage"),
            InvoiceItem(cents: 1000, description: "Mock Fast Prompts"),
        ], pricingDescription: nil)

    // MARK: - Controllable Errors

    var errorToThrow: Error?
    var teamInfoError: Error?
    var userInfoError: Error?
    var monthlyInvoiceError: Error?

    // MARK: - Captured Arguments

    var lastAuthTokenForTeamInfo: String?
    var lastAuthTokenForUserInfo: String?
    var lastAuthTokenForInvoice: String?
    var lastMonthForInvoice: Int?
    var lastYearForInvoice: Int?

    func fetchTeamInfo(authToken: String) async throws -> (id: Int, name: String) {
        fetchTeamInfoCallCount += 1
        lastAuthTokenForTeamInfo = authToken
        if let error = teamInfoError ?? errorToThrow {
            throw error
        }
        guard let teamInfo = teamInfoToReturn else {
            throw CursorAPIError.noTeamFound // Default error if not configured
        }
        return teamInfo
    }

    func fetchUserInfo(authToken: String) async throws -> UserInfo {
        fetchUserInfoCallCount += 1
        lastAuthTokenForUserInfo = authToken
        if let error = userInfoError ?? errorToThrow {
            throw error
        }
        guard let userInfo = userInfoToReturn else {
            // Simulate a generic decoding or network error if specific user info is not set for success
            throw CursorAPIError
                .decodingError(ErrorDetails(message: "Mock UserInfo decoding error"))
        }
        return userInfo
    }

    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int) async throws -> MonthlyInvoice
    {
        fetchMonthlyInvoiceCallCount += 1
        lastAuthTokenForInvoice = authToken
        lastMonthForInvoice = month
        lastYearForInvoice = year
        if let error = monthlyInvoiceError ?? errorToThrow {
            throw error
        }
        guard let invoice = monthlyInvoiceToReturn else {
            // Simulate a generic decoding or network error
            throw CursorAPIError
                .networkError(ErrorDetails(message: "Mock Invoice network error"))
        }
        return invoice
    }

    func reset() {
        fetchTeamInfoCallCount = 0
        fetchUserInfoCallCount = 0
        fetchMonthlyInvoiceCallCount = 0

        teamInfoToReturn = (123, "Mock Team")
        userInfoToReturn = UserInfo(email: "mock@example.com", teamId: 12345)
        monthlyInvoiceToReturn = MonthlyInvoice(items: [
            InvoiceItem(cents: 5000, description: "Mock Pro Usage"),
            InvoiceItem(cents: 1000, description: "Mock Fast Prompts"),
        ], pricingDescription: nil)

        errorToThrow = nil
        teamInfoError = nil
        userInfoError = nil
        monthlyInvoiceError = nil

        lastAuthTokenForTeamInfo = nil
        lastAuthTokenForUserInfo = nil
        lastAuthTokenForInvoice = nil
        lastMonthForInvoice = nil
        lastYearForInvoice = nil
    }
}
