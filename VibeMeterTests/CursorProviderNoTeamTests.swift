import Foundation
import Testing
@testable import VibeMeter

@Suite("CursorProviderNoTeamTests")
struct CursorProviderNoTeamTests {
    private let cursorProvider: CursorProvider
    private let mockURLSession: MockURLSession
    private let mockSettingsManager: MockSettingsManager

    init() {
        self.mockURLSession = MockURLSession()
        self.mockSettingsManager = MainActor.assumeIsolated { MockSettingsManager() }
        self.cursorProvider = CursorProvider(
            settingsManager: mockSettingsManager,
            urlSession: mockURLSession)
    }

    // MARK: - Individual User (No Team) Tests

    @Test("fetch user info  individual user  no team id")
    func fetchUserInfo_IndividualUser_NoTeamId() async throws {
        // Given - API returns user without teamId
        let mockUserData = Data("""
        {
            "email": "individual@example.com"
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.userInfo,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockUserData
        mockURLSession.nextResponse = mockResponse

        // When
        let userInfo = try await cursorProvider.fetchUserInfo(authToken: "individual-token")

        // Then
        #expect(userInfo.email == "individual@example.com")
        #expect(userInfo.provider == .cursor)
    }

    @Test("fetch team info  individual user  empty teams")
    func fetchTeamInfo_IndividualUser_EmptyTeams() async throws {
        // Given - API returns empty teams array for individual users
        let mockEmptyTeamsData = Data("""
        {
            "teams": []
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.teams,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockEmptyTeamsData
        mockURLSession.nextResponse = mockResponse

        // When
        let teamInfo = try await cursorProvider.fetchTeamInfo(authToken: "individual-token")

        // Then - Should return fallback team info for individual users
        #expect(teamInfo.id == CursorAPIConstants.ResponseConstants.individualUserTeamId)
        #expect(teamInfo.provider == .cursor)
    }

    @Test("fetch monthly invoice  individual user  no team id")
    func fetchMonthlyInvoice_IndividualUser_NoTeamId() async throws {
        // Given - No stored team ID and none provided (individual user)
        let mockInvoiceData = Data("""
        {
            "items": [
                {
                    "cents": 2000,
                    "description": "Individual Pro Usage"
                }
            ],
            "pricing_description": {
                "description": "Individual Pro Plan",
                "id": "individual-pro"
            }
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 12,
            year: 2023,
            teamId: nil)

        // Then
        #expect(invoice.items.count == 1)
        #expect(invoice.items[0].description == "Individual Pro Usage")
        #expect(invoice.pricingDescription?.description == "Individual Pro Plan")
        let requestBody = try #require(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["month"] as? Int == 12)
        #expect(bodyJSON?["teamId"] == nil)
    }

    @Test("fetch monthly invoice  individual user  empty invoice")
    func fetchMonthlyInvoice_IndividualUser_EmptyInvoice() async throws {
        // Given - Individual user with no spending
        let mockEmptyInvoiceData = Data("""
        {
            "items": [],
            "pricing_description": null
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockEmptyInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 1,
            year: 2024,
            teamId: nil)

        // Then
        #expect(invoice.items.isEmpty)
        #expect(invoice.pricingDescription == nil)
        let requestBody = try #require(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] == nil)
    }

    @Test("fetch monthly invoice  transition from team to individual")
    func fetchMonthlyInvoice_TransitionFromTeamToIndividual() async throws {
        // Given - User was previously in a team but now is individual
        // First, set up a previous team session
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 999,
            teamName: "Old Team",
            userEmail: "user@example.com",
            isActive: true))

        // Mock response for individual user invoice
        let mockInvoiceData = Data("""
        {
            "items": [{"cents": 1500, "description": "Individual Usage"}],
            "pricing_description": null
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - Explicitly pass nil teamId to override stored value
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 6,
            year: 2024,
            teamId: nil)

        // Then
        #expect(invoice.totalSpendingCents == 1500)
        let requestBody = try #require(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] as? Int == 999)
    }

    @Test("fetch monthly invoice  explicitly no team")
    func fetchMonthlyInvoice_ExplicitlyNoTeam() async throws {
        // Given - User has stored team but we want to fetch without team
        await mockSettingsManager.updateSession(for: .cursor, session: ProviderSession(
            provider: .cursor,
            teamId: 888,
            teamName: "Some Team",
            userEmail: "user@example.com",
            isActive: true))

        // Clear the session to simulate individual user
        await mockSettingsManager.clearUserSessionData(for: .cursor)

        let mockInvoiceData = Data("""
        {
            "items": [],
            "pricing_description": null
        }
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - No teamId provided and no stored session
        let invoice = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "individual-token",
            month: 3,
            year: 2024,
            teamId: nil)

        // Then
        #expect(invoice.items.isEmpty)
        let requestBody = try #require(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] == nil)
    }

    @Test("api request body  with team id")
    func aPIRequestBody_WithTeamId() async throws {
        // Given
        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - Explicitly provide teamId
        _ = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 7,
            year: 2024,
            teamId: 12345)

        // Then - Verify request body includes teamId
        let requestBody = try #require(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]

        #expect(bodyJSON?.count == 4)
        #expect(bodyJSON?["year"] as? Int == 2024)
        #expect(bodyJSON?["month"] as? Int == 7)
        #expect(bodyJSON?["teamId"] as? Int == 12345)
        #expect(bodyJSON?["includeUsageEvents"] as? Bool == false)
    }

    @Test("api request body  without team id")
    func aPIRequestBody_WithoutTeamId() async throws {
        // Given
        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - No teamId provided and no stored session
        _ = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 8,
            year: 2024,
            teamId: nil)

        // Then - Verify request body excludes teamId
        let requestBody = try #require(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?.count == 3)
        #expect(bodyJSON?["year"] as? Int == 2024)
        #expect(bodyJSON?["month"] as? Int == 8)
        #expect(bodyJSON?.keys.contains("teamId") == false)
    }

    @Test("api request body  team id zero")
    func aPIRequestBody_TeamIdZero() async throws {
        // Given - Test edge case where teamId is 0
        let mockInvoiceData = Data("""
        {"items": [], "pricing_description": null}
        """.utf8)

        let mockResponse = HTTPURLResponse(
            url: CursorAPIConstants.URLs.monthlyInvoice,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)!

        mockURLSession.nextData = mockInvoiceData
        mockURLSession.nextResponse = mockResponse

        // When - teamId is 0 (edge case)
        _ = try await cursorProvider.fetchMonthlyInvoice(
            authToken: "token",
            month: 9,
            year: 2024,
            teamId: 0)

        // Then - Verify request body excludes teamId since 0 is now filtered as invalid
        let requestBody = try #require(mockURLSession.lastRequest?.httpBody)
        let bodyJSON = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any]
        #expect(bodyJSON?["teamId"] == nil)
    }
}
