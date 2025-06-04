import Foundation
@testable import VibeMeter

@MainActor
final class CursorAPIClientMock: ProviderProtocol, MockResetProtocol, @unchecked Sendable {
    let provider: ServiceProvider = .cursor

    var fetchTeamInfoCallCount = 0
    var fetchUserInfoCallCount = 0
    var fetchMonthlyInvoiceCallCount = 0
    var fetchUsageDataCallCount = 0
    var validateTokenCallCount = 0

    // MARK: - Controllable Responses

    var teamInfoToReturn: ProviderTeamInfo? = ProviderTeamInfo(id: 123, name: "Mock Team", provider: .cursor)
    var userInfoToReturn: ProviderUserInfo? = ProviderUserInfo(
        email: "mock@example.com",
        teamId: 12345,
        provider: .cursor)
    var monthlyInvoiceToReturn: ProviderMonthlyInvoice? = ProviderMonthlyInvoice(
        items: [
            ProviderInvoiceItem(cents: 5000, description: "Mock Pro Usage", provider: .cursor),
            ProviderInvoiceItem(cents: 1000, description: "Mock Fast Prompts", provider: .cursor),
        ],
        pricingDescription: nil,
        provider: .cursor,
        month: 5,
        year: 2023)
    var usageDataToReturn: ProviderUsageData? = ProviderUsageData(
        currentRequests: 150,
        totalRequests: 4387,
        maxRequests: 500,
        startOfMonth: Date(),
        provider: .cursor)

    // MARK: - Controllable Errors

    var teamInfoError: Error?
    var userInfoError: Error?
    var monthlyInvoiceError: Error?
    var usageDataError: Error?
    var tokenValidationResult: Bool = true

    // MARK: - Captured Parameters

    var lastAuthTokenUsed: String?
    var lastMonthRequested: Int?
    var lastYearRequested: Int?
    var lastTeamIdRequested: Int?

    // MARK: - ProviderProtocol

    func fetchTeamInfo(authToken: String) async throws -> ProviderTeamInfo {
        fetchTeamInfoCallCount += 1
        lastAuthTokenUsed = authToken

        if let error = teamInfoError {
            throw error
        }

        guard let teamInfo = teamInfoToReturn else {
            throw ProviderError.noTeamFound
        }

        return teamInfo
    }

    func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo {
        fetchUserInfoCallCount += 1
        lastAuthTokenUsed = authToken

        if let error = userInfoError {
            throw error
        }

        guard let userInfo = userInfoToReturn else {
            throw ProviderError.networkError(message: "No user info to return", statusCode: nil)
        }

        return userInfo
    }

    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int,
                             teamId: Int?) async throws -> ProviderMonthlyInvoice {
        fetchMonthlyInvoiceCallCount += 1
        lastAuthTokenUsed = authToken
        lastMonthRequested = month
        lastYearRequested = year
        lastTeamIdRequested = teamId

        if let error = monthlyInvoiceError {
            throw error
        }

        guard let invoice = monthlyInvoiceToReturn else {
            throw ProviderError.networkError(message: "No invoice to return", statusCode: nil)
        }

        return invoice
    }

    func fetchUsageData(authToken: String) async throws -> ProviderUsageData {
        fetchUsageDataCallCount += 1
        lastAuthTokenUsed = authToken

        if let error = usageDataError {
            throw error
        }

        guard let usageData = usageDataToReturn else {
            throw ProviderError.networkError(message: "No usage data to return", statusCode: nil)
        }

        return usageData
    }

    func validateToken(authToken: String) async -> Bool {
        validateTokenCallCount += 1
        lastAuthTokenUsed = authToken
        return tokenValidationResult
    }

    nonisolated func getAuthenticationURL() -> URL {
        URL(string: "https://authenticator.cursor.sh")!
    }

    nonisolated func extractAuthToken(from callbackData: [String: Any]) -> String? {
        callbackData["token"] as? String
    }

    // MARK: - Reset

    func reset() {
        resetTracking()
        resetReturnValues()
    }

    func resetTracking() {
        fetchTeamInfoCallCount = 0
        fetchUserInfoCallCount = 0
        fetchMonthlyInvoiceCallCount = 0
        fetchUsageDataCallCount = 0
        validateTokenCallCount = 0
        lastAuthTokenUsed = nil
        lastMonthRequested = nil
        lastYearRequested = nil
        lastTeamIdRequested = nil
    }

    func resetReturnValues() {
        teamInfoToReturn = ProviderTeamInfo(id: 123, name: "Mock Team", provider: .cursor)
        userInfoToReturn = ProviderUserInfo(email: "mock@example.com", teamId: 12345, provider: .cursor)
        monthlyInvoiceToReturn = ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 5000, description: "Mock Pro Usage", provider: .cursor),
                ProviderInvoiceItem(cents: 1000, description: "Mock Fast Prompts", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2023)
        usageDataToReturn = ProviderUsageData(
            currentRequests: 150,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor)
        teamInfoError = nil
        userInfoError = nil
        monthlyInvoiceError = nil
        usageDataError = nil
        tokenValidationResult = true
    }
}
